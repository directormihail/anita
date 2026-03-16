//
//  CategoryAnalyticsViewModel.swift
//  ANITA
//
//  ViewModel for category analytics functionality
//

import Foundation
import SwiftUI

/// Returns (first day YYYY-MM-DD, last day YYYY-MM-DD) for the given month/year for bank transaction API.
private func monthRange(calendar: Calendar, month: Int?, year: Int?) -> (String, String) {
    let now = Date()
    let m = month ?? calendar.component(.month, from: now)
    let y = year ?? calendar.component(.year, from: now)
    let fromStr = String(format: "%04d-%02d-01", y, m)
    var comp = DateComponents(year: y, month: m, day: 1)
    guard let firstDay = calendar.date(from: comp),
          let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else {
        return (fromStr, fromStr)
    }
    let toStr = String(format: "%04d-%02d-%02d", y, m, calendar.component(.day, from: lastDay))
    return (fromStr, toStr)
}

@MainActor
class CategoryAnalyticsViewModel: ObservableObject {
    @Published var categoryData: CategoryAnalyticsData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var categoryTrends: [String: CategoryTrend] = [:]
    
    private let networkService = NetworkService.shared
    private let userId: String

    /// Backend user id: requires Supabase auth so analytics reflect server data shared across devices.
    private var effectiveUserId: String? {
        guard let authed = UserManager.shared.currentUser, UserManager.shared.isAuthenticated else {
            return nil
        }
        return authed.id
    }
    
    // Period filtering - defaults to current month
    var selectedMonth: Date? = nil
    var selectedYear: Int? = nil
    
    // Predefined colors for categories
    private let categoryColors: [Color] = [
        Color(red: 0.2, green: 0.5, blue: 0.9),      // Blue
        Color(red: 0.6, green: 0.4, blue: 0.9),       // Purple
        Color(red: 0.4, green: 0.7, blue: 0.9),       // Light Blue
        Color(red: 1.0, green: 0.6, blue: 0.2),      // Orange
        Color(red: 0.2, green: 0.8, blue: 0.4),      // Green
        Color(red: 0.9, green: 0.3, blue: 0.3),      // Red
        Color(red: 0.9, green: 0.7, blue: 0.2),      // Yellow
        Color(red: 0.7, green: 0.3, blue: 0.8),      // Magenta
    ]
    
    init(userId: String? = nil) {
        self.userId = userId ?? UserManager.shared.userId
    }

