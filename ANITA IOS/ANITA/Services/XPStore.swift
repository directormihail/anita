//
//  XPStore.swift
//  ANITA
//
//  Single source of truth for XP stats. Finance tab and Sidebar read from here
//  so XP updates in real time after chat awards or app-open streak.
//

import Foundation
import SwiftUI

@MainActor
final class XPStore: ObservableObject {
    static let shared = XPStore()

    @Published private(set) var xpStats: XPStats?

    private let networkService = NetworkService.shared

    private init() {}

    /// Fetch latest XP from backend and update store. Call after awarding XP or when Finance tab appears.
    /// Display uses iOS rules: 100 XP per level, 10 levels, level 10 endless (only total_xp from API).
    func refresh() async {
        let userId = UserManager.shared.userId
        guard !userId.isEmpty else { return }
        for attempt in 1...2 {
            do {
                let response = try await networkService.getXPStats(userId: userId)
                let newStats = XPStats.from(totalXP: response.xpStats.total_xp)
                self.xpStats = newStats
                return
            } catch {
                print("[XPStore] refresh attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt == 1 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
        }
    }

    /// Update store with stats (e.g. from SidebarViewModel after load or app-open streak).
    /// Display uses iOS rules: 100 XP per level, 10 levels, level 10 endless (only total_xp from API).
    func update(with stats: XPStats) {
        self.xpStats = XPStats.from(totalXP: stats.total_xp)
    }
}
