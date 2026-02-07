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
    func refresh() async {
        let userId = UserManager.shared.userId
        guard !userId.isEmpty else { return }
        do {
            let response = try await networkService.getXPStats(userId: userId)
            self.xpStats = response.xpStats
        } catch {
            print("[XPStore] refresh failed: \(error.localizedDescription)")
        }
    }

    /// Update store with stats (e.g. from SidebarViewModel after load or app-open streak).
    func update(with stats: XPStats) {
        self.xpStats = stats
    }
}
