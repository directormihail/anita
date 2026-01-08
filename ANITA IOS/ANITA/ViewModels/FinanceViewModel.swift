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
    @Published var selectedMonth: Date = Date() // Current month by default
    
    private let networkService = NetworkService.shared
    let userId: String
    
    init(userId: String? = nil) {
        self.userId = userId ?? UserManager.shared.userId
        
        // Listen for transaction added notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TransactionAdded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func getMonthString(from date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }
    
    private func getYearString(from date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        return String(year)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let monthStr = getMonthString(from: selectedMonth)
                let yearStr = getYearString(from: selectedMonth)
                
                // Load all data in parallel with month filtering
                async let metricsTask = networkService.getFinancialMetrics(userId: userId, month: monthStr, year: yearStr)
                async let transactionsTask = networkService.getTransactions(userId: userId, month: monthStr, year: yearStr)
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
                    let errorDesc = error.localizedDescription
                    var userFriendlyError = errorDesc
                    
                    // Provide more helpful error messages
                    if errorDesc.contains("timed out") || errorDesc.contains("timeout") {
                        userFriendlyError = "Request timed out. Please check:\n1. Backend is running (npm run dev)\n2. Backend URL is correct in Settings\n3. Device and backend are on same network"
                    } else if errorDesc.contains("cannot find host") || errorDesc.contains("cannot connect") {
                        userFriendlyError = "Could not connect to the server.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings is: http://localhost:3001\n3. For physical device: Use your Mac's IP address"
                    } else if errorDesc.contains("The Internet connection appears to be offline") {
                        userFriendlyError = "No internet connection. Please check your network settings."
                    } else if errorDesc.contains("No internet connection") {
                        userFriendlyError = "No internet connection. Please check your network settings."
                    }
                    
                    self.errorMessage = userFriendlyError
                    self.isLoading = false
                }
            }
        }
    }
    
    func refresh() {
        loadData()
    }
    
    func changeMonth(to date: Date) {
        selectedMonth = date
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
    
    func updateAsset(assetId: String, currentValue: Double? = nil, name: String? = nil, type: String? = nil, description: String? = nil) async throws {
        let userId = self.userId
        
        print("[FinanceViewModel] Updating asset \(assetId)")
        
        let response = try await networkService.updateAsset(
            userId: userId,
            assetId: assetId,
            currentValue: currentValue,
            name: name,
            type: type,
            description: description
        )
        
        print("[FinanceViewModel] Asset updated successfully")
        
        // Update local array
        await MainActor.run {
            if let index = self.assets.firstIndex(where: { $0.id == assetId }) {
                self.assets[index] = response.asset
            }
        }
        
        // Refresh to sync
        refresh()
    }
    
    func deleteAsset(assetId: String) async throws {
        let userId = self.userId
        
        print("[FinanceViewModel] Deleting asset \(assetId)")
        
        let response = try await networkService.deleteAsset(
            userId: userId,
            assetId: assetId
        )
        
        print("[FinanceViewModel] Asset deleted successfully: \(response.success)")
        
        // Remove from local array
        await MainActor.run {
            self.assets.removeAll { $0.id == assetId }
        }
        
        // Refresh to sync
        refresh()
    }
    
    func deleteTarget(targetId: String) async throws {
        let userId = self.userId
        
        print("[FinanceViewModel] Deleting target \(targetId)")
        
        // Call backend API to delete target
        let response = try await networkService.deleteTarget(
            userId: userId,
            targetId: targetId
        )
        
        print("[FinanceViewModel] Target deleted successfully: \(response.success)")
        
        // Remove from local arrays
        await MainActor.run {
            self.targets.removeAll { $0.id == targetId }
            self.goals.removeAll { $0.id == targetId }
        }
        
        // Refresh data to sync with backend
        refresh()
    }
}

