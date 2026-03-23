//
//  FinanceViewModel.swift
//  ANITA
//
//  ViewModel for finance functionality
//

import Foundation
import SwiftUI

/// How Insights (`loadHistoricalData`) loads each month — must stay aligned with combined top cards in `loadData`.
private enum HistoricalMetricsMode {
    case manualOnly
    case bankOnly
    /// Manual + bank metrics summed per month (user on manual mode with linked bank).
    case mergedManualAndBank
}

@MainActor
class FinanceViewModel: ObservableObject {
    @Published var totalBalance: Double = 0.0
    @Published var monthlyIncome: Double = 0.0
    @Published var monthlyExpenses: Double = 0.0
    /// Selected month's available funds (income - expenses - transfers to goal + transfers from goal). Used for Available Funds display.
    @Published var monthlyBalance: Double = 0.0
    @Published var transactions: [TransactionItem] = []
    @Published var targets: [Target] = []
    @Published var goals: [Target] = []
    @Published var assets: [Asset] = []
    @Published var xpStats: XPStats?
    @Published var isLoading = false
    /// True after `loadData()` has successfully completed at least once for the current app session.
    /// Used by the UI to avoid showing placeholder / stale values before the first real payload arrives.
    @Published var hasLoadedOnce = false
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
    @Published var comparisonPeriod: ComparisonPeriod = .oneMonth
    @Published var comparisonData: [ComparisonPeriodData] = []
    @Published var isHistoricalDataLoading = false
    /// True after historical data has been loaded at least once (e.g. when user first opens Insights).
    var hasLoadedHistoricalDataOnce = false
    
    private let networkService = NetworkService.shared
    let userId: String

    /// Backend user id: requires Supabase auth so all financial data is stored server-side and shared across devices.
    private var effectiveUserId: String? {
        guard let authed = UserManager.shared.currentUser, UserManager.shared.isAuthenticated else {
            return nil
        }
        return authed.id
    }

    // Must retain observer tokens or they are deallocated and notifications never fire
    private var transactionAddedObserver: NSObjectProtocol?
    private var xpStatsDidUpdateObserver: NSObjectProtocol?
    
