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
    @Published var selectedMonth: Date = {
        // Set to first day of current month to avoid timezone issues
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? now
    }()
    
    // Historical data for comparisons
    @Published var previousMonthIncome: Double = 0.0
    @Published var previousMonthExpenses: Double = 0.0
    @Published var monthlyBalanceHistory: [MonthlyBalance] = []
    @Published var monthlyIncomeExpenseHistory: [MonthlyIncomeExpense] = []
    @Published var monthlyNetWorthHistory: [MonthlyNetWorth] = []
    @Published var comparisonPeriod: ComparisonPeriod = .threeMonths
    @Published var comparisonData: [ComparisonPeriodData] = []
    @Published var isHistoricalDataLoading = false
    
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
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let calendar = Calendar.current
                let month = calendar.component(.month, from: selectedMonth)
                let year = calendar.component(.year, from: selectedMonth)
                
                // Calculate previous month date
                let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                let previousMonth = calendar.component(.month, from: previousMonthDate)
                let previousMonthYear = calendar.component(.year, from: previousMonthDate)
                
                // Load all data in parallel with month filtering
                async let metricsTask = networkService.getFinancialMetrics(userId: userId, month: month, year: year)
                async let transactionsTask = networkService.getTransactions(userId: userId, month: month, year: year)
                async let targetsTask = networkService.getTargets(userId: userId)
                async let assetsTask = networkService.getAssets(userId: userId)
                async let xpStatsTask = networkService.getXPStats(userId: userId)
                
                // Load historical data for comparisons
                async let previousMonthMetricsTask = networkService.getFinancialMetrics(userId: userId, month: previousMonth, year: previousMonthYear)
                
                let metrics = try await metricsTask
                let transactionsResponse = try await transactionsTask
                let targetsResponse = try await targetsTask
                let assetsResponse = try await assetsTask
                let xpStatsResponse = try await xpStatsTask
                let previousMonthMetrics = try? await previousMonthMetricsTask
                
                await MainActor.run {
                    self.totalBalance = metrics.metrics.totalBalance
                    self.monthlyIncome = metrics.metrics.monthlyIncome
                    self.monthlyExpenses = metrics.metrics.monthlyExpenses
                    self.transactions = transactionsResponse.transactions
                    self.targets = targetsResponse.targets
                    self.goals = targetsResponse.goals ?? []
                    self.assets = assetsResponse.assets
                    self.xpStats = xpStatsResponse.xpStats
                    
                    // Set historical comparison data
                    self.previousMonthIncome = previousMonthMetrics?.metrics.monthlyIncome ?? 0.0
                    self.previousMonthExpenses = previousMonthMetrics?.metrics.monthlyExpenses ?? 0.0
                    
                    // Load balance and income/expense history
                    self.loadHistoricalData()
                    
                    self.isLoading = false
                    
                    // Check for notifications after data is loaded
                    Task { @MainActor in
                        let notificationService = NotificationService.shared
                        
                        // Check budget limits
                        notificationService.checkBudgetLimits(
                            goals: self.goals,
                            transactions: self.transactions,
                            selectedMonth: self.selectedMonth
                        )
                        
                        // Check goal milestones
                        notificationService.checkGoalMilestones(goals: self.goals)
                        
                        // Check unusual spending patterns
                        notificationService.checkUnusualSpending(
                            transactions: self.transactions,
                            selectedMonth: self.selectedMonth
                        )
                        
                        // Check transaction reminders (only if no auto banking)
                        // TODO: Check if user has auto banking connection
                        notificationService.checkTransactionReminders(
                            transactions: self.transactions,
                            hasAutoBanking: false // Will be updated when auto banking is implemented
                        )
                    }
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
    
    func loadTargets() async {
        do {
            let targetsResponse = try await networkService.getTargets(userId: userId)
            await MainActor.run {
                self.targets = targetsResponse.targets
                self.goals = targetsResponse.goals ?? []
                
                // Check for goal milestone notifications when targets are updated
                Task { @MainActor in
                    NotificationService.shared.checkGoalMilestones(goals: self.goals)
                }
            }
        } catch {
            print("[FinanceViewModel] Error loading targets: \(error.localizedDescription)")
        }
    }
    
    func changeMonth(to date: Date) {
        selectedMonth = date
        loadData()
        // Also reload category analytics for the new period
        // This will be triggered when the category section is expanded
    }
    
    func changeComparisonPeriod(to period: ComparisonPeriod) {
        comparisonPeriod = period
        // Don't reload data immediately - data is already loaded for 12 months
        // Only reload if we don't have enough data
        if comparisonData.count < period.rawValue {
            loadHistoricalData()
        }
    }
    
    // Calculate spending for a specific category in the selected period
    func getCategorySpending(for category: String) -> Double {
        let categorySpending = transactions
            .filter { $0.type == "expense" && $0.category.lowercased() == category.lowercased() }
            .reduce(0.0) { $0 + $1.amount }
        return categorySpending
    }
    
    // Get period-specific spending for a goal (budget limit)
    func getGoalSpending(for goal: Target) -> Double {
        // If goal has a category, calculate spending for that category in selected period
        if let goalCategory = goal.category, !goalCategory.isEmpty {
            return getCategorySpending(for: goalCategory)
        }
        // Otherwise return the goal's current amount (all-time)
        return goal.currentAmount
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
        
        // Refresh to update net worth and other metrics
        refresh()
    }
    
    func addTarget(title: String, description: String?, targetAmount: Double, currentAmount: Double? = nil, currency: String? = nil, targetDate: String? = nil, targetType: String? = nil, category: String? = nil, priority: String? = nil) async throws {
        let userId = self.userId
        
        let newTarget = try await networkService.createTarget(
            userId: userId,
            title: title,
            description: description,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            currency: currency,
            targetDate: targetDate,
            targetType: targetType ?? "savings",
            category: category,
            priority: priority
        )
        
        await MainActor.run {
            // Add to targets if it's a savings goal, or to goals if it's a budget
            if newTarget.targetType.lowercased() == "savings" || (newTarget.category == nil || newTarget.category!.isEmpty) {
                self.targets.append(newTarget)
            } else {
                self.goals.append(newTarget)
            }
        }
        
        // Refresh to update metrics
        refresh()
    }
    
    func addTransaction(type: String, amount: Double, category: String?, description: String, date: Date?) async throws {
        let userId = self.userId
        
        // Format date as ISO string if provided
        let dateString: String?
        if let date = date {
            let formatter = ISO8601DateFormatter()
            dateString = formatter.string(from: date)
        } else {
            dateString = nil
        }
        
        let newTransaction = try await networkService.createTransaction(
            userId: userId,
            type: type,
            amount: amount,
            category: category,
            description: description,
            date: dateString
        )
        
        await MainActor.run {
            self.transactions.append(newTransaction)
            
            // Record transaction added for reminder tracking
            NotificationService.shared.recordTransactionAdded()
            
            // Recalculate metrics
            refresh()
            
            // Check for notifications after adding transaction
            Task { @MainActor in
                let notificationService = NotificationService.shared
                
                // Check budget limits
                notificationService.checkBudgetLimits(
                    goals: self.goals,
                    transactions: self.transactions,
                    selectedMonth: self.selectedMonth
                )
                
                // Check unusual spending patterns
                notificationService.checkUnusualSpending(
                    transactions: self.transactions,
                    selectedMonth: self.selectedMonth
                )
            }
        }
    }
    
    func updateTransaction(transactionId: String, type: String? = nil, amount: Double? = nil, category: String? = nil, description: String? = nil, date: Date? = nil) async throws {
        let userId = self.userId
        
        // Format date as ISO string if provided
        let dateString: String?
        if let date = date {
            let formatter = ISO8601DateFormatter()
            dateString = formatter.string(from: date)
        } else {
            dateString = nil
        }
        
        print("[FinanceViewModel] Updating transaction \(transactionId)")
        
        let response = try await networkService.updateTransaction(
            userId: userId,
            transactionId: transactionId,
            type: type,
            amount: amount,
            category: category,
            description: description,
            date: dateString
        )
        
        print("[FinanceViewModel] Transaction updated successfully")
        
        // Update local array
        await MainActor.run {
            if let index = self.transactions.firstIndex(where: { $0.id == transactionId }) {
                self.transactions[index] = response.transaction
            }
        }
        
        // Refresh to sync
        refresh()
    }
    
    func deleteTransaction(transactionId: String) async throws {
        let userId = self.userId
        
        print("[FinanceViewModel] Deleting transaction \(transactionId)")
        
        let response = try await networkService.deleteTransaction(
            userId: userId,
            transactionId: transactionId
        )
        
        print("[FinanceViewModel] Transaction deleted successfully: \(response.success)")
        
        // Remove from local array
        await MainActor.run {
            self.transactions.removeAll { $0.id == transactionId }
        }
        
        // Refresh to sync
        refresh()
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
    
    // Load historical data for charts (based on comparison period)
    func loadHistoricalData() {
        // Prevent multiple simultaneous loads
        guard !isHistoricalDataLoading else { return }
        
        Task {
            await MainActor.run {
                self.isHistoricalDataLoading = true
            }
            
            let calendar = Calendar.current
            var history: [MonthlyBalance] = []
            var incomeExpenseHistory: [MonthlyIncomeExpense] = []
            var comparisonDataArray: [ComparisonPeriodData] = []
            
            // Get data for the selected comparison period (always load at least 12 months for flexibility)
            // Load data both backwards AND forwards from selectedMonth to ensure we have previous month data
            let monthsToLoad = 12
            
            // Load months backwards from selectedMonth (including selectedMonth itself)
            for i in 0..<monthsToLoad {
                if let monthDate = calendar.date(byAdding: .month, value: -i, to: selectedMonth) {
                    let month = calendar.component(.month, from: monthDate)
                    let year = calendar.component(.year, from: monthDate)
                    
                    do {
                        let metrics = try await networkService.getFinancialMetrics(userId: userId, month: month, year: year)
                        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? monthDate
                        
                        let balance = metrics.metrics.monthlyBalance
                        let income = metrics.metrics.monthlyIncome
                        let expenses = metrics.metrics.monthlyExpenses
                        
                        history.append(MonthlyBalance(
                            id: "\(year)-\(month)",
                            month: monthStart,
                            balance: balance
                        ))
                        
                        incomeExpenseHistory.append(MonthlyIncomeExpense(
                            id: "\(year)-\(month)",
                            month: monthStart,
                            income: income,
                            expenses: expenses
                        ))
                        
                        comparisonDataArray.append(ComparisonPeriodData(
                            id: "\(year)-\(month)",
                            month: monthStart,
                            income: income,
                            expenses: expenses,
                            balance: balance,
                            incomeChange: 0.0, // Will calculate after sorting
                            expensesChange: 0.0,
                            balanceChange: 0.0
                        ))
                    } catch {
                        print("[FinanceViewModel] Error loading historical data for \(year)-\(month): \(error.localizedDescription)")
                    }
                }
            }
            
            // Sort by date (oldest first) and calculate changes
            let sortedData = comparisonDataArray.sorted { $0.month < $1.month }
            var finalComparisonData: [ComparisonPeriodData] = []
            
            for (index, data) in sortedData.enumerated() {
                var incomeChange: Double = 0.0
                var expensesChange: Double = 0.0
                var balanceChange: Double = 0.0
                
                if index > 0 {
                    let prevData = sortedData[index - 1]
                    incomeChange = data.income - prevData.income
                    expensesChange = data.expenses - prevData.expenses
                    balanceChange = data.balance - prevData.balance
                }
                
                finalComparisonData.append(ComparisonPeriodData(
                    id: data.id,
                    month: data.month,
                    income: data.income,
                    expenses: data.expenses,
                    balance: data.balance,
                    incomeChange: incomeChange,
                    expensesChange: expensesChange,
                    balanceChange: balanceChange
                ))
            }
            
            // Calculate net worth history
            // Net Worth = Total Assets (current) + Cumulative Cash Available (up to each month)
            // Capture asset values on MainActor to ensure thread safety
            let (totalAssets, goalsValue, targetsValue) = await MainActor.run {
                let assets = self.assets.reduce(0) { $0 + $1.currentValue }
                let goals = self.goals.reduce(0) { $0 + $1.currentAmount }
                let targets = self.targets.reduce(0) { $0 + $1.currentAmount }
                return (assets, goals, targets)
            }
            let currentTotalAssets = totalAssets + goalsValue + targetsValue
            
            var netWorthHistory: [MonthlyNetWorth] = []
            var cumulativeCash: Double = 0.0
            
            let sortedHistory = history.sorted { $0.month < $1.month }
            for balance in sortedHistory {
                cumulativeCash += balance.balance
                let netWorth = currentTotalAssets + cumulativeCash
                netWorthHistory.append(MonthlyNetWorth(
                    id: balance.id,
                    month: balance.month,
                    netWorth: netWorth,
                    assets: currentTotalAssets,
                    cashAvailable: cumulativeCash
                ))
            }
            
            await MainActor.run {
                // Sort by month to ensure proper chronological order
                // This is critical for health score calculation to find previous month correctly
                var finalIncomeExpenseHistory = incomeExpenseHistory.sorted { $0.month < $1.month }
                
                // CRITICAL: Ensure we have the previous month for the selected month in history
                // This is essential for health score stability calculation to work for ALL months
                let calendar = Calendar.current
                let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: self.selectedMonth) ?? self.selectedMonth
                let previousMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: previousMonthDate)) ?? previousMonthDate
                
                // Check if previous month is already in history
                let hasPreviousMonth = finalIncomeExpenseHistory.contains { data in
                    calendar.isDate(data.month, equalTo: previousMonthStart, toGranularity: .month)
                }
                
                // If not, and we have previousMonthExpenses from loadData(), add it to history
                // This ensures health score calculation works correctly for every month
                if !hasPreviousMonth && self.previousMonthExpenses > 0 {
                    let previousMonth = calendar.component(.month, from: previousMonthDate)
                    let previousYear = calendar.component(.year, from: previousMonthDate)
                    
                    // Add previous month to history for accurate health score calculation
                    finalIncomeExpenseHistory.append(MonthlyIncomeExpense(
                        id: "\(previousYear)-\(previousMonth)",
                        month: previousMonthStart,
                        income: self.previousMonthIncome,
                        expenses: self.previousMonthExpenses
                    ))
                    
                    // Re-sort after adding to maintain chronological order
                    finalIncomeExpenseHistory = finalIncomeExpenseHistory.sorted { $0.month < $1.month }
                }
                
                // Update all published properties in a single batch to prevent multiple view updates
                // This ensures the graph only updates once when data is fully loaded
                self.monthlyBalanceHistory = history.sorted { $0.month < $1.month }
                self.monthlyIncomeExpenseHistory = finalIncomeExpenseHistory
                self.monthlyNetWorthHistory = netWorthHistory
                self.comparisonData = finalComparisonData
                self.isHistoricalDataLoading = false
            }
        }
    }
    
    // Get comparison data for selected period
    func getComparisonData(for period: ComparisonPeriod) -> [ComparisonPeriodData] {
        let monthsToShow = period.rawValue
        let sortedData = comparisonData.sorted { $0.month < $1.month }
        return Array(sortedData.suffix(monthsToShow))
    }
    
    // Get balance history for selected period
    func getBalanceHistory(for period: ComparisonPeriod) -> [MonthlyBalance] {
        let monthsToShow = period.rawValue
        let sortedData = monthlyBalanceHistory.sorted { $0.month < $1.month }
        return Array(sortedData.suffix(monthsToShow))
    }
    
    // Get income/expense history for selected period
    func getIncomeExpenseHistory(for period: ComparisonPeriod) -> [MonthlyIncomeExpense] {
        let monthsToShow = period.rawValue
        let sortedData = monthlyIncomeExpenseHistory.sorted { $0.month < $1.month }
        return Array(sortedData.suffix(monthsToShow))
    }
    
    // Get net worth history for selected period
    func getNetWorthHistory(for period: ComparisonPeriod) -> [MonthlyNetWorth] {
        let monthsToShow = period.rawValue
        let sortedData = monthlyNetWorthHistory.sorted { $0.month < $1.month }
        return Array(sortedData.suffix(monthsToShow))
    }
    
    // Get total assets value (including goals and targets)
    var totalAssets: Double {
        let assetsValue = assets.reduce(0) { $0 + $1.currentValue }
        let goalsValue = goals.reduce(0) { $0 + $1.currentAmount }
        let targetsValue = targets.reduce(0) { $0 + $1.currentAmount }
        return assetsValue + goalsValue + targetsValue
    }
    
    // Calculate cumulative total balance up to selected month
    // This sums all monthly balances from the first month up to and including the selected month
    // The balance will change as the user selects different months
    var cumulativeTotalBalance: Double {
        let calendar = Calendar.current
        let selectedMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
        
        // Get all monthly balances sorted chronologically
        let sortedHistory = monthlyBalanceHistory.sorted { $0.month < $1.month }
        
        // Calculate balance for the selected month
        // Use monthlyIncome - monthlyExpenses since these are loaded for the selectedMonth
        let selectedMonthBalance = monthlyIncome - monthlyExpenses
        
        // If no history available yet, return just the selected month's balance
        if sortedHistory.isEmpty {
            return selectedMonthBalance
        }
        
        // Sum all balances from history that are BEFORE the selected month
        let previousMonthsBalance = sortedHistory
            .filter { balance in
                // Include only months that are strictly before the selected month
                balance.month < selectedMonthStart
            }
            .reduce(0.0) { $0 + $1.balance }
        
        // Check if the selected month is already in history
        let hasSelectedMonthInHistory = sortedHistory.contains { balance in
            calendar.isDate(balance.month, equalTo: selectedMonthStart, toGranularity: .month)
        }
        
        if hasSelectedMonthInHistory {
            // If selected month is in history, sum all balances up to and including it
            return sortedHistory
                .filter { balance in
                    balance.month <= selectedMonthStart
                }
                .reduce(0.0) { $0 + $1.balance }
        } else {
            // If selected month is not in history, use the loaded monthlyIncome/monthlyExpenses
            return previousMonthsBalance + selectedMonthBalance
        }
    }
    
    // Calculate percentage change for month-to-month comparison
    func getMonthToMonthChange(type: ComparisonType) -> (value: Double, percentage: Double) {
        let current: Double
        let previous: Double
        
        switch type {
        case .income:
            current = monthlyIncome
            previous = previousMonthIncome
        case .expenses:
            current = monthlyExpenses
            previous = previousMonthExpenses
        }
        
        guard previous > 0 else {
            return (current - previous, current > 0 ? 100.0 : 0.0)
        }
        
        let change = current - previous
        let percentage = (change / previous) * 100.0
        return (change, percentage)
    }
    
    // MARK: - Health Score Calculation
    
    struct HealthScore {
        let score: Int
        let explanation: String
    }
    
    func calculateHealthScore() -> HealthScore {
        let income = monthlyIncome
        let expenses = monthlyExpenses
        let currentBalance = monthlyIncome - monthlyExpenses // Current month's balance
        
        // STEP 1: Basic check
        if income <= 0 {
            return HealthScore(
                score: 0,
                explanation: "Add income transactions to get your health score."
            )
        }
        
        // STEP 2: Income vs Expense Score (60% weight)
        // Calculate savings rate: (income - expenses) / income
        let savingsRate = (income - expenses) / income
        let incomeExpenseScore: Double
        
        if expenses > income {
            // Expenses exceed income - critical situation
            // Score decreases based on how much expenses exceed income
            let overspendRate = (expenses - income) / income
            if overspendRate >= 0.50 {
                // Spending 50%+ more than income - very bad
                incomeExpenseScore = 0
            } else if overspendRate >= 0.25 {
                // Spending 25-50% more than income
                incomeExpenseScore = 10
            } else {
                // Spending up to 25% more than income
                incomeExpenseScore = 20
            }
        } else if expenses == income {
            // Break even - neutral score
            incomeExpenseScore = 50
        } else {
            // Positive savings - scale from 50 to 100
            // 0% savings = 50 points, 20%+ savings = 100 points
            if savingsRate >= 0.20 {
                incomeExpenseScore = 100
            } else {
                // Linear scaling: 0% -> 50 points, 20% -> 100 points
                incomeExpenseScore = 50 + (savingsRate / 0.20) * 50
            }
        }
        
        // STEP 3: Balance Change Score (40% weight)
        // Compare current month balance to previous month balance
        let calendar = Calendar.current
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        let previousMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: previousMonthDate)) ?? previousMonthDate
        
        // Get previous month balance from history
        let sortedBalanceHistory = monthlyBalanceHistory.sorted { $0.month < $1.month }
        let previousMonthBalance: Double
        
        if let previousMonthData = sortedBalanceHistory.first(where: { data in
            calendar.isDate(data.month, equalTo: previousMonthStart, toGranularity: .month)
        }) {
            previousMonthBalance = previousMonthData.balance
        } else {
            // No previous month data - use neutral score
            previousMonthBalance = currentBalance // Assume no change for first month
        }
        
        let balanceChangeScore: Double
        
        if previousMonthBalance == 0 && currentBalance == 0 {
            // Both months have zero balance - neutral
            balanceChangeScore = 50
        } else if previousMonthBalance == 0 {
            // First month with balance - positive if balance is positive
            balanceChangeScore = currentBalance > 0 ? 80 : 30
        } else {
            // Calculate percentage change in balance
            let balanceChange = currentBalance - previousMonthBalance
            let balanceChangePercent = balanceChange / abs(previousMonthBalance)
            
            if balanceChange > 0 {
                // Balance increased - good
                if balanceChangePercent >= 0.20 {
                    // 20%+ increase - excellent
                    balanceChangeScore = 100
                } else if balanceChangePercent >= 0.10 {
                    // 10-20% increase - very good
                    balanceChangeScore = 85
                } else if balanceChangePercent >= 0.05 {
                    // 5-10% increase - good
                    balanceChangeScore = 70
                } else {
                    // Small increase - decent
                    balanceChangeScore = 60
                }
            } else if balanceChange == 0 {
                // Balance stayed the same - neutral
                balanceChangeScore = 50
            } else {
                // Balance decreased - bad
                let decreasePercent = abs(balanceChangePercent)
                if decreasePercent >= 0.50 {
                    // 50%+ decrease - very bad
                    balanceChangeScore = 0
                } else if decreasePercent >= 0.25 {
                    // 25-50% decrease - bad
                    balanceChangeScore = 20
                } else if decreasePercent >= 0.10 {
                    // 10-25% decrease - poor
                    balanceChangeScore = 35
                } else {
                    // Small decrease - below average
                    balanceChangeScore = 45
                }
            }
        }
        
        // STEP 4: Final Health Score
        // Weighted combination: 60% income/expense, 40% balance change
        let finalScore = (incomeExpenseScore * 0.60) + (balanceChangeScore * 0.40)
        let clampedScore = max(0, min(100, Int(finalScore.rounded())))
        
        // STEP 5: Generate explanation
        let explanation: String
        
        if expenses > income {
            explanation = "Your expenses exceed your income this month. Reducing spending is essential to improve your financial health."
        } else if savingsRate >= 0.20 {
            if balanceChangeScore >= 80 {
                explanation = "Excellent financial health! You're saving well and your balance is growing."
            } else {
                explanation = "Great savings rate! Keep maintaining this level to improve your score further."
            }
        } else if savingsRate >= 0.10 {
            if balanceChangeScore >= 70 {
                explanation = "Good progress! You're saving money and your balance is increasing."
            } else {
                explanation = "You're saving money, but try to increase your savings rate to 20% or more."
            }
        } else if savingsRate > 0 {
            if balanceChangeScore < 50 {
                explanation = "You're saving, but your balance decreased. Focus on increasing your savings rate."
            } else {
                explanation = "You're saving some money. Aim to save at least 20% of your income for better financial health."
            }
        } else {
            // Break even or negative
            if balanceChangeScore < 50 {
                explanation = "Your expenses match or exceed your income, and your balance is decreasing. Reduce spending to improve your score."
            } else {
                explanation = "Your expenses are too close to your income. Aim to save at least 20% to improve your score."
            }
        }
        
        return HealthScore(score: clampedScore, explanation: explanation)
    }
    
}

enum ComparisonType {
    case income
    case expenses
}

