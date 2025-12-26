//
//  SidebarViewModel.swift
//  ANITA
//
//  ViewModel for sidebar menu functionality
//

import Foundation
import SwiftUI

@MainActor
class SidebarViewModel: ObservableObject {
    @Published var balance: Double = 0.0
    @Published var income: Double = 0.0
    @Published var expense: Double = 0.0
    @Published var xp: Int = 0
    @Published var xpToNextLevel: Int = 0
    @Published var level: Int = 1
    @Published var levelTitle: String = "NEWCOMER"
    @Published var conversations: [ConversationItem] = []
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
                async let conversationsTask = networkService.getConversations(userId: userId)
                async let xpStatsTask = networkService.getXPStats(userId: userId)
                
                let metrics = try await metricsTask
                let conversationsResponse = try await conversationsTask
                let xpStats = try await xpStatsTask
                
                await MainActor.run {
                    // Update financial metrics
                    self.balance = metrics.metrics.totalBalance
                    self.income = metrics.metrics.monthlyIncome
                    self.expense = metrics.metrics.monthlyExpenses
                    
                    // Update XP stats
                    self.xp = xpStats.xpStats.total_xp
                    self.xpToNextLevel = xpStats.xpStats.xp_to_next_level
                    self.level = xpStats.xpStats.current_level
                    self.levelTitle = xpStats.xpStats.level_title.uppercased()
                    
                    // Convert conversations to ConversationItem format
                    self.conversations = conversationsResponse.conversations.map { conv in
                        let dateFormatter = ISO8601DateFormatter()
                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let date = dateFormatter.date(from: conv.updated_at) ?? dateFormatter.date(from: conv.created_at) ?? Date()
                        
                        let calendar = Calendar.current
                        let isToday = calendar.isDateInToday(date)
                        
                        return ConversationItem(
                            id: conv.id,
                            title: conv.title ?? "Untitled Conversation",
                            date: date,
                            isToday: isToday
                        )
                    }
                    
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
}

