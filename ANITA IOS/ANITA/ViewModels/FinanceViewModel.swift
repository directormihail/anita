//
//  FinanceViewModel.swift
//  ANITA
//
//  ViewModel for finance functionality
//

import Foundation
import SwiftUI

@MainActor
class FinanceViewModel: ObservableObject {
    @Published var totalBalance: Double = 0.0
    @Published var monthlyIncome: Double = 0.0
    @Published var monthlyExpenses: Double = 0.0
    @Published var transactions: [TransactionItem] = []
    @Published var targets: [Target] = []
    @Published var goals: [Target] = []
    @Published var assets: [Asset] = []
    @Published var xpStats: XPStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    private let userId: String
    
    init(userId: String? = nil) {
        self.userId = userId ?? UserManager.shared.userId
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Load all data in parallel
                async let metricsTask = networkService.getFinancialMetrics(userId: userId)
                async let transactionsTask = networkService.getTransactions(userId: userId)
                async let targetsTask = networkService.getTargets(userId: userId)
                async let assetsTask = networkService.getAssets(userId: userId)
                async let xpStatsTask = networkService.getXPStats(userId: userId)
                
                let metrics = try await metricsTask
                let transactionsResponse = try await transactionsTask
                let targetsResponse = try await targetsTask
                let assetsResponse = try await assetsTask
                let xpStatsResponse = try await xpStatsTask
                
                await MainActor.run {
                    self.totalBalance = metrics.metrics.totalBalance
                    self.monthlyIncome = metrics.metrics.monthlyIncome
                    self.monthlyExpenses = metrics.metrics.monthlyExpenses
                    self.transactions = transactionsResponse.transactions
                    self.targets = targetsResponse.targets
                    self.goals = targetsResponse.goals ?? []
                    self.assets = assetsResponse.assets
                    self.xpStats = xpStatsResponse.xpStats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func refresh() {
        loadData()
    }
    
    func addAsset(name: String, type: String, currentValue: Double, description: String?) async throws {
        let userId = self.userId
        
        let newAsset = try await networkService.createAsset(
            userId: userId,
            name: name,
            type: type,
            currentValue: currentValue,
            description: description
        )
        
        await MainActor.run {
            self.assets.append(newAsset)
        }
    }
}

