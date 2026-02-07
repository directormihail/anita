//
//  SubscriptionManager.swift
//  ANITA
//
//  Single source of truth for premium status (backend + StoreKit fallback).
//

import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    /// True if user has an active premium (pro/ultimate) subscription.
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    private let networkService = NetworkService.shared
    private let storeKitService = StoreKitService.shared
    private let userManager = UserManager.shared
    
    private init() {
        Task { await refresh() }
    }
    
    /// Refresh premium status from backend (and StoreKit as fallback when offline).
    func refresh() async {
        let uid = userManager.userId
        guard !uid.isEmpty else {
            isPremium = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await networkService.getSubscription(userId: uid)
            isPremium = (response.subscription.plan != "free" && response.subscription.status == "active")
        } catch {
            // Offline or backend error: use StoreKit as fallback
            isPremium = storeKitService.isPurchased("com.anita.pro.monthly")
        }
    }
}
