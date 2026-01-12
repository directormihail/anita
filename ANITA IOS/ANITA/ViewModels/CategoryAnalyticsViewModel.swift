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
                // Load transactions filtered by period
                let transactionsResponse = try await networkService.getTransactions(
                    userId: userId,
                    month: month,
                    year: year
                )
                let analyticsData = calculateCategoryAnalytics(from: transactionsResponse.transactions)
                
                await MainActor.run {
                    self.categoryData = analyticsData
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
}