    init(userId: String? = nil) {
        self.userId = userId ?? UserManager.shared.userId
        
        // Listen for transaction added notifications
        transactionAddedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TransactionAdded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        // Listen for XP updates (e.g. after chat message or app open) so Finance tab XP card updates
        xpStatsDidUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("XPStatsDidUpdate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshXPStats()
            }
        }
    }
    
    deinit {
        if let o = transactionAddedObserver { NotificationCenter.default.removeObserver(o) }
        if let o = xpStatsDidUpdateObserver { NotificationCenter.default.removeObserver(o) }
    }
    
    var usesBankDataOnly: Bool { UserManager.shared.usesBankDataOnly }
    
    // MARK: - Bank sync throttling (once per day, background-only)
    private static let lastBankSyncKey = "anita_last_bank_sync_date"
    
    /// Returns true if we should trigger a background bank sync (at most once per calendar day).
    static func shouldPerformDailyBankSync() -> Bool {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastBankSyncKey) as? Date {
            let cal = Calendar.current
            if cal.isDateInToday(last) { return false }
        }
        return true
    }
    
    static func markBankSyncPerformed() {
        UserDefaults.standard.set(Date(), forKey: lastBankSyncKey)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        // After bank link, manual rows are archived server-side; drop stale in-memory manual txs so they cannot re-merge into the list.
        if UserManager.shared.hasEstablishedBankSync && !usesBankDataOnly {
            transactions = []
        }
        
        Task {
            do {
                let calendar = Calendar.current
                guard let userId = self.effectiveUserId else {
                    await MainActor.run {
                        self.errorMessage = "Please log in or sign up to see your finances on all devices."
                        self.isLoading = false
                    }
                    return
                }
                let month = calendar.component(.month, from: selectedMonth)
                let year = calendar.component(.year, from: selectedMonth)
                
                // Calculate previous month date
                let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                let previousMonth = calendar.component(.month, from: previousMonthDate)
                let previousMonthYear = calendar.component(.year, from: previousMonthDate)
                
                if usesBankDataOnly {
                    // Bank mode: always use effectiveUserId so logged-in users share data across devices,
                    // but anonymous users still see their own bank data.
                    // IMPORTANT: Do NOT sync from Stripe here – we want fast loads using
                    // the cached metrics/transactions that are already in our database.
                    // However, right after the user connects a bank, the backend import/metrics
                    // may still be updating. In that case, force a refresh once and keep
                    // Finance in the loading state until the backend is ready.
                    if UserManager.shared.isJustConnectedBank {
                        do {
                            try await networkService.refreshBankTransactions(userId: userId)
                            UserManager.shared.clearJustConnectedBank()
                        } catch {
                            // Keep the flag until the next successful load attempt.
                            print("[FinanceViewModel] refreshBankTransactions failed: \(error.localizedDescription)")
                        }
                    }

                    let fromStr = String(format: "%04d-%02d-01", year, month)
                    let comp = DateComponents(year: year, month: month, day: 1)
                    guard let firstDay = calendar.date(from: comp),
                          let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) else {
                        await MainActor.run { self.isLoading = false }
                        return
                    }
                    let lastDayNum = calendar.component(.day, from: lastDay)
                    let toStr = String(format: "%04d-%02d-%02d", year, month, lastDayNum)
                    let bankResponse = try await networkService.getBankTransactions(userId: userId, from: fromStr, to: toStr, limit: 1000)
                    let mapped = bankResponse.transactions.map { $0.toTransactionItem() }
                    async let metricsTask = networkService.getFinancialMetrics(userId: userId, month: month, year: year, useBankData: true)
                    async let targetsTask = networkService.getTargets(userId: userId)
                    async let assetsTask = networkService.getAssets(userId: userId)
                    async let xpStatsTask = networkService.getXPStats(userId: userId)
                    async let previousMonthMetricsTask = networkService.getFinancialMetrics(userId: userId, month: previousMonth, year: previousMonthYear, useBankData: true)
                    let metrics = try await metricsTask
                    let targetsResponse = try await targetsTask
                    let assetsResponse = try await assetsTask
                    let xpStatsResponse = try await xpStatsTask
                    let previousMonthMetrics = try? await previousMonthMetricsTask
                    let bankActivityFromServer = !mapped.isEmpty
                        || metrics.metrics.monthlyIncome > 0
                        || metrics.metrics.monthlyExpenses > 0
                    // Load 12 months of balances so Funds Total (cumulative) is correct on first paint
                    let balanceHistory: [MonthlyBalance] = await Self.fetchBalanceHistory(networkService: networkService, userId: userId, selectedMonth: selectedMonth, calendar: calendar, useBankData: true)
                    await MainActor.run {
                        self.transactions = mapped
                        self.totalBalance = metrics.metrics.totalBalance
                        self.monthlyIncome = metrics.metrics.monthlyIncome
                        self.monthlyExpenses = metrics.metrics.monthlyExpenses
                        self.monthlyBalance = metrics.metrics.monthlyBalance
                        self.targets = targetsResponse.targets
                        self.goals = targetsResponse.goals ?? []
                        self.assets = assetsResponse.assets
                        self.xpStats = XPStats.from(totalXP: xpStatsResponse.xpStats.total_xp)
                        self.previousMonthIncome = previousMonthMetrics?.metrics.monthlyIncome ?? 0.0
                        self.previousMonthExpenses = previousMonthMetrics?.metrics.monthlyExpenses ?? 0.0
                        // Always set balance history (even partial) so Funds Total can use cumulative when we have 2+ months
                        if !balanceHistory.isEmpty {
                            self.monthlyBalanceHistory = balanceHistory.sorted { $0.month < $1.month }
                        }
                        if self.monthlyIncome == 0 && self.monthlyExpenses == 0 && !self.transactions.isEmpty {
                            let (income, expenses, balance) = Self.metricsFromTransactions(self.transactions)
                            self.monthlyIncome = income
                            self.monthlyExpenses = expenses
                            self.monthlyBalance = balance
                            if self.totalBalance == 0 { self.totalBalance = balance }
                        }
                        if self.monthlyBalance == 0 && (self.monthlyIncome != 0 || self.monthlyExpenses != 0) {
                            self.monthlyBalance = self.monthlyIncome - self.monthlyExpenses
                        }
                        if !self.hasLoadedHistoricalDataOnce { self.loadHistoricalData() }
                        if bankActivityFromServer { UserManager.shared.markBankSyncEstablished() }
                        self.hasLoadedOnce = true
                        self.isLoading = false
                    }
                } else {
                // Manual mode: also fetch bank metrics so we can show bank data when user has connected bank
                async let metricsTask = networkService.getFinancialMetrics(userId: userId, month: month, year: year)
                async let transactionsTask = networkService.getTransactions(userId: userId, month: month, year: year)
                async let bankMetricsTask = networkService.getFinancialMetrics(userId: userId, month: month, year: year, useBankData: true)
                async let targetsTask = networkService.getTargets(userId: userId)
                async let assetsTask = networkService.getAssets(userId: userId)
                async let xpStatsTask = networkService.getXPStats(userId: userId)
                async let previousMonthMetricsTask = networkService.getFinancialMetrics(userId: userId, month: previousMonth, year: previousMonthYear)
                async let previousMonthBankMetricsTask = networkService.getFinancialMetrics(userId: userId, month: previousMonth, year: previousMonthYear, useBankData: true)
                
                let metrics = try await metricsTask
                let transactionsResponse = try await transactionsTask
                let bankMetrics = try? await bankMetricsTask
                let targetsResponse = try await targetsTask
                let assetsResponse = try await assetsTask
                let xpStatsResponse = try await xpStatsTask
                let previousMonthMetrics = try? await previousMonthMetricsTask
                let previousMonthBankMetrics = try? await previousMonthBankMetricsTask
                
                let manualHasData = metrics.metrics.monthlyIncome > 0 || metrics.metrics.monthlyExpenses > 0
                let bankHasData = (bankMetrics?.metrics.monthlyIncome ?? 0) > 0 || (bankMetrics?.metrics.monthlyExpenses ?? 0) > 0
                let useBankForDisplay = !manualHasData && bankHasData
                // We no longer trigger a Stripe/bank sync in the hot path.
                // If both manual and bank metrics are empty, we keep showing zeros/transactions
                // from our DB and let a separate daily background sync refresh bank data.
                var bankTransactionsForMonth: [TransactionItem]?
                let finalBankMetrics = bankMetrics
                let finalPreviousBankMetrics = previousMonthBankMetrics
                var bankBalanceHistoryForTotal: [MonthlyBalance] = []
                var manualBalanceHistoryForTotal: [MonthlyBalance] = []
                if useBankForDisplay {
                    // Use whatever bank metrics are already cached in our DB; do not force a sync here.
                    bankBalanceHistoryForTotal = await Self.fetchBalanceHistory(networkService: networkService, userId: userId, selectedMonth: selectedMonth, calendar: calendar, useBankData: true)
                } else {
                    // Manual mode: load balance history so Funds Total = (month1 + month2 + … + selected) from first paint
                    manualBalanceHistoryForTotal = await Self.fetchBalanceHistory(networkService: networkService, userId: userId, selectedMonth: selectedMonth, calendar: calendar, useBankData: false)
                }
                // Whenever we have ANY bank data, load bank transactions for the selected month so the list can
                // include both manual and bank activity.
                if bankHasData {
                    let fromStr = String(format: "%04d-%02d-01", year, month)
                    let comp = DateComponents(year: year, month: month, day: 1)
                    if let firstDay = calendar.date(from: comp),
                       let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) {
                        let lastDayNum = calendar.component(.day, from: lastDay)
                        let toStr = String(format: "%04d-%02d-%02d", year, month, lastDayNum)
                        bankTransactionsForMonth = try? await networkService.getBankTransactions(userId: userId, from: fromStr, to: toStr, limit: 1000).transactions.map { $0.toTransactionItem() }
                    }
                }
                
                let bankActivityFromServer = bankHasData || !(bankTransactionsForMonth?.isEmpty ?? true)
                
                await MainActor.run {
                    if useBankForDisplay, let bank = finalBankMetrics?.metrics {
                        self.totalBalance = bank.totalBalance
                        self.monthlyIncome = bank.monthlyIncome
                        self.monthlyExpenses = bank.monthlyExpenses
                        self.monthlyBalance = bank.monthlyBalance
                        self.previousMonthIncome = finalPreviousBankMetrics?.metrics.monthlyIncome ?? 0.0
                        self.previousMonthExpenses = finalPreviousBankMetrics?.metrics.monthlyExpenses ?? 0.0
                        if !bankBalanceHistoryForTotal.isEmpty {
                            self.monthlyBalanceHistory = bankBalanceHistoryForTotal
                        }
                        // Always replace list in bank-display mode (avoid keeping pre-bank manual txs if bank fetch is empty or slow).
                        self.transactions = bankTransactionsForMonth ?? []
                        self.targets = targetsResponse.targets
                        self.goals = targetsResponse.goals ?? []
                        self.assets = assetsResponse.assets
                        self.xpStats = XPStats.from(totalXP: xpStatsResponse.xpStats.total_xp)
                        if self.monthlyIncome == 0 && self.monthlyExpenses == 0 && !self.transactions.isEmpty {
                            let (income, expenses, balance) = Self.metricsFromTransactions(self.transactions)
                            self.monthlyIncome = income
                            self.monthlyExpenses = expenses
                            self.monthlyBalance = balance
                            if self.totalBalance == 0 { self.totalBalance = balance }
                        }
                        if self.monthlyBalance == 0 && (self.monthlyIncome != 0 || self.monthlyExpenses != 0) {
                            self.monthlyBalance = self.monthlyIncome - self.monthlyExpenses
                        }
                        if !self.hasLoadedHistoricalDataOnce { self.loadHistoricalData(useBankData: true) }
                    } else {
                        // Combine manual + bank metrics so top cards reflect ALL activity.
                        let manualMetrics = metrics.metrics
                        let bank = bankMetrics?.metrics
                        self.totalBalance = manualMetrics.totalBalance + (bank?.totalBalance ?? 0.0)
                        self.monthlyIncome = manualMetrics.monthlyIncome + (bank?.monthlyIncome ?? 0.0)
                        self.monthlyExpenses = manualMetrics.monthlyExpenses + (bank?.monthlyExpenses ?? 0.0)
                        self.monthlyBalance = manualMetrics.monthlyBalance + (bank?.monthlyBalance ?? 0.0)
                        self.previousMonthIncome = previousMonthMetrics?.metrics.monthlyIncome ?? 0.0
                        self.previousMonthExpenses = previousMonthMetrics?.metrics.monthlyExpenses ?? 0.0
                        if !manualBalanceHistoryForTotal.isEmpty {
                            self.monthlyBalanceHistory = manualBalanceHistoryForTotal.sorted { $0.month < $1.month }
                        }
                        let fromAPI = transactionsResponse.transactions
                        let fromAPIInSelectedMonth = fromAPI.filter { Self.isTransactionInMonth($0, month: month, year: year) }
                        let apiIds = Set(fromAPIInSelectedMonth.map(\.id))
                        // Without this, cached manual rows stay visible forever once bank sync hides them from the API (`onlyLocal` re-attach).
                        let onlyLocalInSelectedMonth: [TransactionItem]
                        if UserManager.shared.hasEstablishedBankSync {
                            onlyLocalInSelectedMonth = []
                        } else {
                            let onlyLocal = self.transactions.filter { !apiIds.contains($0.id) }
                            onlyLocalInSelectedMonth = onlyLocal.filter { Self.isTransactionInMonth($0, month: month, year: year) }
                        }
                        var merged = onlyLocalInSelectedMonth + fromAPIInSelectedMonth
                        if let bankList = bankTransactionsForMonth {
                            let existingIds = Set(merged.map(\.id))
                            merged.append(contentsOf: bankList.filter { !existingIds.contains($0.id) })
                        }
                        self.transactions = merged
                        self.targets = targetsResponse.targets
                        self.goals = targetsResponse.goals ?? []
                        self.assets = assetsResponse.assets
                        self.xpStats = XPStats.from(totalXP: xpStatsResponse.xpStats.total_xp)
                        if self.monthlyIncome == 0 && self.monthlyExpenses == 0 && !self.transactions.isEmpty {
                            let (income, expenses, balance) = Self.metricsFromTransactions(self.transactions)
                            self.monthlyIncome = income
                            self.monthlyExpenses = expenses
                            self.monthlyBalance = balance
                            if self.totalBalance == 0 { self.totalBalance = balance }
                        }
                        if self.monthlyBalance == 0 && (self.monthlyIncome != 0 || self.monthlyExpenses != 0) {
                            self.monthlyBalance = self.monthlyIncome - self.monthlyExpenses
                        }
                        if !self.hasLoadedHistoricalDataOnce { self.loadHistoricalData() }
                    }
                    if bankActivityFromServer { UserManager.shared.markBankSyncEstablished() }
                    self.hasLoadedOnce = true
                    self.isLoading = false
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
    
    /// Call from pull-to-refresh. We no longer force a bank sync here; instead we rely on
    /// a separate daily background sync so that refresh stays fast and uses cached data.
    func refreshAsync() async {
        loadData()
    }

    /// Fetch 12 months of balance history so Funds Total (cumulative) can be computed on first load.
    private static func fetchBalanceHistory(networkService: NetworkService, userId: String, selectedMonth: Date, calendar: Calendar, useBankData: Bool) async -> [MonthlyBalance] {
        var monthInfos: [(Int, Int)] = []
        for i in 0..<12 {
            if let monthDate = calendar.date(byAdding: .month, value: -i, to: selectedMonth) {
                monthInfos.append((calendar.component(.month, from: monthDate), calendar.component(.year, from: monthDate)))
            }
        }
        let results: [MonthlyBalance?] = await withTaskGroup(of: MonthlyBalance?.self) { group in
            for (m, y) in monthInfos {
                group.addTask {
                    guard let monthStart = calendar.date(from: DateComponents(year: y, month: m, day: 1)) else { return nil }
                    do {
                        let metrics = try await networkService.getFinancialMetrics(userId: userId, month: m, year: y, useBankData: useBankData)
                        return MonthlyBalance(id: "\(y)-\(m)", month: monthStart, balance: metrics.metrics.monthlyBalance)
                    } catch {
                        return nil
                    }
                }
            }
            var arr: [MonthlyBalance?] = []
            for await r in group { arr.append(r) }
            return arr
        }
        return results.compactMap { $0 }.sorted { $0.month < $1.month }
    }
    
    /// Compute income, expenses, and balance from a list of transactions (so top card matches the list when API returns zeros).
    private static func metricsFromTransactions(_ transactions: [TransactionItem]) -> (income: Double, expenses: Double, balance: Double) {
        let income = transactions.filter { $0.type.lowercased() == "income" }.reduce(0.0) { $0 + $1.amount }
        let expenses = transactions.filter { $0.type.lowercased() == "expense" }.reduce(0.0) { $0 + $1.amount }
        return (income, expenses, income - expenses)
    }
    
    /// True if the transaction's date falls in the given calendar month/year (used to show only selected month).
    private static func isTransactionInMonth(_ transaction: TransactionItem, month: Int, year: Int) -> Bool {
        guard let d = parseTransactionDate(transaction.date) else { return false }
        let cal = Calendar.current
        return cal.component(.month, from: d) == month && cal.component(.year, from: d) == year
    }
    
    /// Parse transaction date string (ISO8601 with or without time, or date-only).
    private static func parseTransactionDate(_ dateString: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateString) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateString) { return d }
        iso.formatOptions = [.withFullDate]
        if let d = iso.date(from: dateString) { return d }
        return nil
    }

    /// Transactions for the selected month only (income, expense, and transfers). Use this for display so we never show another month.
    var transactionsForSelectedMonth: [TransactionItem] {
        let cal = Calendar.current
        let month = cal.component(.month, from: selectedMonth)
        let year = cal.component(.year, from: selectedMonth)
        return transactions.filter { Self.isTransactionInMonth($0, month: month, year: year) }
    }

    /// Add a new transaction to the list immediately (e.g. after creating a transfer). List is newest-first.
    func prependTransaction(_ transaction: TransactionItem) {
        if !transactions.contains(where: { $0.id == transaction.id }) {
            transactions.insert(transaction, at: 0)
        }
    }

    /// Update a goal's saved amount locally so progress shows immediately and matches the persisted value after reload.
    func updateGoalProgress(targetId: String, newCurrentAmount: Double) {
        if let index = targets.firstIndex(where: { $0.id == targetId }) {
            let t = targets[index]
            let updated = Target(
                id: t.id,
                accountId: t.accountId,
                title: t.title,
                description: t.description,
                targetAmount: t.targetAmount,
                currentAmount: newCurrentAmount,
                currency: t.currency,
                targetDate: t.targetDate,
                status: t.status,
                targetType: t.targetType,
                category: t.category,
                priority: t.priority,
                autoUpdate: t.autoUpdate,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt
            )
            targets[index] = updated
        }
        if let index = goals.firstIndex(where: { $0.id == targetId }) {
            let g = goals[index]
            let updated = Target(
                id: g.id,
                accountId: g.accountId,
                title: g.title,
                description: g.description,
                targetAmount: g.targetAmount,
                currentAmount: newCurrentAmount,
                currency: g.currency,
                targetDate: g.targetDate,
                status: g.status,
                targetType: g.targetType,
                category: g.category,
                priority: g.priority,
                autoUpdate: g.autoUpdate,
                createdAt: g.createdAt,
                updatedAt: g.updatedAt
            )
            goals[index] = updated
        }
    }

    // MARK: - Add/Take goal (transfer) — Available Funds
    // Flow: 1) Update target via API 2) Create transfer transaction 3) Update local goal progress, prepend transaction, adjust monthlyBalance. We do NOT refresh after add/take so the UI stays correct; a later user-driven load (change month, pull, reopen) syncs from API.
    // Previously: a delayed refresh ran after add/take and clearPendingTransferAdjustment() was called before refresh(), so loadData() never applied the pending correction — Available Funds could show the wrong value. Removed delayed refresh and pending logic; local updates are the source of truth until next load.

    /// Update Available Funds when user adds money to a goal (transfer to goal).
    func subtractFromAvailableFunds(_ amount: Double) {
        monthlyBalance -= amount
    }

    /// Update Available Funds when user takes money from a goal (transfer from goal).
    func addToAvailableFunds(_ amount: Double) {
        monthlyBalance += amount
    }

    /// Refreshes only XP stats (e.g. after earning XP in chat). Keeps Finance tab XP card in sync.
    func refreshXPStats() {
        let currentUserId = UserManager.shared.userId
        guard !currentUserId.isEmpty else { return }
        Task { @MainActor in
            do {
                let response = try await networkService.getXPStats(userId: currentUserId)
                self.xpStats = XPStats.from(totalXP: response.xpStats.total_xp)
            } catch {
                print("[FinanceViewModel] refreshXPStats failed: \(error.localizedDescription)")
            }
        }
    }

    func loadTargets() async {
        do {
            let targetsResponse = try await networkService.getTargets(userId: userId)
            await MainActor.run {
                self.targets = targetsResponse.targets
                self.goals = targetsResponse.goals ?? []
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
        // Data is already loaded once when Insights was first opened; slider only filters that data.
    }
    
    /// First of the currently selected month in UTC (ISO string). Use this for new transfers so they appear in the correct month and update Available Funds.
    var selectedMonthFirstDayISO: String {
        let local = Calendar.current
        let comps = local.dateComponents([.year, .month], from: selectedMonth)
        let year = comps.year ?? 2025
        let month = comps.month ?? 1
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let first = utc.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: first)
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to add assets.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to add goals.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to add transactions.")
        }
        
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
            refresh()
        }
        
        // Backend awards 10 XP and stores in DB; refresh XP so the level card updates
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s so DB commit is visible
        await XPStore.shared.refresh()
        try? await Task.sleep(nanoseconds: 350_000_000) // second fetch in case of replication
        await XPStore.shared.refresh()
        await MainActor.run {
            self.xpStats = XPStore.shared.xpStats
        }
        NotificationCenter.default.post(name: NSNotification.Name("XPStatsDidUpdate"), object: nil)
    }
    
    func updateTransaction(transactionId: String, type: String? = nil, amount: Double? = nil, category: String? = nil, description: String? = nil, date: Date? = nil) async throws {
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to update transactions.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to delete transactions.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to update assets.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to delete assets.")
        }
        
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
        guard let userId = effectiveUserId else {
            throw NetworkError.apiError("Please log in to delete goals.")
        }
        
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
    
    // Load historical data for charts (based on comparison period).
    /// - Parameter useBankData: `nil` = infer from account (bank-only vs manual vs manual+bank merged when `hasEstablishedBankSync`).
    func loadHistoricalData(useBankData: Bool? = nil) {
        guard !isHistoricalDataLoading else { return }
        
        let mode: HistoricalMetricsMode
        if let explicit = useBankData {
            mode = explicit ? .bankOnly : .manualOnly
        } else if usesBankDataOnly {
            mode = .bankOnly
        } else if UserManager.shared.hasEstablishedBankSync {
            mode = .mergedManualAndBank
        } else {
            mode = .manualOnly
        }
        
        Task {
            await MainActor.run {
                self.isHistoricalDataLoading = true
            }
            
            let calendar = Calendar.current
            let monthsToLoad = 12
            let selectedMonth = await MainActor.run { self.selectedMonth }
            let uid = await MainActor.run { self.effectiveUserId ?? self.userId }
            guard !uid.isEmpty else {
                await MainActor.run {
                    self.isHistoricalDataLoading = false
                }
                return
            }
            
            // Build list of (monthDate, month, year) for all months to load
            var monthInfos: [(Date, Int, Int)] = []
            for i in 0..<monthsToLoad {
                if let monthDate = calendar.date(byAdding: .month, value: -i, to: selectedMonth) {
                    let month = calendar.component(.month, from: monthDate)
                    let year = calendar.component(.year, from: monthDate)
                    monthInfos.append((monthDate, month, year))
                }
            }
            
            // Fetch all 12 months in parallel (instead of sequentially) for much faster load
            struct MonthMetricsResult {
                let id: String
                let monthStart: Date
                let income: Double
                let expenses: Double
                let balance: Double
            }
            let results: [MonthMetricsResult] = await withTaskGroup(of: MonthMetricsResult?.self) { group in
                for (monthDate, month, year) in monthInfos {
                    let modeCopy = mode
                    group.addTask {
                        let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? monthDate
                        switch modeCopy {
                        case .manualOnly:
                            do {
                                let metrics = try await self.networkService.getFinancialMetrics(userId: uid, month: month, year: year, useBankData: false)
                                return MonthMetricsResult(
                                    id: "\(year)-\(month)",
                                    monthStart: monthStart,
                                    income: metrics.metrics.monthlyIncome,
                                    expenses: metrics.metrics.monthlyExpenses,
                                    balance: metrics.metrics.monthlyBalance
                                )
                            } catch {
                                print("[FinanceViewModel] Error loading historical data for \(year)-\(month): \(error.localizedDescription)")
                                return nil
                            }
                        case .bankOnly:
                            do {
                                let metrics = try await self.networkService.getFinancialMetrics(userId: uid, month: month, year: year, useBankData: true)
                                return MonthMetricsResult(
                                    id: "\(year)-\(month)",
                                    monthStart: monthStart,
                                    income: metrics.metrics.monthlyIncome,
                                    expenses: metrics.metrics.monthlyExpenses,
                                    balance: metrics.metrics.monthlyBalance
                                )
                            } catch {
                                print("[FinanceViewModel] Error loading historical data (bank) for \(year)-\(month): \(error.localizedDescription)")
                                return nil
                            }
                        case .mergedManualAndBank:
                            async let manualTask = try? await self.networkService.getFinancialMetrics(userId: uid, month: month, year: year, useBankData: false)
                            async let bankTask = try? await self.networkService.getFinancialMetrics(userId: uid, month: month, year: year, useBankData: true)
                            let m = await manualTask
                            let b = await bankTask
                            if m == nil && b == nil { return nil }
                            let income = (m?.metrics.monthlyIncome ?? 0) + (b?.metrics.monthlyIncome ?? 0)
                            let expenses = (m?.metrics.monthlyExpenses ?? 0) + (b?.metrics.monthlyExpenses ?? 0)
                            let balance = (m?.metrics.monthlyBalance ?? 0) + (b?.metrics.monthlyBalance ?? 0)
                            return MonthMetricsResult(
                                id: "\(year)-\(month)",
                                monthStart: monthStart,
                                income: income,
                                expenses: expenses,
                                balance: balance
                            )
                        }
                    }
                }
                var arr: [MonthMetricsResult] = []
                for await r in group {
                    if let r = r { arr.append(r) }
                }
                return arr
            }
            
            // Build history arrays from parallel results (order may vary, so we sort below)
            let history: [MonthlyBalance] = results.map { MonthlyBalance(id: $0.id, month: $0.monthStart, balance: $0.balance) }
            let incomeExpenseHistory: [MonthlyIncomeExpense] = results.map { MonthlyIncomeExpense(id: $0.id, month: $0.monthStart, income: $0.income, expenses: $0.expenses) }
            let comparisonDataArray: [ComparisonPeriodData] = results.map { ComparisonPeriodData(id: $0.id, month: $0.monthStart, income: $0.income, expenses: $0.expenses, balance: $0.balance, incomeChange: 0.0, expensesChange: 0.0, balanceChange: 0.0) }
            
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
                let maxMonths = max(1, finalComparisonData.count)
                if self.comparisonPeriod.rawValue > maxMonths {
                    self.comparisonPeriod = ComparisonPeriod(rawValue: maxMonths) ?? .oneMonth
                }
                self.hasLoadedHistoricalDataOnce = true
                self.isHistoricalDataLoading = false
            }
        }
    }
    
    /// Clears the Insights cache and reloads (e.g. after bank link, when merged manual+bank metrics apply).
    func invalidateAndReloadHistoricalData() {
        hasLoadedHistoricalDataOnce = false
        loadHistoricalData()
    }
    
    /// Maximum number of months available for comparison (based on loaded data). At least 1.
    var maxAvailableComparisonMonths: Int {
        max(1, comparisonData.count)
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
    
    /// Funds Total to display.
    /// Definition (from earlier logic and history fetching):
    ///   Funds Total = sum of each month's ending Available Funds (monthlyBalance)
    ///   from the first month we have data up to and including the selected month.
    /// This uses `cumulativeTotalBalance`, which is built from `monthlyBalanceHistory`
    /// populated by `loadHistoricalData` / `fetchBalanceHistory`.
    var displayTotalBalance: Double {
        return cumulativeTotalBalance
    }
    
    /// Monthly income to display in the top card.
    /// Prefers the sum of the visible transaction list for the selected month so it always matches what the user sees.
    var displayMonthlyIncome: Double {
        let txIncome = transactionsForSelectedMonth
            .filter { $0.type.lowercased() == "income" }
            .reduce(0.0) { $0 + $1.amount }
        if txIncome > 0 {
            return txIncome
        }
        return monthlyIncome
    }
    
    /// Monthly expenses to display in the top card.
    /// Prefers the sum of the visible transaction list for the selected month so it always matches what the user sees.
    var displayMonthlyExpenses: Double {
        let txExpenses = transactionsForSelectedMonth
            .filter { $0.type.lowercased() == "expense" }
            .reduce(0.0) { $0 + $1.amount }
        if txExpenses > 0 {
            return txExpenses
        }
        return monthlyExpenses
    }
    
    /// Available Funds for display: this month's step only (income − expenses − transfers to goal + transfers from goal).
    /// Prefers computing from the visible transaction list so it exactly matches the user's transactions.
    var displayAvailableFunds: Double {
        if !transactionsForSelectedMonth.isEmpty {
            let income = transactionsForSelectedMonth
                .filter { $0.type.lowercased() == "income" }
                .reduce(0.0) { $0 + $1.amount }
            let expenses = transactionsForSelectedMonth
                .filter { $0.type.lowercased() == "expense" }
                .reduce(0.0) { $0 + $1.amount }
            let transfersToGoal = transactionsForSelectedMonth
                .filter { $0.type.lowercased() == "transfer" && $0.category.lowercased().contains("to goal") }
                .reduce(0.0) { $0 + $1.amount }
            let transfersFromGoal = transactionsForSelectedMonth
                .filter { $0.type.lowercased() == "transfer" && $0.category.lowercased().contains("from goal") }
                .reduce(0.0) { $0 + $1.amount }
            return income - expenses - transfersToGoal + transfersFromGoal
        }
        let derived = monthlyIncome - monthlyExpenses
        if monthlyBalance == 0 && derived != 0 {
            return derived
        }
        return monthlyBalance
    }
    
    // Funds Total = sum of each month's ending balance from first month through selected month only (no future months).
    // If we don't have multi-month history, use all-time totalBalance so "Funds Total" includes previous months (not just current).
    var cumulativeTotalBalance: Double {
        let calendar = Calendar.current
        let selectedMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
        let sortedHistory = monthlyBalanceHistory.sorted { $0.month < $1.month }
        let currentMonthBalance = monthlyBalance
        
        // Ensure selected month is in the list (so we always have a value)
        let hasSelectedInHistory = sortedHistory.contains { calendar.isDate($0.month, equalTo: selectedMonthStart, toGranularity: .month) }
        let effectiveHistory: [MonthlyBalance]
        if hasSelectedInHistory {
            effectiveHistory = sortedHistory
        } else {
            let y = calendar.component(.year, from: selectedMonthStart)
            let m = calendar.component(.month, from: selectedMonthStart)
            let entry = MonthlyBalance(id: "\(y)-\(m)", month: selectedMonthStart, balance: currentMonthBalance)
            effectiveHistory = (sortedHistory + [entry]).sorted { $0.month < $1.month }
        }
        
        // When we have no history or only one month, use all-time totalBalance so Funds Total includes previous months
        if effectiveHistory.isEmpty {
            return totalBalance != 0 ? totalBalance : currentMonthBalance
        }
        if effectiveHistory.count < 2 {
            return totalBalance != 0 ? totalBalance : currentMonthBalance
        }
        
        // Sum only months up to and including selected (never future months)
        let sumUpToSelected = effectiveHistory
            .filter { $0.month <= selectedMonthStart }
            .reduce(0.0) { $0 + $1.balance }
        return sumUpToSelected
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
    
    // MARK: - Health Score Calculation (Income vs Expenses only)
    
    /// Health score is based only on this month's income and expenses.
    /// Simple rule: higher savings rate = higher score. No balance history or available funds.
    struct HealthScore {
        let score: Int
        let explanation: String
    }
    
    func calculateHealthScore() -> HealthScore {
        let income = monthlyIncome
        let expenses = monthlyExpenses
        
        guard income > 0 else {
            return HealthScore(
                score: 0,
                explanation: "Add income transactions to get your health score."
            )
        }
        
        // Savings rate: (income - expenses) / income. Negative when spending more than income.
        let savingsRate = (income - expenses) / income
        
        let score: Int
        let explanation: String
        
        if expenses > income {
            // Spending more than income
            let overspendRate = (expenses - income) / income
            if overspendRate >= 0.50 {
                score = 0
                explanation = "You're spending 50%+ more than you earn. Reduce expenses or add income to improve your score."
            } else if overspendRate >= 0.25 {
                score = 15
                explanation = "Expenses are 25–50% above income. Try to cut spending or increase income."
            } else {
                score = 30
                explanation = "Expenses exceed income this month. Reduce spending to get into the green."
            }
        } else if expenses == income {
            score = 50
            explanation = "Income and expenses are even. Saving even a small amount will raise your score."
        } else {
            // Saving money: 0% savings → 50, 20%+ savings → 100
            if savingsRate >= 0.20 {
                score = 100
                explanation = "You're saving 20% or more of your income. Great financial health."
            } else if savingsRate >= 0.10 {
                score = 75
                explanation = "You're saving 10–20%. Aim for 20%+ to reach the top score."
            } else {
                score = Int(50 + (savingsRate / 0.20) * 50)
                explanation = "You're saving a bit. Saving 20% of income gives the best score."
            }
        }
        
        let clampedScore = max(0, min(100, score))
        return HealthScore(score: clampedScore, explanation: explanation)
    }
    
}

enum ComparisonType {
    case income
    case expenses
}

