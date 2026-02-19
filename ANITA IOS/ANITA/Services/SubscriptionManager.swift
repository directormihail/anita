//
//  SubscriptionManager.swift
//  ANITA
//
//  Single source of truth for premium status and subscription plan name (backend + StoreKit fallback).
//

import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    /// True if user has an active premium subscription (we only have Premium now; legacy "ultimate" is treated as Premium).
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    /// Normalized plan: "free" or "premium".
    @Published private(set) var subscriptionPlan: String = "free"
    
    /// Localized display name for the current plan ("Free" or "Premium"). Always reflects database when available.
    var subscriptionDisplayName: String {
        subscriptionPlan == "premium" ? AppL10n.t("plans.premium") : AppL10n.t("plans.free")
    }
    
    private let networkService = NetworkService.shared
    private let storeKitService = StoreKitService.shared
    private let userManager = UserManager.shared
    
    private init() {
        Task { await refresh() }
    }
    
    /// Refresh premium status and plan name from backend (and StoreKit as fallback when offline).
    func refresh() async {
        let uid = userManager.userId
        guard !uid.isEmpty else {
            isPremium = false
            subscriptionPlan = "free"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.getSubscription(userId: uid)
            let sub = response.subscription
            isPremium = (sub.plan != "free" && sub.status == "active")
            subscriptionPlan = (sub.plan == "premium" || sub.plan == "pro" || sub.plan == "ultimate") ? "premium" : "free"
        } catch {
            // Offline or backend error: use StoreKit as fallback
            let purchased = storeKitService.isPurchased("com.anita.pro.monthly")
            isPremium = purchased
            subscriptionPlan = purchased ? "premium" : "free"
        }
    }
}