    func loadData(month: Int? = nil, year: Int? = nil) {
        isLoading = true
        errorMessage = nil
        
        // Store period for refresh
        if let month = month, let year = year {
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            self.selectedMonth = calendar.date(from: components)
            self.selectedYear = year
        }
        
        Task {
            do {
                let calendar = Calendar.current
                guard let userId = self.effectiveUserId else {
                    await MainActor.run {
                        self.errorMessage = "Please log in to see category analytics on all devices."
                        self.isLoading = false
                    }
                    return
                }
                var currentTransactions: [TransactionItem] = []
                var previousMonthData: [TransactionItem] = []

                if UserManager.shared.usesBankDataOnly {
                    // Bank-only mode: use bank transactions (same source as Transactions list and health score)
                    let (fromStr, toStr) = monthRange(calendar: calendar, month: month, year: year)
                    let bankResponse = try await networkService.getBankTransactions(
                        userId: userId,
                        from: fromStr,
                        to: toStr,
                        limit: 1000
                    )
                    currentTransactions = bankResponse.transactions.map { $0.toTransactionItem() }
                    
                    if let month = month, let year = year,
                       let currentMonthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                       let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonthDate) {
                        let prevMonth = calendar.component(.month, from: previousMonthDate)
                        let prevYear = calendar.component(.year, from: previousMonthDate)
                        let (prevFrom, prevTo) = monthRange(calendar: calendar, month: prevMonth, year: prevYear)
                        do {
                            let prevBank = try await networkService.getBankTransactions(
                                userId: userId,
                                from: prevFrom,
                                to: prevTo,
                                limit: 1000
                            )
                            previousMonthData = prevBank.transactions.map { $0.toTransactionItem() }
                        } catch {
                            print("[CategoryAnalyticsViewModel] Error loading previous month bank data: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Manual mode: include BOTH manual (anita_data) and bank transactions so Insights reflects all activity.
                    async let manualCurrent = networkService.getTransactions(
                        userId: userId,
                        month: month,
                        year: year
                    )
                    async let manualPrevious: GetTransactionsResponse? = {
                        if let month = month, let year = year,
                           let currentMonthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                           let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonthDate) {
                            let prevMonth = calendar.component(.month, from: previousMonthDate)
                            let prevYear = calendar.component(.year, from: previousMonthDate)
                            return try? await networkService.getTransactions(
                                userId: userId,
                                month: prevMonth,
                                year: prevYear
                            )
                        }
                        return nil
                    }()
                    
                    async let bankCurrent: GetBankTransactionsResponse? = {
                        let (fromStr, toStr) = monthRange(calendar: calendar, month: month, year: year)
                        return try? await networkService.getBankTransactions(
                            userId: userId,
                            from: fromStr,
                            to: toStr,
                            limit: 1000
                        )
                    }()
                    
                    async let bankPrevious: [TransactionItem]? = {
                        if let month = month, let year = year,
                           let currentMonthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                           let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonthDate) {
                            let prevMonth = calendar.component(.month, from: previousMonthDate)
                            let prevYear = calendar.component(.year, from: previousMonthDate)
                            let (prevFrom, prevTo) = monthRange(calendar: calendar, month: prevMonth, year: prevYear)
                            if let resp = try? await networkService.getBankTransactions(
                                userId: userId,
                                from: prevFrom,
                                to: prevTo,
                                limit: 1000
                            ) {
                                return resp.transactions.map { $0.toTransactionItem() }
                            }
                        }
                        return nil
                    }()
                    
                    let manualCurrentResp = try await manualCurrent
                    let manualPreviousResp = await manualPrevious
                    let bankCurrentResp = await bankCurrent
                    let bankPreviousTx = await bankPrevious
                    
                    currentTransactions = manualCurrentResp.transactions
                    if let bankTx = bankCurrentResp?.transactions {
                        currentTransactions.append(contentsOf: bankTx.map { $0.toTransactionItem() })
                    }
                    
                    previousMonthData = manualPreviousResp?.transactions ?? []
                    if let bankPrev = bankPreviousTx {
                        previousMonthData.append(contentsOf: bankPrev)
                    }
                }

                let analyticsData = calculateCategoryAnalytics(from: currentTransactions)
                let trends = calculateCategoryTrends(
                    current: currentTransactions,
                    previous: previousMonthData
                )

                await MainActor.run {
                    self.categoryData = analyticsData
                    self.categoryTrends = trends
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
        // Use stored period if available, otherwise use current month
        let calendar = Calendar.current
        if let selectedMonth = selectedMonth {
            let month = calendar.component(.month, from: selectedMonth)
            let year = calendar.component(.year, from: selectedMonth)
            loadData(month: month, year: year)
        } else {
            let now = Date()
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            loadData(month: month, year: year)
        }
    }
    
    private func calculateCategoryAnalytics(from transactions: [TransactionItem]) -> CategoryAnalyticsData {
        // Filter only expense transactions
        let expenses = transactions.filter { $0.type == "expense" }
        
        // Group by category
        var categoryTotals: [String: Double] = [:]
        
        for transaction in expenses {
            // Normalize category to proper case (not all caps)
            let categoryName = CategoryDefinitions.shared.normalizeCategory(transaction.category)
            categoryTotals[categoryName, default: 0.0] += transaction.amount
        }
        
        // Calculate total
        let totalAmount = categoryTotals.values.reduce(0, +)
        
        // Create category analytics sorted by amount (descending)
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        
        var categories: [CategoryAnalytics] = []
        for (index, (name, amount)) in sortedCategories.enumerated() {
            let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
            let color = categoryColors[index % categoryColors.count]
            
            categories.append(CategoryAnalytics(
                id: name,
                name: name,
                amount: amount,
                percentage: percentage,
                color: color
            ))
        }
        
        return CategoryAnalyticsData(
            categories: categories,
            totalAmount: totalAmount,
            categoryCount: categories.count
        )
    }
    
    private func calculateCategoryTrends(current: [TransactionItem], previous: [TransactionItem]) -> [String: CategoryTrend] {
        var trends: [String: CategoryTrend] = [:]
        
        // Calculate current month spending by category
        var currentSpending: [String: Double] = [:]
        for transaction in current where transaction.type == "expense" {
            let categoryName = CategoryDefinitions.shared.normalizeCategory(transaction.category)
            currentSpending[categoryName, default: 0.0] += transaction.amount
        }
        
        // Calculate previous month spending by category
        var previousSpending: [String: Double] = [:]
        for transaction in previous where transaction.type == "expense" {
            let categoryName = CategoryDefinitions.shared.normalizeCategory(transaction.category)
            previousSpending[categoryName, default: 0.0] += transaction.amount
        }
        
        // Calculate trends for all categories that appear in either period
        let allCategories = Set(currentSpending.keys).union(Set(previousSpending.keys))
        
        for category in allCategories {
            let currentAmount = currentSpending[category] ?? 0.0
            let previousAmount = previousSpending[category] ?? 0.0
            
            var percentageChange: Double = 0.0
            if previousAmount > 0 {
                percentageChange = ((currentAmount - previousAmount) / previousAmount) * 100.0
            } else if currentAmount > 0 {
                percentageChange = 100.0
            }
            
            trends[category] = CategoryTrend(
                currentAmount: currentAmount,
                previousAmount: previousAmount,
                change: currentAmount - previousAmount,
                percentageChange: percentageChange
            )
        }
        
        return trends
    }
}

struct CategoryTrend {
    let currentAmount: Double
    let previousAmount: Double
    let change: Double
    let percentageChange: Double
    
    var isPositive: Bool {
        change >= 0
    }
}

