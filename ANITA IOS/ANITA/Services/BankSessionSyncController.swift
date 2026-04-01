//
//  BankSessionSyncController.swift
//  ANITA
//
//  Pulls fresh bank data from Stripe only during an active user session (foreground open /
//  right after link), not from iOS background modes. Chains requests so they never overlap.
//
//  Cost control: at most one successful Stripe refresh per user per 24 hours (persisted), for
//  any trigger (app open or bank link). Between refreshes the app reads `bank_transactions` from
//  Supabase. New links still get data from the `financial_connections.account.created` webhook;
//  the client refresh is only when the 24h window allows it.
//

import Foundation

/// Unit-testable policy: mirrors iOS foreground throttle (24h since last success).
enum BankSessionForegroundSyncPolicy {
    static let minSecondsBetweenSuccesses: TimeInterval = 24 * 3600

    /// Whether a foreground (e.g. app open) refresh may call Stripe, given last successful end time.
    static func shouldAllowForegroundRefresh(lastSuccessfulSyncAt: Date?, now: Date = Date()) -> Bool {
        guard let last = lastSuccessfulSyncAt else { return true }
        return now.timeIntervalSince(last) >= minSecondsBetweenSuccesses
    }
}

final class BankSessionSyncController {
    static let shared = BankSessionSyncController()

    private static let lastSuccessKeyPrefix = "anita_last_stripe_bank_sync_success_at_"

    enum Trigger {
        case appForeground
        case afterBankLinkSuccess
    }

    private let lock = NSLock()
    private var chain: Task<Void, Never>?

    private init() {}

    static func lastSuccessfulSyncDate(forUserId userId: String) -> Date? {
        UserDefaults.standard.object(forKey: lastSuccessKeyPrefix + userId) as? Date
    }

    private static func setLastSuccessfulSync(forUserId userId: String, date: Date) {
        UserDefaults.standard.set(date, forKey: lastSuccessKeyPrefix + userId)
    }

    /// Exposed for tests / rare reset (e.g. debug). Normal flow sets this only after a successful API refresh.
    static func clearLastSuccessfulSync(forUserId userId: String) {
        UserDefaults.standard.removeObject(forKey: lastSuccessKeyPrefix + userId)
    }

    /// Enqueues a Stripe→DB refresh. Completion runs on the main queue after the attempt (success, skip, or failure).
    func schedule(userId: String, trigger: Trigger, completion: @escaping () -> Void = {}) {
        guard !userId.isEmpty else {
            DispatchQueue.main.async { completion() }
            return
        }

        lock.lock()
        let previous = chain
        // No `[weak self]` — this controller is a singleton and the task uses only `Self` / static APIs.
        chain = Task {
            await previous?.value

            let lastSuccess = Self.lastSuccessfulSyncDate(forUserId: userId)
            let allowStripe = BankSessionForegroundSyncPolicy.shouldAllowForegroundRefresh(lastSuccessfulSyncAt: lastSuccess)

            if !allowStripe {
                #if DEBUG
                print("[BankSessionSync] skip (24h window) user=\(userId.prefix(8))… trigger=\(trigger)")
                #endif
                await MainActor.run { completion() }
                return
            }

            do {
                try await NetworkService.shared.refreshBankTransactions(userId: userId)
                Self.setLastSuccessfulSync(forUserId: userId, date: Date())
            } catch {
                print("[BankSessionSync] refreshBankTransactions failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                NotificationCenter.default.post(name: .anitaBankSyncCompleted, object: nil)
                completion()
            }
        }
        lock.unlock()
    }
}
