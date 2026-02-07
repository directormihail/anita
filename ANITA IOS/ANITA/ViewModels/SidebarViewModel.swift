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
    @Published var xpStats: XPStats?
    @Published var conversations: [ConversationItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    private let userManager = UserManager.shared

    // Must retain observer tokens or they are deallocated and notifications never fire
    private var userDidSignInObserver: NSObjectProtocol?
    private var conversationCreatedObserver: NSObjectProtocol?
    private var xpStatsDidUpdateObserver: NSObjectProtocol?
    
    init(userId: String? = nil) {
        // Note: We don't store userId as a property anymore
        // Instead, we always get it fresh from UserManager when loading data
        // This ensures we use the correct authenticated user ID
        print("[SidebarViewModel] Initialized")
        
        // Observe authentication changes to refresh data
        userDidSignInObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidSignIn"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadData()
            }
        }
        
        // Observe conversation creation to refresh conversation list
        conversationCreatedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ConversationCreated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[SidebarViewModel] Conversation created, refreshing conversation list...")
            Task { @MainActor in
                self?.loadData()
            }
        }

        // Observe XP updates (e.g. after sending a chat message) to refresh stats
        xpStatsDidUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("XPStatsDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadData()
            }
        }
    }

    deinit {
        if let o = userDidSignInObserver { NotificationCenter.default.removeObserver(o) }
        if let o = conversationCreatedObserver { NotificationCenter.default.removeObserver(o) }
        if let o = xpStatsDidUpdateObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        // Get the current userId (in case it changed after authentication)
        let currentUserId = UserManager.shared.userId
        print("[SidebarViewModel] Loading data for userId: \(currentUserId)")
        
        Task {
            // First, check if backend is reachable
            do {
                print("[SidebarViewModel] Checking backend health...")
                _ = try await networkService.checkHealth()
                print("[SidebarViewModel] Backend health check passed")
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    print("[SidebarViewModel] Backend health check failed: \(errorMsg)")
                    
                    // Provide helpful error message
                    var userFriendlyError = "Could not connect to the server.\n\n"
                    
                    if errorMsg.contains("timed out") || errorMsg.contains("timeout") {
                        userFriendlyError += "Request timed out.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL is correct in Settings\n3. Device and backend are on same network"
                    } else if errorMsg.contains("cannot find host") || errorMsg.contains("cannot connect") {
                        userFriendlyError += "Cannot reach backend server.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings:\n   - Simulator: http://localhost:3001\n   - Physical device: http://YOUR_MAC_IP:3001\n3. Both devices on same Wi-Fi network"
                    } else if errorMsg.contains("No internet connection") {
                        userFriendlyError = "No internet connection. Please check your network settings."
                    } else {
                        userFriendlyError += "Error: \(errorMsg)\n\nPlease check:\n1. Backend is running\n2. Backend URL is correct in Settings"
                    }
                    
                    self.errorMessage = userFriendlyError
                    self.isLoading = false
                }
                return
            }
            
            // If health check passes, load all data
            do {
                print("[SidebarViewModel] Loading data from backend...")
                // Load all data in parallel
                async let metricsTask = networkService.getFinancialMetrics(userId: currentUserId)
                async let conversationsTask = networkService.getConversations(userId: currentUserId)
                async let xpStatsTask = networkService.getXPStats(userId: currentUserId)
                
                let metrics = try await metricsTask
                let conversationsResponse = try await conversationsTask
                let xpStats = try await xpStatsTask
                
                await MainActor.run {
                    print("[SidebarViewModel] Successfully loaded data:")
                    print("  - Total Balance: \(metrics.metrics.totalBalance)")
                    print("  - Total Income: \(metrics.metrics.totalIncome)")
                    print("  - Total Expenses: \(metrics.metrics.totalExpenses)")
                    print("  - Monthly Income: \(metrics.metrics.monthlyIncome)")
                    print("  - Monthly Expenses: \(metrics.metrics.monthlyExpenses)")
                    print("  - XP: \(xpStats.xpStats.total_xp)")
                    print("  - Conversations: \(conversationsResponse.conversations.count)")
                    
                    // Update financial metrics
                    // Match webapp behavior: webapp shows current month values by default
                    // If monthly values are 0 (no transactions this month), show total values as fallback
                    // This provides more useful information to the user
                    let displayIncome = metrics.metrics.monthlyIncome > 0 ? metrics.metrics.monthlyIncome : metrics.metrics.totalIncome
                    let displayExpense = metrics.metrics.monthlyExpenses > 0 ? metrics.metrics.monthlyExpenses : metrics.metrics.totalExpenses
                    
                    // Ensure we have valid numbers (not NaN or null)
                    self.balance = metrics.metrics.totalBalance.isNaN ? 0.0 : metrics.metrics.totalBalance
                    self.income = displayIncome.isNaN ? 0.0 : displayIncome
                    self.expense = displayExpense.isNaN ? 0.0 : displayExpense
                    
                    // Update XP stats (full object for 1:1 card with finance page). Use display rules: 100 XP/level, 10 levels, L10 endless.
                    let raw = xpStats.xpStats
                    let stats = XPStats.from(totalXP: raw.total_xp)
                    self.xpStats = stats
                    XPStore.shared.update(with: stats)
                    self.xp = stats.total_xp
                    self.xpToNextLevel = stats.xp_to_next_level
                    self.level = stats.current_level
                    self.levelTitle = stats.level_title.uppercased()

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
                    self.errorMessage = nil // Clear any previous errors
                }

                // Record app open; may award 100 XP (week_streak_7) if user opened 7 days this week
                if let openResponse = try? await networkService.appOpen(userId: currentUserId), openResponse.awardedStreak == true {
                    if let newStats = try? await networkService.getXPStats(userId: currentUserId) {
                        await MainActor.run {
                            let stats = XPStats.from(totalXP: newStats.xpStats.total_xp)
                            self.xpStats = stats
                            self.xp = stats.total_xp
                            self.xpToNextLevel = stats.xp_to_next_level
                            self.level = stats.current_level
                            self.levelTitle = stats.level_title.uppercased()
                            XPStore.shared.update(with: stats)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    print("[SidebarViewModel] Error loading data: \(errorMsg)")
                    print("[SidebarViewModel] Error details: \(error)")
                    
                    // Provide more helpful error messages
                    var userFriendlyError = errorMsg
                    if errorMsg.contains("timed out") || errorMsg.contains("timeout") {
                        userFriendlyError = "Request timed out. Please check:\n1. Backend is running (cd 'ANITA backend' && npm run dev)\n2. Backend URL is correct in Settings\n3. Device and backend are on same network"
                    } else if errorMsg.contains("cannot find host") || errorMsg.contains("cannot connect") || errorMsg.contains("Could not connect") {
                        userFriendlyError = "Could not connect to the server.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings is: http://localhost:3001\n3. For physical device: Use your Mac's IP address (e.g., http://192.168.1.100:3001)"
                    } else if errorMsg.contains("The Internet connection appears to be offline") || errorMsg.contains("No internet connection") {
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
}

