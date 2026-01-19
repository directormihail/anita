//
//  CategoryAnalyticsViewModel.swift
//  ANITA
//
//  ViewModel for category analytics functionality
//

import Foundation
import SwiftUI

@MainActor
class CategoryAnalyticsViewModel: ObservableObject {
    @Published var categoryData: CategoryAnalyticsData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var categoryTrends: [String: CategoryTrend] = [:]
    
    private let networkService = NetworkService.shared
    private let userId: String
    
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
                // Load transactions filtered by period
                let transactionsResponse = try await networkService.getTransactions(
                    userId: userId,
                    month: month,
                    year: year
                )
                let analyticsData = calculateCategoryAnalytics(from: transactionsResponse.transactions)
                
                // Load previous month data for trend comparison
                var previousMonthData: [TransactionItem] = []
                if let month = month, let year = year,
                   let currentMonthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                   let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonthDate) {
                    let prevMonth = calendar.component(.month, from: previousMonthDate)
                    let prevYear = calendar.component(.year, from: previousMonthDate)
                    do {
                        let prevResponse = try await networkService.getTransactions(
                            userId: userId,
                            month: prevMonth,
                            year: prevYear
                        )
                        previousMonthData = prevResponse.transactions
                    } catch {
                        print("[CategoryAnalyticsViewModel] Error loading previous month data: \(error.localizedDescription)")
                    }
                }
                
                // Calculate trends
                let trends = calculateCategoryTrends(
                    current: transactionsResponse.transactions,
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

