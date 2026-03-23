import Foundation
import SwiftUI
import UIKit

#if canImport(StripeFinancialConnections)
import StripeCore
import StripeFinancialConnections
#endif

/// Return URL for Stripe Financial Connections (must match URL scheme in Info.plist — we use "anita").
private let stripeReturnURL = "anita://stripe-redirect"

/// Starts the Stripe Financial Connections flow: backend session → present sheet on main thread.
final class BankConnectionTester: ObservableObject {
    static let shared = BankConnectionTester()
    
    #if canImport(StripeFinancialConnections)
    private var sheet: FinancialConnectionsSheet?
    #endif
    
    private init() {}
    
    /// 1) Fetches client_secret from backend. 2) Presents FinancialConnectionsSheet on main thread.
    /// - Returns: `true` if the user successfully completed linking; `false` if canceled, failed, or unavailable.
    func startTestFlow(userId: String, userEmail: String?) async throws -> Bool {
        // Prefer authenticated Supabase id when available so bank data is sharable across devices,
        // but still allow anonymous testing using the provided userId.
        let resolvedUserId: String
        if UserManager.shared.isAuthenticated, let current = UserManager.shared.currentUser {
            resolvedUserId = current.id
        } else {
            resolvedUserId = userId
        }
        let response = try await NetworkService.shared.createFinancialConnectionsSession(
            userId: resolvedUserId,
            userEmail: userEmail
        )
        
        guard let clientSecret = response.clientSecret, !clientSecret.isEmpty else {
            throw NetworkError.apiError(response.error ?? "Missing client_secret from backend.")
        }
        
        #if canImport(StripeFinancialConnections)
        return await presentSheetOnMain(clientSecret: clientSecret)
        #else
        print("[BankConnectionTester] Session created. Add StripeFinancialConnections to target to show the window.")
        return false
        #endif
    }
    
    #if canImport(StripeFinancialConnections)
    @MainActor
    private func presentSheetOnMain(clientSecret: String) async -> Bool {
        StripeAPI.defaultPublishableKey = Config.stripePublishableKey
        sheet = FinancialConnectionsSheet(
            financialConnectionsSessionClientSecret: clientSecret,
            returnURL: stripeReturnURL
        )
        
        guard let rootVC = topMostViewController() else {
            print("[BankConnectionTester] No root view controller.")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            sheet?.present(from: rootVC) { result in
                let success: Bool
                switch result {
                case .completed:
                    print("[BankConnectionTester] Completed.")
                    UserManager.shared.markBankSyncEstablished()
                    success = true
                case .canceled:
                    print("[BankConnectionTester] Canceled.")
                    success = false
                case .failed(let error):
                    print("[BankConnectionTester] Failed: \(error.localizedDescription)")
                    success = false
                @unknown default:
                    success = false
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    private func topMostViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            var root = window.rootViewController
        else { return nil }
        while let presented = root.presentedViewController { root = presented }
        return root
    }
    #endif
}
