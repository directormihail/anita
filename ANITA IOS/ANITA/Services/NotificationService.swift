//
//  NotificationService.swift
//  ANITA
//
//  Service for managing local push notifications
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    @Published var pushNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(pushNotificationsEnabled, forKey: "anita_push_notifications_enabled")
            if pushNotificationsEnabled {
                requestAuthorization()
                // Schedule monthly summary when notifications are enabled
                scheduleMonthlySummary()
            }
        }
    }
    
    private var lastBudgetNotification: [String: [Double]] = [:] // Track last notified percentages per goal
    private var lastGoalMilestone: [String: [Double]] = [:] // Track last notified milestones per goal
    private var lastTransactionDate: Date? // Track when last transaction was added
    private var lastTransactionReminderDate: Date? // Track when we last reminded about transactions
    
    override init() {
        self.pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "anita_push_notifications_enabled")
        super.init()
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Check current authorization status
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        print("[NotificationService] Requesting notification authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    print("[NotificationService] ❌ Authorization error: \(error.localizedDescription)")
                } else {
                    print("[NotificationService] ✅ Authorization result: \(granted ? "GRANTED" : "DENIED")")
                    if granted {
                        // Schedule monthly summary when authorization is granted
                        self?.scheduleMonthlySummary()
                        print("[NotificationService] Monthly summary scheduled")
                    } else {
                        print("[NotificationService] ⚠️ User denied notification permissions")
                    }
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
                print("[NotificationService] Authorization status checked: \(settings.authorizationStatus.rawValue) -> authorized: \(self?.isAuthorized ?? false)")
                
                if settings.authorizationStatus == .denied {
                    print("[NotificationService] ⚠️ Notifications are denied. User needs to enable in Settings app.")
                } else if settings.authorizationStatus == .notDetermined {
                    print("[NotificationService] ⚠️ Notification permission not determined yet.")
                }
            }
        }
    }
    
    // MARK: - Budget Limit Notifications
    
    func checkBudgetLimits(goals: [Target], transactions: [TransactionItem], selectedMonth: Date) {
        print("[NotificationService] checkBudgetLimits called - enabled: \(pushNotificationsEnabled), authorized: \(isAuthorized), goals: \(goals.count), transactions: \(transactions.count)")
        
        guard pushNotificationsEnabled && isAuthorized else {
            print("[NotificationService] Notifications disabled or not authorized. Enabled: \(pushNotificationsEnabled), Authorized: \(isAuthorized)")
            return
        }
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedMonth)
        let year = calendar.component(.year, from: selectedMonth)
        
        // Filter transactions for the selected month
        let monthTransactions = transactions.filter { transaction in
            if let date = ISO8601DateFormatter().date(from: transaction.date) {
                let transactionMonth = calendar.component(.month, from: date)
                let transactionYear = calendar.component(.year, from: date)
                return transactionMonth == month && transactionYear == year
            }
            return false
        }
        
        // Check each budget goal (goals with category)
        for goal in goals where goal.targetType == "budget" || (goal.category != nil && !goal.category!.isEmpty) {
            guard let category = goal.category, !category.isEmpty else { continue }
            
            // Calculate spending for this category in the selected month
            let categorySpending = monthTransactions
                .filter { $0.type == "expense" && $0.category.lowercased() == category.lowercased() }
                .reduce(0.0) { $0 + $1.amount }
            
            let percentage = (categorySpending / goal.targetAmount) * 100
            
            // Check thresholds: 80%, 100%, 120%
            let thresholds: [Double] = [80, 100, 120]
            
            for threshold in thresholds {
                if percentage >= threshold {
                    // Check if we've already notified for this threshold
                    let lastNotified = lastBudgetNotification[goal.id] ?? []
                    if !lastNotified.contains(threshold) {
                        // Check if we've crossed this threshold (not just equal)
                        let previousThresholds = lastNotified.filter { $0 < threshold }
                        if previousThresholds.isEmpty || percentage > threshold {
                            sendBudgetLimitNotification(
                                goal: goal,
                                category: category,
                                spending: categorySpending,
                                limit: goal.targetAmount,
                                percentage: percentage,
                                threshold: threshold
                            )
                            
                            // Update last notified thresholds
                            var updated = lastNotified
                            updated.append(threshold)
                            lastBudgetNotification[goal.id] = updated
                        }
                    }
                }
            }
            
            // Reset if spending drops below 80%
            if percentage < 80 {
                lastBudgetNotification[goal.id] = []
            }
        }
    }
    
    private func sendBudgetLimitNotification(goal: Target, category: String, spending: Double, limit: Double, percentage: Double, threshold: Double) {
        let content = UNMutableNotificationContent()
        
        let currency = goal.currency
        let spendingFormatted = formatCurrency(spending, currency: currency)
        let limitFormatted = formatCurrency(limit, currency: currency)
        
        // Funny passive-aggressive messages like Duolingo
        if threshold >= 120 {
            let messages = [
                "💸 Your \(category) budget called. It wants a divorce. You've spent \(spendingFormatted) of \(limitFormatted).",
                "🚨 Breaking news: You've exceeded your \(category) budget by \(Int(percentage - 100))%! Your wallet is crying. \(spendingFormatted) of \(limitFormatted).",
                "📢 Public service announcement: Your \(category) spending is \(Int(percentage - 100))% over budget. Maybe time to... stop? \(spendingFormatted) of \(limitFormatted).",
                "🎭 Plot twist: You've spent \(spendingFormatted) on \(category), which is \(Int(percentage - 100))% over your \(limitFormatted) limit. Surprise!",
                "💀 RIP your \(category) budget. You've spent \(spendingFormatted) of \(limitFormatted). It was nice knowing you."
            ]
            content.title = "Your Budget is Screaming"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .defaultCritical
        } else if threshold >= 100 {
            let messages = [
                "🎯 Congratulations! You've hit your \(category) budget limit! \(spendingFormatted) of \(limitFormatted). Now what?",
                "🏁 You've reached the finish line! Your \(category) budget is at \(limitFormatted). Time to stop spending?",
                "✅ Mission accomplished: You've spent exactly \(spendingFormatted) on \(category). Your budget is... not happy.",
                "🎪 The circus is here! You've maxed out your \(category) budget at \(limitFormatted). Enjoy the show!",
                "🔔 Ding ding ding! \(category) budget limit reached: \(spendingFormatted) of \(limitFormatted). No more spending for you!"
            ]
            content.title = "Budget Limit Reached"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default
        } else {
            let messages = [
                "👀 Hey there, big spender! You're at \(Int(threshold))% of your \(category) budget. \(spendingFormatted) of \(limitFormatted). Still time to reconsider?",
                "⚠️ Friendly reminder: You've spent \(spendingFormatted) on \(category), which is \(Int(threshold))% of your \(limitFormatted) limit. Just saying...",
                "📊 Quick update: \(Int(threshold))% of \(category) budget used (\(spendingFormatted) of \(limitFormatted)). Your future self is watching.",
                "🎪 The \(category) spending show is at \(Int(threshold))%! \(spendingFormatted) of \(limitFormatted). Tickets still available!",
                "💡 Pro tip: You're at \(Int(threshold))% of your \(category) budget (\(spendingFormatted) of \(limitFormatted)). Maybe slow down?"
            ]
            content.title = "Budget Check-in"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default
        }
        
        content.categoryIdentifier = "BUDGET_ALERT"
        content.userInfo = [
            "type": "budget_limit",
            "goalId": goal.id,
            "category": category,
            "threshold": threshold
        ]
        
        // Use a small delay trigger for immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "budget_\(goal.id)_\(Int(threshold))_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending budget notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Budget notification sent successfully: \(content.title) - \(content.body)")
            }
        }
    }
    
    // MARK: - Goal Milestone Notifications
    
    func checkGoalMilestones(goals: [Target]) {
        print("[NotificationService] checkGoalMilestones called - enabled: \(pushNotificationsEnabled), authorized: \(isAuthorized), goals: \(goals.count)")
        
        guard pushNotificationsEnabled && isAuthorized else {
            print("[NotificationService] Notifications disabled or not authorized for goal milestones")
            return
        }
        
        // Check savings goals (goals without category)
        for goal in goals where goal.targetType == "savings" || (goal.category == nil || goal.category!.isEmpty) {
            let progress = goal.progressPercentage
            let milestones: [Double] = [25, 50, 75, 100]
            
            for milestone in milestones {
                if progress >= milestone {
                    // Check if we've already notified for this milestone
                    let lastNotified = lastGoalMilestone[goal.id] ?? []
                    if !lastNotified.contains(milestone) {
                        // Check if we've crossed this milestone
                        let previousMilestones = lastNotified.filter { $0 < milestone }
                        if previousMilestones.isEmpty || progress > milestone {
                            sendGoalMilestoneNotification(goal: goal, milestone: milestone, progress: progress)
                            
                            // Update last notified milestones
                            var updated = lastNotified
                            updated.append(milestone)
                            lastGoalMilestone[goal.id] = updated
                        }
                    }
                }
            }
            
            // Reset if progress drops (shouldn't happen, but just in case)
            if progress < 25 {
                lastGoalMilestone[goal.id] = []
            }
        }
    }
    
    private func sendGoalMilestoneNotification(goal: Target, milestone: Double, progress: Double) {
        let content = UNMutableNotificationContent()
        
        let currency = goal.currency
        let currentFormatted = formatCurrency(goal.currentAmount, currency: currency)
        let targetFormatted = formatCurrency(goal.targetAmount, currency: currency)
        
        if milestone >= 100 {
            let messages = [
                "🏆 LEGEND! You've saved \(currentFormatted) for \(goal.title)! Your future self is doing a happy dance!",
                "🎊 You did it! \(goal.title) goal COMPLETE! \(currentFormatted) saved. Time to celebrate (responsibly)!",
                "🌟 Achievement unlocked: \(goal.title)! You saved \(currentFormatted). Now go treat yourself (within budget, of course).",
                "💪 You're a financial wizard! \(currentFormatted) saved for \(goal.title). Your bank account is proud!",
                "🎯 Bullseye! \(goal.title) goal achieved! \(currentFormatted) saved. You're officially awesome!"
            ]
            content.title = "Goal Achieved! 🎉"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .defaultCritical
        } else {
            let messages = [
                "🎯 \(Int(milestone))% there! You've saved \(currentFormatted) of \(targetFormatted) for \(goal.title). Keep going, champ!",
                "📈 Progress update: \(Int(milestone))% of \(goal.title) complete! \(currentFormatted) of \(targetFormatted). You got this!",
                "💪 \(Int(milestone))% milestone reached! \(currentFormatted) saved for \(goal.title). Your wallet is getting stronger!",
                "🚀 You're \(Int(milestone))% of the way to \(goal.title)! \(currentFormatted) of \(targetFormatted). Don't stop now!",
                "⭐ Quarter \(Int(milestone)/25) complete! \(currentFormatted) saved for \(goal.title). Only \(formatCurrency(goal.targetAmount - goal.currentAmount, currency: currency)) to go!"
            ]
            content.title = "Goal Progress: \(goal.title)"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default
        }
        
        content.categoryIdentifier = "GOAL_MILESTONE"
        content.userInfo = [
            "type": "goal_milestone",
            "goalId": goal.id,
            "milestone": milestone
        ]
        
        // Use a small delay trigger for immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "goal_\(goal.id)_\(Int(milestone))_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending goal notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Goal notification sent successfully: \(content.title) - \(content.body)")
            }
        }
    }
    
    // MARK: - Unusual Spending Pattern Notifications
    
    func checkUnusualSpending(transactions: [TransactionItem], selectedMonth: Date) {
        guard pushNotificationsEnabled && isAuthorized else { return }
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedMonth)
        let year = calendar.component(.year, from: selectedMonth)
        
        // Filter transactions for the selected month
        let monthTransactions = transactions.filter { transaction in
            if let date = ISO8601DateFormatter().date(from: transaction.date) {
                let transactionMonth = calendar.component(.month, from: date)
                let transactionYear = calendar.component(.year, from: date)
                return transactionMonth == month && transactionYear == year && transaction.type == "expense"
            }
            return false
        }
        
        // Group by category
        let categorySpending = Dictionary(grouping: monthTransactions, by: { $0.category })
            .mapValues { transactions in
                transactions.reduce(0.0) { $0 + $1.amount }
            }
        
        // Calculate average spending per category
        let totalSpending = categorySpending.values.reduce(0.0, +)
        let averagePerCategory = totalSpending / Double(max(categorySpending.count, 1))
        
        // Find categories with unusually high spending (more than 3x average)
        for (category, spending) in categorySpending {
            if spending > averagePerCategory * 3 && spending > 100 { // Only alert for significant amounts
                sendUnusualSpendingNotification(category: category, amount: spending)
                break // Only send one notification per check
            }
        }
    }
    
    private func sendUnusualSpendingNotification(category: String, amount: Double) {
        // Check if we've already sent this notification today
        let todayKey = "unusual_\(category)_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        if UserDefaults.standard.bool(forKey: todayKey) {
            return
        }
        
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let amountFormatted = formatCurrency(amount, currency: currency)
        
        let messages = [
            "🤔 Interesting... You've spent \(amountFormatted) on \(category) this month. That's... a lot. Just an observation.",
            "📊 PSA: Your \(category) spending (\(amountFormatted)) is unusually high. Your other categories are feeling neglected.",
            "🎭 Plot twist: You've spent \(amountFormatted) on \(category). That's 3x your average. No judgment, just... wow.",
            "💸 Breaking: \(category) spending alert! \(amountFormatted) this month. Your wallet wants to have a word.",
            "🚨 Unusual activity detected: \(amountFormatted) on \(category). Is everything okay? Asking for a friend (your budget)."
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Spending Pattern Alert"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "UNUSUAL_SPENDING"
        content.userInfo = [
            "type": "unusual_spending",
            "category": category,
            "amount": amount
        ]
        
        // Use a small delay trigger for immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "unusual_\(category)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending unusual spending notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Unusual spending notification sent successfully")
                UserDefaults.standard.set(true, forKey: todayKey)
            }
        }
    }
    
    // MARK: - Monthly Summary Notifications
    
    func scheduleMonthlySummary() {
        guard pushNotificationsEnabled && isAuthorized else { return }
        
        // Remove existing monthly summary notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["monthly_summary"])
        
        // Schedule for the 1st of each month at 9 AM
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let messages = [
            "📊 Your monthly financial report is ready! Spoiler: your wallet has opinions.",
            "📈 Monthly summary time! Let's see how your money behaved last month...",
            "🎯 Time for your monthly financial check-in! No judgment, just facts (and maybe some judgment).",
            "📋 Your financial report card is in! Spoiler alert: it's... interesting.",
            "💼 Monthly financial summary ready! Your money wants to talk. It's not happy."
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Monthly Summary Ready"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "MONTHLY_SUMMARY"
        content.userInfo = ["type": "monthly_summary"]
        
        let request = UNNotificationRequest(
            identifier: "monthly_summary",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Error scheduling monthly summary: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Bill Reminder Notifications
    
    func scheduleBillReminder(title: String, amount: Double, dueDate: Date, currency: String = "USD") {
        guard pushNotificationsEnabled && isAuthorized else { return }
        
        // Schedule reminder 3 days before due date
        let reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: dueDate) ?? dueDate
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let amountFormatted = formatCurrency(amount, currency: currency)
        
        let messages = [
            "💳 Friendly reminder: \(title) bill (\(amountFormatted)) is due in 3 days. Your future self will thank you.",
            "📅 Hey! \(title) wants \(amountFormatted) in 3 days. Don't make it angry.",
            "⏰ 3 days until \(title) bill (\(amountFormatted)) is due. Time to pay up!",
            "🔔 Bill alert: \(title) needs \(amountFormatted) in 3 days. It's waiting...",
            "💸 PSA: \(title) bill (\(amountFormatted)) due in 3 days. Your wallet is ready (hopefully)."
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Bill Reminder: \(title)"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "BILL_REMINDER"
        content.userInfo = [
            "type": "bill_reminder",
            "title": title,
            "amount": amount,
            "dueDate": ISO8601DateFormatter().string(from: dueDate)
        ]
        
        let request = UNNotificationRequest(
            identifier: "bill_\(title)_\(dueDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Error scheduling bill reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    // MARK: - Transaction Reminder Notifications
    
    func checkTransactionReminders(transactions: [TransactionItem], hasAutoBanking: Bool = false) {
        // Only show reminders if user doesn't have auto banking connection
        guard !hasAutoBanking else {
            print("[NotificationService] Auto banking enabled, skipping transaction reminders")
            return
        }
        
        guard pushNotificationsEnabled && isAuthorized else { return }
        
        // Find the most recent transaction
        let sortedTransactions = transactions.sorted { transaction1, transaction2 in
            let date1 = ISO8601DateFormatter().date(from: transaction1.date) ?? Date.distantPast
            let date2 = ISO8601DateFormatter().date(from: transaction2.date) ?? Date.distantPast
            return date1 > date2
        }
        
        let mostRecentTransactionDate = sortedTransactions.first.flatMap { transaction in
            ISO8601DateFormatter().date(from: transaction.date)
        }
        
        // Update last transaction date
        if let mostRecentDate = mostRecentTransactionDate {
            lastTransactionDate = mostRecentDate
        }
        
        // Check if we should send a reminder
        let now = Date()
        let daysSinceLastTransaction: Int
        
        // Handle case when there are no transactions at all
        if transactions.isEmpty {
            // Check if we've reminded about empty transactions before
            if let lastReminderDate = lastTransactionReminderDate {
                let daysSinceLastReminder = Calendar.current.dateComponents([.day], from: lastReminderDate, to: now).day ?? 0
                if daysSinceLastReminder >= 1 {
                    // Remind again after 1 day
                    sendTransactionReminder(urgency: .first, daysSince: 1)
                    lastTransactionReminderDate = now
                }
            } else {
                // First time - remind immediately if it's been at least 1 day since app install
                // For now, we'll remind if no transactions exist
                sendTransactionReminder(urgency: .first, daysSince: 1)
                lastTransactionReminderDate = now
            }
            return
        }
        
        // We have transactions, check the last one
        guard let lastDate = lastTransactionDate else {
            // Can't determine last transaction date, skip
            return
        }
        
        daysSinceLastTransaction = Calendar.current.dateComponents([.day], from: lastDate, to: now).day ?? 0
        
        // Don't remind if we already reminded today
        if let lastReminderDate = lastTransactionReminderDate {
            let daysSinceLastReminder = Calendar.current.dateComponents([.day], from: lastReminderDate, to: now).day ?? 0
            if daysSinceLastReminder < 1 {
                return
            }
        }
        
        // Send reminders based on days since last transaction
        if daysSinceLastTransaction >= 7 {
            // 7+ days - urgent reminder
            sendTransactionReminder(urgency: .urgent, daysSince: daysSinceLastTransaction)
            lastTransactionReminderDate = now
        } else if daysSinceLastTransaction >= 3 {
            // 3-6 days - gentle reminder
            sendTransactionReminder(urgency: .gentle, daysSince: daysSinceLastTransaction)
            lastTransactionReminderDate = now
        }
    }
    
    private enum ReminderUrgency {
        case first
        case gentle
        case urgent
    }
    
    private func sendTransactionReminder(urgency: ReminderUrgency, daysSince: Int) {
        let content = UNMutableNotificationContent()
        
        switch urgency {
        case .first:
            let messages = [
                "👋 Hey! It's been a day since you started. Want to add your first transaction? Your budget is waiting...",
                "📝 Day 1 check-in: Ready to track your spending? Add a transaction and let's get started!",
                "💰 Your financial journey begins with one transaction. Want to add it now?",
                "🎯 First transaction time! Let's see where your money goes. Add one now?",
                "📊 Day 1: No transactions yet. Want to start tracking? Your wallet is ready!"
            ]
            content.title = "Let's Get Started!"
            content.body = messages.randomElement() ?? messages[0]
            
        case .gentle:
            let messages = [
                "👀 It's been \(daysSince) days since your last transaction. Everything okay? Your budget misses you.",
                "📅 Quick check: \(daysSince) days without transactions. Want to add one? Your finances are waiting.",
                "💭 Just thinking... it's been \(daysSince) days. Maybe add a transaction? Just a suggestion.",
                "📊 \(daysSince) days and counting. Your budget is getting lonely. Want to add a transaction?",
                "🎪 The transaction show hasn't had a new episode in \(daysSince) days. Want to add one?"
            ]
            content.title = "Transaction Reminder"
            content.body = messages.randomElement() ?? messages[0]
            
        case .urgent:
            let messages = [
                "🚨 ALERT: It's been \(daysSince) days since your last transaction! Your budget is having an existential crisis.",
                "💀 Your transaction history hasn't been updated in \(daysSince) days. Is your wallet okay?",
                "📢 Breaking news: \(daysSince) days without transactions! Your budget is staging an intervention.",
                "⚠️ \(daysSince) days?! Your financial tracking is on vacation. Want to add a transaction?",
                "🔔 URGENT: \(daysSince) days of radio silence. Your budget needs attention. Add a transaction?"
            ]
            content.title = "Transaction Alert!"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default
        }
        
        content.categoryIdentifier = "TRANSACTION_REMINDER"
        content.userInfo = [
            "type": "transaction_reminder",
            "daysSince": daysSince,
            "urgency": urgency == .urgent ? "urgent" : (urgency == .gentle ? "gentle" : "first")
        ]
        
        // Use a small delay trigger for immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "transaction_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending transaction reminder: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Transaction reminder sent successfully")
            }
        }
    }
    
    func recordTransactionAdded() {
        lastTransactionDate = Date()
        lastTransactionReminderDate = nil // Reset reminder date when transaction is added
        print("[NotificationService] Transaction added - reminder timer reset")
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() {
        print("[NotificationService] Sending test notification...")
        print("[NotificationService] Status - Enabled: \(pushNotificationsEnabled), Authorized: \(isAuthorized)")
        
        guard pushNotificationsEnabled else {
            print("[NotificationService] ❌ Push notifications are disabled in settings")
            return
        }
        
        guard isAuthorized else {
            print("[NotificationService] ❌ Notifications not authorized. Requesting authorization...")
            requestAuthorization()
            // Try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendTestNotification()
            }
            return
        }
        
        let messages = [
            "🧪 Test notification! If you see this, your notifications are working. Congrats!",
            "✅ Notification test successful! Your phone can receive messages. Revolutionary!",
            "🎉 Test passed! Your notifications work. Now go save some money!",
            "🔔 Test notification received! Everything works. Time to get financially responsible!",
            "✨ Notification system: OPERATIONAL. Your wallet is safe (for now)."
        ]
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "TEST"
        content.userInfo = ["type": "test"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending test notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Test notification sent successfully!")
            }
        }
    }
    
    // MARK: - Reset Tracking
    
    func resetBudgetTracking() {
        lastBudgetNotification.removeAll()
    }
    
    func resetGoalTracking() {
        lastGoalMilestone.removeAll()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String {
            switch type {
            case "budget_limit":
                // Navigate to finance tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
            case "goal_milestone":
                // Navigate to finance tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
            case "unusual_spending":
                // Navigate to finance tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
            case "monthly_summary":
                // Navigate to finance tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
            case "transaction_reminder":
                // Navigate to finance tab to add transaction
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
            default:
                break
            }
        }
        
        completionHandler()
    }
}
