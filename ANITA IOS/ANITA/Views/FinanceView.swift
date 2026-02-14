//
//  FinanceView.swift
//  ANITA
//
//  Finance page matching webapp design
//

import SwiftUI

// Custom iOS-style transitions - contained animations
extension AnyTransition {
    static var expandSection: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.96))
                .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(0.05)),
            removal: .opacity
                .combined(with: .scale(scale: 0.96))
                .animation(.spring(response: 0.3, dampingFraction: 0.85))
        )
    }
    
    static var slideInFade: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.98))
                .animation(.spring(response: 0.35, dampingFraction: 0.8)),
            removal: .opacity
                .combined(with: .scale(scale: 0.98))
                .animation(.spring(response: 0.3, dampingFraction: 0.85))
        )
    }
}

// Extension to dismiss keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func dismissKeyboardOnSwipe() -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    // Dismiss on downward swipe
                    if value.translation.height > 50 {
                        hideKeyboard()
                    }
                }
        )
    }
    
    func dismissKeyboardOnTap() -> some View {
        self.background(KeyboardDismissingBackground())
    }
}

// Custom tap recognizer so we can detect our gesture (UIGestureRecognizer has no .tag in Swift)
private final class KeyboardDismissTapRecognizer: UITapGestureRecognizer {}

// UIViewRepresentable to handle tap gesture for keyboard dismissal
struct KeyboardDismissingBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        // Add tap gesture to the key window after view appears (async so window is ready on first screen)
        DispatchQueue.main.async {
            guard let window = Self.keyWindow else { return }
            // Avoid duplicate recognizers when modifier is used in multiple places (e.g. root + sheet)
            let recognizers: [UIGestureRecognizer] = window.gestureRecognizers ?? []
            let alreadyHasOurs = recognizers.contains(where: { $0 is KeyboardDismissTapRecognizer })
            if alreadyHasOurs { return }
            
            let tapGesture = KeyboardDismissTapRecognizer(target: context.coordinator, action: #selector(Coordinator.dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = context.coordinator
            window.addGestureRecognizer(tapGesture)
            context.coordinator.gestureRecognizer = tapGesture
            context.coordinator.ownedWindow = window
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let gesture = coordinator.gestureRecognizer, let window = coordinator.ownedWindow {
            window.removeGestureRecognizer(gesture)
            coordinator.gestureRecognizer = nil
            coordinator.ownedWindow = nil
        }
    }
    
    /// Prefer key window so tap-to-dismiss works on first screen and when multiple windows exist.
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var gestureRecognizer: UITapGestureRecognizer?
        weak var ownedWindow: UIWindow?
        
        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else { return true }
            var currentView: UIView? = view
            while let v = currentView {
                if v is UITextField || v is UITextView || v is UIButton {
                    return false
                }
                currentView = v.superview
            }
            return true
        }
    }
}

// 3D Digit Effect Modifier
struct Digit3DEffect: ViewModifier {
    let baseColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: baseColor.opacity(1.0), location: 0.0),
                        .init(color: baseColor.opacity(0.98), location: 0.3),
                        .init(color: baseColor.opacity(0.95), location: 0.7),
                        .init(color: baseColor.opacity(0.92), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // Dark shadow below (depth) - reduced intensity
            .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1.5)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            // Subtle highlight on top (embossed effect) - reduced shine
            .shadow(color: baseColor.opacity(0.2), radius: 0, x: 0, y: -1)
            .shadow(color: .white.opacity(0.08), radius: 0, x: 0, y: -0.5)
    }
}

extension View {
    func digit3D(baseColor: Color) -> some View {
        self.modifier(Digit3DEffect(baseColor: baseColor))
    }
}

struct FinanceView: View {
    @StateObject private var viewModel = FinanceViewModel()
    @StateObject private var categoryViewModel = CategoryAnalyticsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var xpStore = XPStore.shared
    @State private var languageRefreshTrigger = UUID()
    @State private var showUpgradeSheet = false
    @State private var isSpendingLimitsExpanded = false
    @State private var isSavingGoalsExpanded = false
    @State private var isCategoryAnalysisExpanded = false
    @State private var isAssetsExpanded = false
    @State private var isTransactionsExpanded = false
    @State private var isTrendsAndComparisonsExpanded = false
    @State private var selectedCategory: String? = nil
    @State private var showAddAssetSheet = false
    @State private var showAddSavingGoalSheet = false
    @State private var showAddSavingLimitSheet = false
    @State private var showAddSpendingLimitSheet = false
    @State private var showAddTransactionSheet = false
    @State private var showMonthPicker = false
    @State private var tempSelectedMonth: Date = Date()
    @State private var targetToScrollTo: String? = nil
    @State private var animatedHealthScore: Double = 0
    @State private var animatedProgress: Double = 0 // Smooth progress for the bar
    @State private var healthScoreTimer: Timer?
    @State private var animationDebounceTimer: Timer?
    
    // MARK: - Helper Functions
    
    /// Health score is based only on income vs expenses for the selected month.
    private var currentHealthScore: FinanceViewModel.HealthScore {
        viewModel.calculateHealthScore()
    }
    
    /// Tracks only the data that affects health score: income, expenses, selected month.
    private var healthScoreDataHash: String {
        let income = String(format: "%.2f", viewModel.monthlyIncome)
        let expenses = String(format: "%.2f", viewModel.monthlyExpenses)
        let month = viewModel.selectedMonth.timeIntervalSince1970
        return "\(income)-\(expenses)-\(month)"
    }
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Debounced update when income/expenses change (e.g. after refresh or month change).
    private func triggerHealthScoreAnimation() {
        animationDebounceTimer?.invalidate()
        animationDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [self] _ in
            Task { @MainActor in
                let freshScore = self.viewModel.calculateHealthScore()
                self.startHealthScoreAnimation(to: freshScore.score)
            }
        }
        if let timer = animationDebounceTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Animate health score with counting effect.
    private func startHealthScoreAnimation(to targetScore: Int) {
        // Cancel any existing animation timer
        healthScoreTimer?.invalidate()
        healthScoreTimer = nil
        
        // Don't reset if we're already close to the target (smooth transition)
        let currentScore = Int(animatedHealthScore)
        if abs(currentScore - targetScore) <= 2 && animatedHealthScore > 0 {
            // Already close to target, just animate to exact value
            animatedHealthScore = Double(targetScore)
            animatedProgress = Double(targetScore)
            return
        }
        
        // Reset to 0 for new animation
        animatedHealthScore = 0
        animatedProgress = 0
        
        let target = Double(targetScore)
        
        // Calculate duration based on target score
        // For scores 0-100: duration ranges from 1.8 to 2.8 seconds
        let duration: TimeInterval = 1.8 + (Double(targetScore) / 100.0) * 1.0
        
        let startTime = Date()
        let updateInterval: TimeInterval = 0.02 // Update every 20ms for smooth animation
        
        healthScoreTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            // Use easeOut curve for smooth progress bar animation
            let easedProgress = 1 - pow(1 - progress, 3)
            animatedProgress = target * easedProgress
            
            // For the number display, show integer counting (round to show each number)
            let currentValue = target * easedProgress
            let roundedValue = round(currentValue)
            
            // Only update the displayed number when it changes (to show counting effect)
            if roundedValue != animatedHealthScore {
                animatedHealthScore = roundedValue
            }
            
            // Stop timer when animation completes
            if progress >= 1.0 {
                animatedHealthScore = target
                animatedProgress = target
                timer.invalidate()
                healthScoreTimer = nil
            }
        }
        
        // Add timer to RunLoop to ensure it works properly
        if let timer = healthScoreTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // Comprehensive assets including goals (matching webapp behavior)
    private var comprehensiveAssets: [Asset] {
        var allAssets = viewModel.assets
        
        // Combine all targets and goals that have money in them
        let allGoalsAndTargets = (viewModel.goals + viewModel.targets)
            .filter { $0.currentAmount > 0 } // Only include goals/targets with money
        
        // Include all goals/targets with money (any goal you put money into should appear)
        // Also prioritize savings-related goals for proper categorization
        for goal in allGoalsAndTargets {
            // Check if this goal is already in assets (avoid duplicates)
            if !allAssets.contains(where: { $0.id == "target-\(goal.id)" }) {
                // Determine asset type based on goal type
                let assetType: String
                if goal.targetType.lowercased() == "savings" ||
                   goal.targetType.lowercased() == "emergency_fund" ||
                   goal.title.lowercased().contains("savings") ||
                   goal.title.lowercased().contains("fund") {
                    assetType = "savings"
                } else {
                    // Default to savings for any goal with money
                    assetType = "savings"
                }
                
                let goalAsset = Asset(
                    id: "target-\(goal.id)",
                    accountId: goal.accountId,
                    name: goal.title,
                    type: assetType,
                    currentValue: goal.currentAmount,
                    description: "Target: \(formatCurrency(goal.targetAmount)) (\(Int(goal.progressPercentage))% complete)",
                    currency: goal.currency,
                    createdAt: goal.createdAt,
                    updatedAt: goal.updatedAt
                )
                allAssets.append(goalAsset)
            }
        }
        
        return allAssets
    }
    
    // Total assets value
    private var totalAssetsValue: Double {
        comprehensiveAssets.reduce(0) { $0 + $1.currentValue }
    }
    
    // MARK: - View Components
    private var monthPickerView: some View {
        HStack(spacing: 0) {
            Button(action: {
                let calendar = Calendar.current
                if let previousMonth = calendar.date(byAdding: .month, value: -1, to: viewModel.selectedMonth) {
                    viewModel.changeMonth(to: previousMonth)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
            }
            
            Spacer()
            
            // Month Display
            Button(action: {
                tempSelectedMonth = viewModel.selectedMonth
                showMonthPicker = true
            }) {
                VStack(spacing: 4) {
                    Text(monthYearString(from: viewModel.selectedMonth))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text(AppL10n.t("finance.tap_to_change"))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            Button(action: {
                let calendar = Calendar.current
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedMonth) {
                    // Don't allow future months
                    let now = Date()
                    let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                    if nextMonth <= currentMonth {
                        viewModel.changeMonth(to: nextMonth)
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
            }
            .disabled({
                let calendar = Calendar.current
                let now = Date()
                let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedMonth) {
                    return nextMonth > currentMonth
                }
                return true
            }())
            .opacity({
                let calendar = Calendar.current
                let now = Date()
                let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: viewModel.selectedMonth) {
                    return nextMonth > currentMonth ? 0.3 : 1.0
                }
                return 0.3
            }())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
    
    private var balanceCardView: some View {
        // Use computed property that updates reactively
        let healthScore = currentHealthScore
        // Available Funds = monthlyBalance from API (income - expenses - transfers to goal + transfers from goal)
        let availableFunds = viewModel.monthlyBalance
        
        // Use animated score for display (integer for counting effect)
        let displayScore = Int(animatedHealthScore)
        // Use smooth progress for the bar animation
        let progressPercentage = animatedProgress / 100.0
        
        // Determine health score color based on actual score (not animated)
        let scoreColor: Color
        if healthScore.score >= 70 {
            scoreColor = .green
        } else if healthScore.score >= 40 {
            scoreColor = .orange
        } else {
            scoreColor = .red
        }
        
        let balanceColor: Color = availableFunds >= 0 ? .green : .red
        
        // Determine health score status based on actual score (not animated)
        let statusText: String
        if healthScore.score >= 80 {
            statusText = AppL10n.t("finance.score_excellent")
        } else if healthScore.score >= 60 {
            statusText = AppL10n.t("finance.score_good")
        } else if healthScore.score >= 40 {
            statusText = AppL10n.t("finance.score_fair")
        } else {
            statusText = AppL10n.t("finance.score_needs_work")
        }
        
        return VStack(spacing: 0) {
            // Health Score Section
            VStack(spacing: 12) {
                Text(AppL10n.t("finance.health_score"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.8)
                
                // Semicircle progress with score (premium iOS speedometer style)
                ZStack(alignment: .bottom) {
                    // Background semicircle track (refined iOS style)
                    Circle()
                        .trim(from: 0.0, to: 0.5)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(180))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(y: 12)
                    
                    // Progress semicircle with red-to-orange-to-green gradient (animated)
                    Circle()
                        .trim(from: 0.0, to: 0.5 * progressPercentage)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .red, location: 0.0),
                                    .init(color: .orange, location: 0.5),
                                    .init(color: .green, location: 1.0)
                                ]),
                                startPoint: .trailing,
                                endPoint: .leading
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(180))
                        .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 2)
                        .shadow(color: scoreColor.opacity(0.2), radius: 4, x: 0, y: 1)
                        .offset(y: 12)
                    
                    // Inner glow effect with matching gradient (animated)
                    Circle()
                        .trim(from: 0.0, to: 0.5 * progressPercentage)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .red.opacity(0.4), location: 0.0),
                                    .init(color: .orange.opacity(0.4), location: 0.5),
                                    .init(color: .green.opacity(0.4), location: 1.0)
                                ]),
                                startPoint: .trailing,
                                endPoint: .leading
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(180))
                        .blur(radius: 4)
                        .offset(y: 12)
                    
                    // Score number and status as one unified piece (animated)
                    VStack(spacing: 2) {
                        VStack(spacing: 0) {
                            Text("\(displayScore)")
                                .font(.system(size: 67, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor)
                                .digit3D(baseColor: scoreColor)
                                .offset(y: 3)
                            
                            Text("/100")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(0.5)
                                .digit3D(baseColor: .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        
                        Text(statusText)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(scoreColor)
                    }
                    .offset(y: -30)
                }
                .frame(width: 320, height: 180)
                .onAppear {
                    // When card appears, show score if data is already loaded (e.g. returning to tab)
                    if !viewModel.isLoading {
                        let freshScore = viewModel.calculateHealthScore()
                        startHealthScoreAnimation(to: freshScore.score)
                    }
                }
                .onChange(of: viewModel.isLoading) { oldValue, newValue in
                    // When loading finishes, update health score once (income/expenses are ready)
                    if oldValue == true && newValue == false {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            let freshScore = viewModel.calculateHealthScore()
                            startHealthScoreAnimation(to: freshScore.score)
                        }
                    }
                }
                .onChange(of: healthScoreDataHash) { oldValue, newValue in
                    // When income, expenses, or month change (and not loading), update score
                    if oldValue != newValue && !viewModel.isLoading {
                        triggerHealthScoreAnimation()
                    }
                }
                .onDisappear {
                    // Clean up timers when view disappears
                    healthScoreTimer?.invalidate()
                    healthScoreTimer = nil
                    animationDebounceTimer?.invalidate()
                    animationDebounceTimer = nil
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 2)
            
            // Metrics Grid: Income, Expenses, Balance, Total Balance
            VStack(spacing: 0) {
                // First row: Income and Expenses
                HStack(spacing: 0) {
                    // Income
                    VStack(spacing: 10) {
                        Text(AppL10n.t("finance.income"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.8)
                        
                        Text(formatCurrency(viewModel.monthlyIncome))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .digit3D(baseColor: .green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.5)
                        .padding(.vertical, 8)
                    
                    // Expenses
                    VStack(spacing: 10) {
                        Text(AppL10n.t("finance.expenses"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.8)
                        
                        Text(formatCurrency(viewModel.monthlyExpenses))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                            .digit3D(baseColor: .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                // Horizontal divider
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
                
                // Second row: Balance and Total Balance
                HStack(spacing: 0) {
                    // Balance
                    VStack(spacing: 10) {
                        Text(AppL10n.t("finance.balance"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.8)
                        
                        Text(formatCurrency(availableFunds))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(balanceColor)
                            .digit3D(baseColor: balanceColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.5)
                        .padding(.vertical, 8)
                    
                    // Total Balance
                    VStack(spacing: 10) {
                        Text(AppL10n.t("finance.total_balance"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.8)
                        
                        Text(formatCurrency(viewModel.cumulativeTotalBalance))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .liquidGlass(cornerRadius: 22)
        .padding(.horizontal, 20)
    }
    
    private var trendsAndComparisonsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isTrendsAndComparisonsExpanded.toggle()
                    if isTrendsAndComparisonsExpanded {
                        // Load historical data when expanded
                        viewModel.loadHistoricalData()
                    }
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.insights"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isTrendsAndComparisonsExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTrendsAndComparisonsExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            
            if isTrendsAndComparisonsExpanded {
                if subscriptionManager.isPremium {
                    VStack(spacing: 20) {
                        // Period Selector
                        ComparisonPeriodSelectorView(viewModel: viewModel)
                            .padding(.horizontal, 20)
                            .transition(.expandSection)
                        
                        // Income vs Expenses Bar Chart
                        VStack(alignment: .leading, spacing: 16) {
                            let chartData = viewModel.getComparisonData(for: viewModel.comparisonPeriod)
                            EnhancedIncomeExpenseBarChart(
                                data: chartData,
                                currency: userCurrency,
                                isExpanded: isTrendsAndComparisonsExpanded
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .liquidGlass(cornerRadius: 20)
                            .padding(.horizontal, 20)
                        }
                        .transition(.expandSection)
                    }
                    .padding(.top, 8)
                } else {
                    PremiumGateView(onUpgrade: { showUpgradeSheet = true })
                        .padding(.top, 8)
                        .transition(.expandSection)
                }
            }
        }
    }
    
    private var categoryAnalysisView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isCategoryAnalysisExpanded.toggle()
                    if isCategoryAnalysisExpanded {
                        // Load category data filtered by selected month
                        let calendar = Calendar.current
                        let month = calendar.component(.month, from: viewModel.selectedMonth)
                        let year = calendar.component(.year, from: viewModel.selectedMonth)
                        categoryViewModel.loadData(month: month, year: year)
                    }
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // Premium glass circle background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.category_analysis"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isCategoryAnalysisExpanded ? 180 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCategoryAnalysisExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PremiumSettingsButtonStyle())
            
            if isCategoryAnalysisExpanded {
                if !subscriptionManager.isPremium {
                    PremiumGateView(onUpgrade: { showUpgradeSheet = true })
                        .padding(.top, 8)
                        .transition(.expandSection)
                } else {
                // Single section container (like webapp's insight-card)
                VStack(spacing: 0) {
                    // Always show existing data immediately (even during refresh).
                    // Only show a minimal loading/empty state when we truly have no data yet.
                    if let data = categoryViewModel.categoryData {
                        VStack(spacing: 24) {
                            // Perfect Donut Chart - Progressive design with enhanced glass morphism
                            GeometryReader { geometry in
                                let chartSize = min(geometry.size.width, geometry.size.height)
                                let radius = chartSize / 2 - 10
                                let innerRadius = radius * 0.6
                                let innerCircleDiameter = innerRadius * 2
                                
                                ZStack {
                                    // Enhanced 3D Donut chart
                                    DonutChartView3D(categories: data.categories, selectedCategory: selectedCategory)
                                        .drawingGroup() // Ensures smooth rendering
                                    
                                    // Center text - shows selected category, largest category, total count, or "No data available"
                                    VStack(spacing: 6) {
                                        if data.categories.isEmpty {
                                            Text(AppL10n.t("finance.no_data_available"))
                                                .font(.system(size: min(18, innerCircleDiameter * 0.2), weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.6))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.6)
                                        } else if let selectedCategory = selectedCategory,
                                           let category = data.categories.first(where: { $0.name == selectedCategory }) {
                                            Text(String(format: "%.1f%%", category.percentage))
                                                .font(.system(size: min(42, innerCircleDiameter * 0.35), weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .digit3D(baseColor: .white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                            
                                            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category.name)) // Display with proper case, not all caps
                                                .font(.system(size: min(12, innerCircleDiameter * 0.1), weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.6))
                                                .tracking(0.5)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                        } else if data.categories.first != nil {
                                            // Show largest category by default (first is sorted by percentage descending)
                                            Text("\(data.categories.count)")
                                                .font(.system(size: min(42, innerCircleDiameter * 0.35), weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .digit3D(baseColor: .white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                            
                                            Text(data.categories.count == 1 ? "category" : "categories")
                                                .font(.system(size: min(12, innerCircleDiameter * 0.1), weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.6))
                                                .tracking(0.5)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                        } else {
                                            Text("\(data.categoryCount)")
                                                .font(.system(size: min(42, innerCircleDiameter * 0.35), weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .digit3D(baseColor: .white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                            
                                            Text(AppL10n.t("finance.categories"))
                                                .font(.system(size: min(12, innerCircleDiameter * 0.1), weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.6))
                                                .tracking(0.8)
                                                .textCase(.uppercase)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                        }
                                    }
                                    .frame(width: innerCircleDiameter * 0.9, height: innerCircleDiameter * 0.9)
                                    .clipped()
                                }
                            }
                            .frame(height: 240)
                            .padding(.top, 24)
                            .opacity(isCategoryAnalysisExpanded ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isCategoryAnalysisExpanded)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategory)
                            
                            // Scrollable Category List - Progressive design with enhanced cards
                            if !data.categories.isEmpty {
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 14) {
                                        ForEach(Array(data.categories.enumerated()), id: \.element.id) { index, category in
                                            Button(action: {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    selectedCategory = selectedCategory == category.name ? nil : category.name
                                                }
                                            }) {
                                                FinanceCategoryRow(
                                                    category: category,
                                                    isSelected: selectedCategory == category.name,
                                                    trend: categoryViewModel.categoryTrends[category.name]
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .contentShape(Rectangle())
                                            .opacity(isCategoryAnalysisExpanded ? 1 : 0)
                                            .offset(y: isCategoryAnalysisExpanded ? 0 : 20)
                                            .animation(
                                                .spring(response: 0.5, dampingFraction: 0.8)
                                                    .delay(Double(index) * 0.03),
                                                value: isCategoryAnalysisExpanded
                                            )
                                        }
                                    }
                                    .padding(.bottom, 8)
                                }
                                .frame(maxHeight: 400) // Limit height for scrolling
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    } else if categoryViewModel.isLoading {
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.loading"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    } else {
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.no_category_data"))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.15).opacity(0.95),
                                    Color(white: 0.12).opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                )
                .padding(.horizontal, 20)
                .transition(.expandSection)
                }
            }
        }
    }
    
    private var spendingLimitsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isSpendingLimitsExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // Premium glass circle background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.95),
                                        Color.red.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.spending_limits"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isSpendingLimitsExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSpendingLimitsExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PremiumSettingsButtonStyle())
            
            if isSpendingLimitsExpanded {
                if !subscriptionManager.isPremium {
                    PremiumGateView(onUpgrade: { showUpgradeSheet = true })
                        .padding(.top, 8)
                        .transition(.expandSection)
                } else if viewModel.goals.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(AppL10n.t("finance.no_spending_limits"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(AppL10n.t("finance.add_first_limit"))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            if subscriptionManager.isPremium {
                                showAddSpendingLimitSheet = true
                            } else {
                                showUpgradeSheet = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppL10n.t("finance.add_spending_limit"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                } else {
                    // Row height: ~85px (28px vertical padding + ~57px content height)
                    let rowHeight: CGFloat = 85
                    let dividerHeight: CGFloat = 1
                    let maxVisibleRows: CGFloat = 3.5
                    // Include "Add Spending Limit" button as first row
                    let totalItemCount = 1 + viewModel.goals.count
                    let itemCount = CGFloat(totalItemCount)
                    let heightForThreePointFiveRows = 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                    let calculatedHeight: CGFloat = {
                        if itemCount <= maxVisibleRows {
                            // Extend with every added section: height = content only (1, 2, or 3.5 rows)
                            let fullRows = floor(itemCount)
                            let partialRow = itemCount - fullRows
                            let dividers = max(0, Int(fullRows) - 1)
                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                        } else {
                            // More than 3.5 items: cap at 3.5 rows and scroll the rest
                            return heightForThreePointFiveRows
                        }
                    }()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Add Spending Limit button as first item in the list (matching GoalRow design)
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                if subscriptionManager.isPremium {
                                    showAddSpendingLimitSheet = true
                                } else {
                                    showUpgradeSheet = true
                                }
                            }) {
                                HStack(spacing: 16) {
                                    // Limit icon with premium glass effect (matching GoalRow)
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.red.opacity(0.95),
                                                        Color.red.opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    // Spending limit details (matching GoalRow)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(AppL10n.t("finance.add_spending_limit"))
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.95))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .opacity(isSpendingLimitsExpanded ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(0.01),
                                value: isSpendingLimitsExpanded
                            )
                            
                            // Divider after Add Spending Limit button
                            PremiumDivider()
                                .padding(.leading, 76)
                                .opacity(isSpendingLimitsExpanded ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(0.02),
                                    value: isSpendingLimitsExpanded
                                )
                            
                            // Goals list
                            ForEach(Array(viewModel.goals.enumerated()), id: \.element.id) { index, goal in
                                GoalRow(goal: goal, viewModel: viewModel)
                                    .opacity(isSpendingLimitsExpanded ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(Double(index + 1) * 0.025),
                                        value: isSpendingLimitsExpanded
                                    )
                                
                                if index < viewModel.goals.count - 1 {
                                    PremiumDivider()
                                        .padding(.leading, 76)
                                        .opacity(isSpendingLimitsExpanded ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                .delay(Double(index + 1) * 0.025 + 0.01),
                                            value: isSpendingLimitsExpanded
                                        )
                                }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .clipped()
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
            }
        }
    }
    
    private var savingGoalsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isSavingGoalsExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // Premium glass circle background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.saving_goals"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isSavingGoalsExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSavingGoalsExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PremiumSettingsButtonStyle())
            
            if isSavingGoalsExpanded {
                if !subscriptionManager.isPremium {
                    PremiumGateView(onUpgrade: { showUpgradeSheet = true })
                        .padding(.top, 8)
                        .transition(.expandSection)
                } else {
                // Goals total reserve summary (same design as Total Assets)
                if !viewModel.targets.isEmpty {
                    let goalsTotalReserve = viewModel.targets.reduce(0.0) { $0 + $1.currentAmount }
                    HStack {
                        Text(AppL10n.t("finance.goals_total_reserve"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.8)
                        
                        Spacer()
                        
                        Text(formatCurrency(goalsTotalReserve))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .digit3D(baseColor: .green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .liquidGlass(cornerRadius: 20)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
                
                if viewModel.targets.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "target")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(AppL10n.t("finance.no_saving_goals"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(AppL10n.t("finance.add_first_goal"))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            if subscriptionManager.isPremium {
                                showAddSavingGoalSheet = true
                            } else {
                                showUpgradeSheet = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppL10n.t("finance.add_saving_goal"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                } else {
                    // Row height: ~85px (28px vertical padding + ~57px content height)
                    let rowHeight: CGFloat = 85
                    let dividerHeight: CGFloat = 1
                    let maxVisibleRows: CGFloat = 3.5
                    // Include "Add Saving Goal" button as first row
                    let totalItemCount = 1 + viewModel.targets.count
                    let itemCount = CGFloat(totalItemCount)
                    let heightForThreePointFiveRows = 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                    let calculatedHeight: CGFloat = {
                        if itemCount <= maxVisibleRows {
                            // Extend with every added section: height = content only (1, 2, or 3.5 rows)
                            let fullRows = floor(itemCount)
                            let partialRow = itemCount - fullRows
                            let dividers = max(0, Int(fullRows) - 1)
                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                        } else {
                            // More than 3.5 items: cap at 3.5 rows and scroll the rest
                            return heightForThreePointFiveRows
                        }
                    }()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Add Saving Goal button as first item in the list (matching TargetRow design)
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                if subscriptionManager.isPremium {
                                    showAddSavingGoalSheet = true
                                } else {
                                    showUpgradeSheet = true
                                }
                            }) {
                                HStack(spacing: 16) {
                                    // Target icon with premium glass effect (matching TargetRow)
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    // Saving goal details (matching TargetRow)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(AppL10n.t("finance.add_saving_goal"))
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.95))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .opacity(isSavingGoalsExpanded ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(0.01),
                                value: isSavingGoalsExpanded
                            )
                            
                            // Divider after Add Saving Goal button
                            PremiumDivider()
                                .padding(.leading, 76)
                                .opacity(isSavingGoalsExpanded ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(0.02),
                                    value: isSavingGoalsExpanded
                                )
                            
                            // Target list
                            ForEach(Array(viewModel.targets.enumerated()), id: \.element.id) { index, target in
                                TargetRow(target: target, viewModel: viewModel)
                                    .id("target-\(target.id)")
                                    .opacity(isSavingGoalsExpanded ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(Double(index + 1) * 0.025),
                                        value: isSavingGoalsExpanded
                                    )
                                
                                if index < viewModel.targets.count - 1 {
                                    PremiumDivider()
                                        .padding(.leading, 76)
                                        .opacity(isSavingGoalsExpanded ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                .delay(Double(index + 1) * 0.025 + 0.01),
                                            value: isSavingGoalsExpanded
                                        )
                                }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .clipped()
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
                }
            }
        }
    }
    
    private var assetsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isAssetsExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // Premium glass circle background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.95),
                                        Color.green.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.assets"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isAssetsExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isAssetsExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PremiumSettingsButtonStyle())
            
            if isAssetsExpanded {
                if !subscriptionManager.isPremium {
                    PremiumGateView(onUpgrade: { showUpgradeSheet = true })
                        .padding(.top, 8)
                        .transition(.expandSection)
                } else {
                // Total Assets Summary (shown when expanded)
                if !comprehensiveAssets.isEmpty {
                    HStack {
                        Text(AppL10n.t("finance.total_assets"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.8)
                        
                        Spacer()
                        
                        Text(formatCurrency(totalAssetsValue))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .digit3D(baseColor: .green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .liquidGlass(cornerRadius: 20)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
                
                if comprehensiveAssets.isEmpty {
                    // Empty state - same design as Add First Transaction / Limits / Goals
                    VStack(spacing: 20) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(AppL10n.t("finance.no_assets"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(AppL10n.t("finance.add_first_asset"))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            if subscriptionManager.isPremium {
                                showAddAssetSheet = true
                            } else {
                                showUpgradeSheet = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppL10n.t("finance.add_asset"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                } else {
                    // Row height: ~85px (28px vertical padding + ~57px content height)
                    let rowHeight: CGFloat = 85
                    let dividerHeight: CGFloat = 1
                    let maxVisibleRows: CGFloat = 3.5
                    // Include "Add Asset" button as first row
                    let totalItemCount = 1 + comprehensiveAssets.count
                    let itemCount = CGFloat(totalItemCount)
                    let heightForThreePointFiveRows = 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                    let calculatedHeight: CGFloat = {
                        if itemCount <= maxVisibleRows {
                            // Extend with every added section: height = content only (1, 2, or 3.5 rows)
                            let fullRows = floor(itemCount)
                            let partialRow = itemCount - fullRows
                            let dividers = max(0, Int(fullRows) - 1)
                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                        } else {
                            // More than 3.5 items: cap at 3.5 rows and scroll the rest
                            return heightForThreePointFiveRows
                        }
                    }()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Add Asset button as first item in the list (matching AssetRow design)
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                if subscriptionManager.isPremium {
                                    showAddAssetSheet = true
                                } else {
                                    showUpgradeSheet = true
                                }
                            }) {
                                HStack(spacing: 16) {
                                    // Asset icon with premium glass effect (matching AssetRow)
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.green.opacity(0.95),
                                                        Color.green.opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    // Asset details (matching AssetRow)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(AppL10n.t("finance.add_asset"))
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.95))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .opacity(isAssetsExpanded ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(0.01),
                                value: isAssetsExpanded
                            )
                            
                            // Divider after Add Asset button
                            PremiumDivider()
                                .padding(.leading, 76)
                                .opacity(isAssetsExpanded ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                        .delay(0.02),
                                    value: isAssetsExpanded
                                )
                            
                            // Asset list
                            ForEach(Array(comprehensiveAssets.enumerated()), id: \.element.id) { index, asset in
                                AssetRow(asset: asset, isVirtualAsset: asset.id.hasPrefix("target-"), viewModel: viewModel)
                                    .opacity(isAssetsExpanded ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(Double(index + 1) * 0.025),
                                        value: isAssetsExpanded
                                    )
                                
                                if index < comprehensiveAssets.count - 1 {
                                    PremiumDivider()
                                        .padding(.leading, 76)
                                        .opacity(isAssetsExpanded ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                .delay(Double(index + 1) * 0.025 + 0.01),
                                            value: isAssetsExpanded
                                        )
                                }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .clipped()
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
                }
            }
        }
    }
    
    private var xpLevelWidgetView: some View {
        Group {
            if let xpStats = xpStore.xpStats {
                XPLevelWidget(xpStats: xpStats)
            }
        }
    }
    
    private var transactionsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                    isTransactionsExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // Premium glass circle background with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text(AppL10n.t("finance.transactions"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isTransactionsExpanded ? 90 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTransactionsExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
            }
            .buttonStyle(PremiumSettingsButtonStyle())
            .id("transactions-section")
            
            if isTransactionsExpanded {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                        .padding()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .liquidGlass(cornerRadius: 18)
                        .padding(.horizontal, 20)
                        .transition(.expandSection)
                } else if viewModel.transactions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(AppL10n.t("finance.no_transactions"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(AppL10n.t("finance.add_first_transaction"))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showAddTransactionSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(AppL10n.t("finance.add_transaction"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                } else {
                    // Always show all transactions - Transactions section is independent
                    let allTransactions = viewModel.transactions
                    
                    // Row height: ~85px (28px vertical padding + ~57px content height)
                    let rowHeight: CGFloat = 85
                    let dividerHeight: CGFloat = 1
                    let maxVisibleRows: CGFloat = 3.5
                    // Include "Add Transaction" button as first row
                    let totalItemCount = 1 + allTransactions.count
                    let itemCount = CGFloat(totalItemCount)
                    let heightForThreePointFiveRows = 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                    let calculatedHeight: CGFloat = {
                        if itemCount <= maxVisibleRows {
                            // Extend with every added section: height = content only (1, 2, or 3.5 rows)
                            let fullRows = floor(itemCount)
                            let partialRow = itemCount - fullRows
                            let dividers = max(0, Int(fullRows) - 1)
                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                        } else {
                            // More than 3.5 items: cap at 3.5 rows and scroll the rest
                            return heightForThreePointFiveRows
                        }
                    }()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Add Transaction button as first item (inline with transactions)
                            AddTransactionRow(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showAddTransactionSheet = true
                            })
                            .opacity(isTransactionsExpanded ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(0.01),
                                value: isTransactionsExpanded
                            )
                            
                            // Divider after Add Transaction button
                            if !allTransactions.isEmpty {
                                PremiumDivider()
                                    .padding(.leading, 82)
                                    .opacity(isTransactionsExpanded ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(0.02),
                                        value: isTransactionsExpanded
                                    )
                            }
                            
                            // Transaction list - always shows all transactions
                            ForEach(Array(allTransactions.enumerated()), id: \.element.id) { index, transaction in
                                TransactionRow(transaction: transaction, viewModel: viewModel)
                                    .opacity(isTransactionsExpanded ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(Double(index + 1) * 0.025),
                                        value: isTransactionsExpanded
                                    )
                                
                                if index < allTransactions.count - 1 {
                                    PremiumDivider()
                                        .padding(.leading, 82)
                                        .opacity(isTransactionsExpanded ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                .delay(Double(index + 1) * 0.025 + 0.01),
                                            value: isTransactionsExpanded
                                        )
                                }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .clipped()
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal, 20)
                    .transition(.expandSection)
                }
            }
        }
    }
    
    /// Error banner at top of Finance page (same style as Chat).
    private var financeErrorBanner: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(AppL10n.t("chat.error"))
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: {
                            viewModel.errorMessage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.red.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            NavigationView {
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            // Fixed safe area bar - smooth gradient from transparent (bottom) to darker (top/status bar)
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0),
                                    Color.black.opacity(0.5),
                                    Color.black.opacity(0.9),
                                    Color.black
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: 0.5)
                            .frame(maxWidth: .infinity)
                            
                            ScrollView {
                                VStack(spacing: 20) {
                                    financeErrorBanner
                                    monthPickerView
                                    balanceCardView
                                    trendsAndComparisonsView
                                    categoryAnalysisView
                                    transactionsView
                                    spendingLimitsView
                                    savingGoalsView
                                    assetsView
                                    xpLevelWidgetView
                                    
                                    Spacer(minLength: 40)
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToTarget"))) { notification in
                                if let targetId = notification.object as? String {
                                    targetToScrollTo = targetId
                                    // Expand Saving Goals section if not already expanded
                                    if !isSavingGoalsExpanded {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            isSavingGoalsExpanded = true
                                        }
                                    }
                                    // Wait a bit for the section to expand, then scroll
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            proxy.scrollTo("target-\(targetId)", anchor: .center)
                                        }
                                    }
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FilterTransactionsByCategory"))) { notification in
                                // Filter transactions by category when limit button is clicked
                                if let category = notification.object as? String {
                                    withAnimation {
                                        selectedCategory = category
                                        // Scroll to transactions section
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation {
                                                proxy.scrollTo("transactions-section", anchor: .top)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .background(Color.black)
                .navigationBarHidden(true)
                .navigationBarTitleDisplayMode(.inline)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TargetCreated"))) { _ in
                    // Refresh targets when a new one is created
                    Task {
                        await viewModel.loadTargets()
                    }
                }
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .background(Color.black)
        }
        .onAppear {
            viewModel.loadData()
            // Refresh shared XP store so Level card is up to date (single source of truth)
            Task { await XPStore.shared.refresh() }
            // Health score will update automatically when isLoading changes to false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LanguageChanged"))) { _ in
            languageRefreshTrigger = UUID()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
                // Also refresh category analytics if expanded
                if isCategoryAnalysisExpanded {
                    let calendar = Calendar.current
                    let month = calendar.component(.month, from: viewModel.selectedMonth)
                    let year = calendar.component(.year, from: viewModel.selectedMonth)
                    categoryViewModel.loadData(month: month, year: year)
                }
                // Health score will update automatically via onChange(of: isLoading) when refresh completes
            }
        }
        .onChange(of: viewModel.selectedMonth) { oldValue, newValue in
            // Reload category analytics when month changes (if expanded)
            if isCategoryAnalysisExpanded {
                let calendar = Calendar.current
                let month = calendar.component(.month, from: newValue)
                let year = calendar.component(.year, from: newValue)
                categoryViewModel.loadData(month: month, year: year)
            }
        }
        .sheet(isPresented: $showAddSavingGoalSheet) {
            AddSavingGoalSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddSavingLimitSheet) {
            AddSavingLimitSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddSpendingLimitSheet) {
            AddSpendingLimitSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddAssetSheet) {
            AddAssetSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddTransactionSheet) {
            AddTransactionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
        .onChange(of: showUpgradeSheet) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task { await subscriptionManager.refresh() }
            }
        }
        .onChange(of: showAddTransactionSheet) { oldValue, newValue in
            // When transaction sheet is dismissed, refresh data
            if oldValue == true && newValue == false {
                viewModel.refresh()
                // Health score updates when isLoading goes false after refresh
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TransactionAdded"))) { _ in
            viewModel.refresh()
            // Health score updates when isLoading goes false after refresh
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(
                selectedMonth: $tempSelectedMonth,
                onConfirm: {
                    let calendar = Calendar.current
                    let now = Date()
                    let currentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                    
                    // Don't allow future months
                    if tempSelectedMonth <= currentMonth {
                        viewModel.changeMonth(to: tempSelectedMonth)
                    }
                    showMonthPicker = false
                },
                onCancel: {
                    showMonthPicker = false
                }
            )
        }
    }
}

// TransactionItem is now defined in Models.swift

struct TransactionRow: View {
    let transaction: TransactionItem
    @ObservedObject var viewModel: FinanceViewModel
    @State private var showEditTransactionSheet = false
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon with premium glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.3),
                                Color(white: 0.15).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                
                Image(systemName: categoryIcon(transaction.category))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (transaction.type == "transfer"
                                    ? Color.orange.opacity(0.95)
                                    : (transaction.type == "income"
                                        ? Color.green.opacity(0.95)
                                        : Color.red.opacity(0.95))),
                                (transaction.type == "transfer"
                                    ? Color.orange.opacity(0.8)
                                    : (transaction.type == "income"
                                        ? Color.green.opacity(0.8)
                                        : Color.red.opacity(0.8)))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(CategoryDefinitions.shared.normalizeCategory(transaction.category)) // Display with proper case
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.3)
                    
                    Text(formatDate(transaction.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Amount (transfer: orange, amount only; income/expense: green/red with sign)
            Text(formatAmount(transaction.amount))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(transaction.type == "transfer" ? .orange : (transaction.type == "income" ? .green : .red))
                .digit3D(baseColor: transaction.type == "transfer" ? .orange : (transaction.type == "income" ? .green : .red))
            
            // Edit button (hidden for transfers — they are not editable as income/expense)
            if transaction.type != "transfer" {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showEditTransactionSheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .buttonStyle(PremiumSettingsButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
        .sheet(isPresented: $showEditTransactionSheet) {
            EditTransactionSheet(transaction: transaction, viewModel: viewModel)
        }
    }
    
    private func categoryIcon(_ category: String) -> String {
        let lowercased = category.lowercased()
        if lowercased.contains("transfer") {
            return "arrow.left.arrow.right"
        } else if lowercased.contains("food") || lowercased.contains("restaurant") {
            return "fork.knife"
        } else if lowercased.contains("transport") || lowercased.contains("car") {
            return "car.fill"
        } else if lowercased.contains("shopping") {
            return "bag.fill"
        } else if lowercased.contains("bills") || lowercased.contains("utility") {
            return "doc.text.fill"
        } else if lowercased.contains("entertainment") {
            return "gamecontroller.fill"
        } else if lowercased.contains("health") {
            return "heart.fill"
        } else if lowercased.contains("loan") {
            return "banknote"
        } else if lowercased.contains("debt") {
            return "creditcard.fill"
        } else if lowercased.contains("leasing") || lowercased.contains("lease") {
            return "doc.richtext.fill"
        } else {
            return "dollarsign.circle.fill"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
        if transaction.type == "transfer" {
            return formatted
        }
        let sign = transaction.type == "income" ? "+" : "-"
        return "\(sign)\(formatted)"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = dateFormatter.date(from: dateString) else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            guard let date = dateFormatter.date(from: dateString) else {
                return dateString
            }
            return formatDate(date)
        }
        return formatDate(date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let dateFormat = UserDefaults.standard.string(forKey: "anita_date_format") ?? "MM/DD/YYYY"
        let displayFormatter = DateFormatter()
        
        switch dateFormat {
        case "MM/DD/YYYY":
            displayFormatter.dateFormat = "MM/dd/yyyy"
        case "DD/MM/YYYY":
            displayFormatter.dateFormat = "dd/MM/yyyy"
        case "YYYY-MM-DD":
            displayFormatter.dateFormat = "yyyy-MM-dd"
        default:
            displayFormatter.dateStyle = .short
        }
        
        return displayFormatter.string(from: date)
    }
}

// Add Transaction Row - matches TransactionRow design exactly
struct AddTransactionRow: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Plus icon with premium glass effect (matching TransactionRow exactly)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.2).opacity(0.3),
                                    Color(white: 0.15).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Transaction details (matching TransactionRow layout exactly)
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppL10n.t("finance.add_transaction"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.clear)
        }
        .buttonStyle(PremiumSettingsButtonStyle())
    }
}

struct TargetRow: View {
    let target: Target
    @State private var showEditGoalSheet = false
    @ObservedObject var viewModel: FinanceViewModel
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    init(target: Target, viewModel: FinanceViewModel) {
        self.target = target
        self.viewModel = viewModel
    }
    
    private var isCompleted: Bool {
        target.progressPercentage >= 100
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon - checkmark for completed, or arrow for incomplete
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.3),
                                Color(white: 0.15).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.95),
                                    Color.green.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Image(systemName: "arrow.down.right")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            // Target details
            VStack(alignment: .leading, spacing: 6) {
                Text(target.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 6) {
                    Text("\(Int(target.progressPercentage))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isCompleted ? Color.green : .white.opacity(0.6))
                        .digit3D(baseColor: isCompleted ? Color.green : .white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    
                    Text(formatCurrency(target.currentAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .digit3D(baseColor: .white.opacity(0.5))
                    
                    Text(AppL10n.t("finance.of"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatCurrency(target.targetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .digit3D(baseColor: .white.opacity(0.5))
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                            .cornerRadius(2.5)
                        
                        Rectangle()
                            .fill(
                                isCompleted ?
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.9),
                                        Color.green.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92),
                                        Color(red: 0.5, green: 0.55, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(target.progressPercentage / 100), height: 5)
                            .cornerRadius(2.5)
                    }
                }
                .frame(height: 5)
                .padding(.top, 6)
            }
            
            Spacer()
            
            // Edit button - opens menu with options
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showEditGoalSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.2).opacity(0.3),
                                    Color(white: 0.15).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .buttonStyle(PremiumSettingsButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
        .sheet(isPresented: $showEditGoalSheet) {
            EditGoalSheet(target: target, viewModel: viewModel)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// Add Money to Goal Sheet with Calculator Interface
struct AddMoneyToGoalSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var amount: String = "0"
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.add_amount_to_goal"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Display amount
                    VStack(spacing: 8) {
                        Text(formatDisplayAmount())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                            .frame(height: 70)
                            .frame(maxWidth: .infinity)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Calculator keypad
                    VStack(spacing: 16) {
                        // Row 1: 1, 2, 3
                        HStack(spacing: 16) {
                            CalculatorButton(number: "1", action: { appendDigit("1") })
                            CalculatorButton(number: "2", action: { appendDigit("2") })
                            CalculatorButton(number: "3", action: { appendDigit("3") })
                        }
                        
                        // Row 2: 4, 5, 6
                        HStack(spacing: 16) {
                            CalculatorButton(number: "4", action: { appendDigit("4") })
                            CalculatorButton(number: "5", action: { appendDigit("5") })
                            CalculatorButton(number: "6", action: { appendDigit("6") })
                        }
                        
                        // Row 3: 7, 8, 9
                        HStack(spacing: 16) {
                            CalculatorButton(number: "7", action: { appendDigit("7") })
                            CalculatorButton(number: "8", action: { appendDigit("8") })
                            CalculatorButton(number: "9", action: { appendDigit("9") })
                        }
                        
                        // Row 4: decimal (,. or .), 0, ⌫
                        HStack(spacing: 16) {
                            CalculatorButton(number: Locale.current.decimalSeparator ?? ".", action: { appendDecimal() })
                            CalculatorButton(number: "0", action: { appendDigit("0") })
                            CalculatorButton(number: "⌫", action: { deleteLastDigit() })
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Add Button
                    Button(action: {
                        addMoneyToGoal()
                    }) {
                        HStack {
                            Spacer()
                            if isAdding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(AppL10n.t("finance.add"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .disabled(isAdding || amount == "0" || amount.isEmpty)
                    .opacity(isAdding || amount == "0" || amount.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if amount == "0" {
            amount = digit
        } else {
            amount += digit
        }
        errorMessage = nil
    }
    
    private func appendDecimal() {
        // Check if decimal separator already exists; use locale separator (comma or dot)
        let sep = Locale.current.decimalSeparator ?? "."
        if !amount.contains(".") && !amount.contains(",") {
            amount += sep
        }
    }
    
    private func deleteLastDigit() {
        if amount.count > 1 {
            amount = String(amount.dropLast())
        } else {
            amount = "0"
        }
    }
    
    private func getLocaleForCurrency(_ currencyCode: String) -> Locale {
        // Map currency codes to appropriate locales for correct formatting
        let localeMap: [String: String] = [
            "USD": "en_US",
            "EUR": "de_DE", // Uses comma as decimal separator
            "GBP": "en_GB",
            "JPY": "ja_JP",
            "CAD": "en_CA",
            "AUD": "en_AU",
            "CHF": "de_CH",
            "CNY": "zh_CN",
            "INR": "en_IN",
            "BRL": "pt_BR", // Uses comma as decimal separator
            "MXN": "es_MX",
            "KRW": "ko_KR"
        ]
        
        if let localeIdentifier = localeMap[currencyCode] {
            return Locale(identifier: localeIdentifier)
        }
        
        // Default to US locale if currency not found
        return Locale(identifier: "en_US")
    }
    
    private func formatDisplayAmount() -> String {
        // Use user's preferred currency from settings
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        formatter.usesGroupingSeparator = false // No thousand separators
        
        // If amount is "0" or empty, show just "0" with currency
        if amount == "0" || amount.isEmpty {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: 0)) ?? "0"
        }
        
        // Parse the amount value (accepts both comma and dot as decimal separator)
        if let value = amount.parseAmount() {
            // Check if user has entered decimal part
            let hasDecimal = amount.contains(".") || amount.contains(",")
            
            if hasDecimal {
                // Show decimals if user entered them
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            } else {
                // No decimals if user hasn't entered them
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
            }
            
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        // Fallback
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }
    
    private var selectedMonthDateString: String? {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: viewModel.selectedMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: firstOfMonth)
    }
    
    private func addMoneyToGoal() {
        guard let amountValue = amount.parseAmount(), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                let userId = viewModel.userId
                let newCurrentAmount = target.currentAmount + amountValue
                
                // Record transfer to goal (reduces Available Funds; not income/expense)
                _ = try await NetworkService.shared.createTransaction(
                    userId: userId,
                    type: "transfer",
                    amount: amountValue,
                    category: "Transfer to goal",
                    description: "To goal: \(target.title)",
                    date: selectedMonthDateString
                )
                
                _ = try await NetworkService.shared.updateTarget(
                    userId: userId,
                    targetId: target.id,
                    currentAmount: newCurrentAmount
                )
                
                await MainActor.run {
                    isAdding = false
                    dismiss()
                    viewModel.refresh()
                }
            } catch {
                print("[AddMoneyToGoalSheet] Error: \(error.localizedDescription)")
                await MainActor.run {
                    isAdding = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to add money: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Change Amount Sheet with Calculator Interface
struct ChangeAmountSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var amount: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    init(target: Target, viewModel: FinanceViewModel) {
        self.target = target
        self.viewModel = viewModel
        // Initialize with current target amount, remove trailing zeros
        let amountValue = target.targetAmount
        if amountValue.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number, no decimals
            _amount = State(initialValue: String(format: "%.0f", amountValue))
        } else {
            // Has decimals, show up to 2 decimal places
            _amount = State(initialValue: String(format: "%.2f", amountValue))
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.change_amount"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Display amount
                    VStack(spacing: 8) {
                        Text(formatDisplayAmount())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                        Color.white.opacity(0.98),
                                        Color.white.opacity(0.9)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                            .frame(height: 70)
                            .frame(maxWidth: .infinity)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Calculator keypad
                    VStack(spacing: 16) {
                        // Row 1: 1, 2, 3
                        HStack(spacing: 16) {
                            CalculatorButton(number: "1", action: { appendDigit("1") })
                            CalculatorButton(number: "2", action: { appendDigit("2") })
                            CalculatorButton(number: "3", action: { appendDigit("3") })
                        }
                        
                        // Row 2: 4, 5, 6
                        HStack(spacing: 16) {
                            CalculatorButton(number: "4", action: { appendDigit("4") })
                            CalculatorButton(number: "5", action: { appendDigit("5") })
                            CalculatorButton(number: "6", action: { appendDigit("6") })
                        }
                        
                        // Row 3: 7, 8, 9
                        HStack(spacing: 16) {
                            CalculatorButton(number: "7", action: { appendDigit("7") })
                            CalculatorButton(number: "8", action: { appendDigit("8") })
                            CalculatorButton(number: "9", action: { appendDigit("9") })
                        }
                        
                        // Row 4: decimal (,. or .), 0, ⌫
                        HStack(spacing: 16) {
                            CalculatorButton(number: Locale.current.decimalSeparator ?? ".", action: { appendDecimal() })
                            CalculatorButton(number: "0", action: { appendDigit("0") })
                            CalculatorButton(number: "⌫", action: { deleteLastDigit() })
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        changeAmount()
                    }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(AppL10n.t("finance.save"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                            LinearGradient(
                                                colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                            }
                        }
                    }
                    .disabled(isSaving || amount == "0" || amount.isEmpty)
                    .opacity(isSaving || amount == "0" || amount.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if amount == "0" {
            amount = digit
        } else {
            amount += digit
        }
        errorMessage = nil
    }
    
    private func appendDecimal() {
        let sep = Locale.current.decimalSeparator ?? "."
        if !amount.contains(".") && !amount.contains(",") {
            amount += sep
        }
    }
    
    private func deleteLastDigit() {
        if amount.count > 1 {
            amount = String(amount.dropLast())
        } else {
            amount = "0"
        }
    }
    
    private func getLocaleForCurrency(_ currencyCode: String) -> Locale {
        // Map currency codes to appropriate locales for correct formatting
        let localeMap: [String: String] = [
            "USD": "en_US",
            "EUR": "de_DE", // Uses comma as decimal separator
            "GBP": "en_GB",
            "JPY": "ja_JP",
            "CAD": "en_CA",
            "AUD": "en_AU",
            "CHF": "de_CH",
            "CNY": "zh_CN",
            "INR": "en_IN",
            "BRL": "pt_BR", // Uses comma as decimal separator
            "MXN": "es_MX",
            "KRW": "ko_KR"
        ]
        
        if let localeIdentifier = localeMap[currencyCode] {
            return Locale(identifier: localeIdentifier)
        }
        
        // Default to US locale if currency not found
        return Locale(identifier: "en_US")
    }
    
    private func formatDisplayAmount() -> String {
        // Use user's preferred currency from settings
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        formatter.usesGroupingSeparator = false // No thousand separators
        
        // If amount is "0" or empty, show just "0" with currency
        if amount == "0" || amount.isEmpty {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: 0)) ?? "0"
        }
        
        // Parse the amount value (accepts both comma and dot as decimal separator)
        if let value = amount.parseAmount() {
            // Check if user has entered decimal part
            let hasDecimal = amount.contains(".") || amount.contains(",")
            
            if hasDecimal {
                // Show decimals if user entered them
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            } else {
                // No decimals if user hasn't entered them
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
            }
            
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        // Fallback
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }
    
    private func changeAmount() {
        guard let amountValue = amount.parseAmount(), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        // Don't update if amount hasn't changed
        if amountValue == target.targetAmount {
            dismiss()
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let userId = viewModel.userId
                print("[ChangeAmountSheet] Updating target \(target.id) with new amount: \(amountValue)")
                
                let updatedTarget = try await NetworkService.shared.updateTarget(
                    userId: userId,
                    targetId: target.id,
                    targetAmount: amountValue
                )
                
                print("[ChangeAmountSheet] Successfully updated target. New amount: \(updatedTarget.target.targetAmount)")
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                    // Refresh the goals list to show updated data
                    viewModel.refresh()
                }
            } catch {
                print("[ChangeAmountSheet] Error updating target: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to update amount: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Edit Goal Sheet - Different options for savings goals vs budgets
struct EditGoalSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showAddSheet = false
    @State private var showTakeSheet = false
    @State private var showChangeAmountSheet = false
    @State private var showRemoveSheet = false
    
    // Check if this is a savings goal (not a budget)
    private var isSavingsGoal: Bool {
        target.targetType.lowercased() != "budget"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.edit_goal"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Action buttons - different for savings goals vs budgets
                    VStack(spacing: 12) {
                        if isSavingsGoal {
                            // Savings Goal: Add Money, Take Money, Remove (like assets)
                            // Add Money Button
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showAddSheet = true
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.green.opacity(0.95),
                                                        Color.green.opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    Text(AppL10n.t("finance.add_money"))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .liquidGlass(cornerRadius: 18)
                            .padding(.horizontal, 20)
                            
                            // Take Money Button
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showTakeSheet = true
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "minus")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color.orange.opacity(0.95),
                                                        Color.orange.opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    Text(AppL10n.t("finance.take_money"))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .liquidGlass(cornerRadius: 18)
                            .padding(.horizontal, 20)
                        } else {
                            // Budget: Change Amount, Remove
                            // Change Amount Button
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showChangeAmountSheet = true
                            }) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(white: 0.2).opacity(0.3),
                                                        Color(white: 0.15).opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.white.opacity(0.2),
                                                                Color.white.opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        
                                        Image(systemName: "pencil")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    
                                    Text(AppL10n.t("finance.change_amount"))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            .liquidGlass(cornerRadius: 18)
                            .padding(.horizontal, 20)
                        }
                        
                        // Remove Button (for both)
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showRemoveSheet = true
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(white: 0.2).opacity(0.3),
                                                    Color(white: 0.15).opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        }
                                    
                                    Image(systemName: "trash")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.red.opacity(0.95),
                                                    Color.red.opacity(0.8)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                Text(AppL10n.t("finance.remove"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.95))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 18)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMoneyToGoalSheet(target: target, viewModel: viewModel)
            }
            .sheet(isPresented: $showTakeSheet) {
                TakeMoneyFromGoalSheet(target: target, viewModel: viewModel)
            }
            .sheet(isPresented: $showChangeAmountSheet) {
                ChangeAmountSheet(target: target, viewModel: viewModel)
            }
            .sheet(isPresented: $showRemoveSheet) {
                RemoveGoalSheet(target: target, viewModel: viewModel)
            }
        }
    }
}

// Edit Asset Sheet with Add, Take, and Remove options
struct EditAssetSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showAddSheet = false
    @State private var showTakeSheet = false
    @State private var showRemoveSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.edit_asset"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(asset.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Action buttons - matching FinanceView row style
                    VStack(spacing: 12) {
                        // Add Button
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showAddSheet = true
                        }) {
                            HStack(spacing: 16) {
                                // Icon with premium glass circle
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(white: 0.2).opacity(0.3),
                                                    Color(white: 0.15).opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        }
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.green.opacity(0.95),
                                                    Color.green.opacity(0.8)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                // Text
                                Text(AppL10n.t("finance.add_value"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.95))
                                
                                Spacer()
                                
                                // Chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 18)
                        .padding(.horizontal, 20)
                        
                        // Take Button
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showTakeSheet = true
                        }) {
                            HStack(spacing: 16) {
                                // Icon with premium glass circle
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(white: 0.2).opacity(0.3),
                                                    Color(white: 0.15).opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        }
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.orange.opacity(0.95),
                                                    Color.orange.opacity(0.8)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                // Text
                                Text(AppL10n.t("finance.reduce_value"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.95))
                                
                                Spacer()
                                
                                // Chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 18)
                        .padding(.horizontal, 20)
                        
                        // Remove Button
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showRemoveSheet = true
                        }) {
                            HStack(spacing: 16) {
                                // Icon with premium glass circle
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(white: 0.2).opacity(0.3),
                                                    Color(white: 0.15).opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.2),
                                                            Color.white.opacity(0.1)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        }
                                    
                                    Image(systemName: "trash")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.red.opacity(0.95),
                                                    Color.red.opacity(0.8)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                // Text
                                Text(AppL10n.t("finance.remove_asset"))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.95))
                                
                                Spacer()
                                
                                // Chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 18)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddValueToAssetSheet(asset: asset, viewModel: viewModel)
            }
            .sheet(isPresented: $showTakeSheet) {
                ReduceAssetValueSheet(asset: asset, viewModel: viewModel)
            }
            .sheet(isPresented: $showRemoveSheet) {
                RemoveAssetSheet(asset: asset, viewModel: viewModel)
            }
        }
    }
}

// Take Money from Goal Sheet
struct TakeMoneyFromGoalSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var amount: String = "0"
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.take_amount_from_goal"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Display amount
                    VStack(spacing: 8) {
                        Text(formatDisplayAmount())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                            .frame(height: 70)
                            .frame(maxWidth: .infinity)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Calculator keypad
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CalculatorButton(number: "1", action: { appendDigit("1") })
                            CalculatorButton(number: "2", action: { appendDigit("2") })
                            CalculatorButton(number: "3", action: { appendDigit("3") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "4", action: { appendDigit("4") })
                            CalculatorButton(number: "5", action: { appendDigit("5") })
                            CalculatorButton(number: "6", action: { appendDigit("6") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "7", action: { appendDigit("7") })
                            CalculatorButton(number: "8", action: { appendDigit("8") })
                            CalculatorButton(number: "9", action: { appendDigit("9") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: Locale.current.decimalSeparator ?? ".", action: { appendDecimal() })
                            CalculatorButton(number: "0", action: { appendDigit("0") })
                            CalculatorButton(number: "⌫", action: { deleteLastDigit() })
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Take Button
                    Button(action: {
                        takeMoneyFromGoal()
                    }) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(AppL10n.t("finance.take"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.orange.opacity(0.9),
                                                Color.orange.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .disabled(isProcessing || amount == "0" || amount.isEmpty)
                    .opacity(isProcessing || amount == "0" || amount.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if amount == "0" {
            amount = digit
        } else {
            amount += digit
        }
        errorMessage = nil
    }
    
    private func appendDecimal() {
        if !amount.contains(".") && !amount.contains(",") {
            amount += (Locale.current.decimalSeparator ?? ".")
        }
    }
    
    private func deleteLastDigit() {
        if amount.count > 1 {
            amount = String(amount.dropLast())
        } else {
            amount = "0"
        }
    }
    
    private func getLocaleForCurrency(_ currencyCode: String) -> Locale {
        let localeMap: [String: String] = [
            "USD": "en_US",
            "EUR": "de_DE",
            "GBP": "en_GB",
            "JPY": "ja_JP",
            "CAD": "en_CA",
            "AUD": "en_AU",
            "CHF": "de_CH",
            "CNY": "zh_CN",
            "INR": "en_IN",
            "BRL": "pt_BR",
            "MXN": "es_MX",
            "KRW": "ko_KR"
        ]
        
        if let localeIdentifier = localeMap[currencyCode] {
            return Locale(identifier: localeIdentifier)
        }
        
        return Locale(identifier: "en_US")
    }
    
    private func formatDisplayAmount() -> String {
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        
        if amount == "0" || amount.isEmpty {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: 0)) ?? "0"
        }
        
        if let value = amount.parseAmount() {
            let hasDecimal = amount.contains(".") || amount.contains(",")
            
            if hasDecimal {
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
            } else {
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
            }
            
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }
    
    private func takeMoneyFromGoal() {
        guard let amountValue = amount.parseAmount(), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        if amountValue > target.currentAmount {
            errorMessage = "Cannot take more than current amount"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        let selectedMonthDateString: String? = {
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month], from: viewModel.selectedMonth)
            guard let firstOfMonth = calendar.date(from: comps) else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: firstOfMonth)
        }()
        
        Task {
            do {
                let userId = viewModel.userId
                let newCurrentAmount = target.currentAmount - amountValue
                
                // Record transfer from goal (increases Available Funds; not income/expense)
                _ = try await NetworkService.shared.createTransaction(
                    userId: userId,
                    type: "transfer",
                    amount: amountValue,
                    category: "Transfer from goal",
                    description: "From goal: \(target.title)",
                    date: selectedMonthDateString
                )
                
                _ = try await NetworkService.shared.updateTarget(
                    userId: userId,
                    targetId: target.id,
                    currentAmount: newCurrentAmount
                )
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    viewModel.refresh()
                }
            } catch {
                print("[TakeMoneyFromGoalSheet] Error: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessing = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to take money: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Remove Goal Sheet
struct RemoveGoalSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isRemoving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.remove_goal"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Warning message
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text(AppL10n.t("finance.remove_goal_confirm"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(AppL10n.t("finance.remove_goal_warning"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Remove Button
                        Button(action: {
                            removeGoal()
                        }) {
                            HStack {
                                Spacer()
                                if isRemoving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.remove_goal"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.9),
                                                Color.red.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .disabled(isRemoving)
                        .opacity(isRemoving ? 0.6 : 1.0)
                        
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text(AppL10n.t("common.cancel"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func removeGoal() {
        isRemoving = true
        errorMessage = nil
        
        Task {
            do {
                print("[RemoveGoalSheet] Deleting target: \(target.id)")
                try await viewModel.deleteTarget(targetId: target.id)
                
                print("[RemoveGoalSheet] Target deleted successfully")
                
                await MainActor.run {
                    isRemoving = false
                    dismiss()
                    // ViewModel already refreshes in deleteTarget, but ensure UI updates
                    viewModel.refresh()
                }
            } catch {
                print("[RemoveGoalSheet] Error deleting target: \(error.localizedDescription)")
                await MainActor.run {
                    isRemoving = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to remove goal: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Remove Target Sheet
struct RemoveTargetSheet: View {
    let target: Target
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isRemoving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.remove_budget"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(target.title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Warning message
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text(AppL10n.t("finance.remove_budget_confirm"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(AppL10n.t("finance.remove_goal_warning"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Remove Button
                        Button(action: {
                            removeTarget()
                        }) {
                            HStack {
                                Spacer()
                                if isRemoving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.remove_budget"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.9),
                                                Color.red.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .disabled(isRemoving)
                        .opacity(isRemoving ? 0.6 : 1.0)
                        
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text(AppL10n.t("common.cancel"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func removeTarget() {
        isRemoving = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.deleteTarget(targetId: target.id)
                await MainActor.run {
                    isRemoving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRemoving = false
                }
            }
        }
    }
}

// Add Value to Asset Sheet
struct AddValueToAssetSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var amount: String = "0"
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.add_value_to_asset"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(asset.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Display amount
                    VStack(spacing: 8) {
                        Text(formatDisplayAmount())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                            .frame(height: 70)
                            .frame(maxWidth: .infinity)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Calculator keypad
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CalculatorButton(number: "1", action: { appendDigit("1") })
                            CalculatorButton(number: "2", action: { appendDigit("2") })
                            CalculatorButton(number: "3", action: { appendDigit("3") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "4", action: { appendDigit("4") })
                            CalculatorButton(number: "5", action: { appendDigit("5") })
                            CalculatorButton(number: "6", action: { appendDigit("6") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "7", action: { appendDigit("7") })
                            CalculatorButton(number: "8", action: { appendDigit("8") })
                            CalculatorButton(number: "9", action: { appendDigit("9") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: Locale.current.decimalSeparator ?? ".", action: { appendDecimal() })
                            CalculatorButton(number: "0", action: { appendDigit("0") })
                            CalculatorButton(number: "⌫", action: { deleteLastDigit() })
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Add Button
                    Button(action: {
                        addValueToAsset()
                    }) {
                        HStack {
                            Spacer()
                            if isAdding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(AppL10n.t("finance.add"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                                Color(red: 0.5, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .disabled(isAdding || amount == "0" || amount.isEmpty)
                    .opacity(isAdding || amount == "0" || amount.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if amount == "0" {
            amount = digit
        } else {
            amount += digit
        }
        errorMessage = nil
    }
    
    private func appendDecimal() {
        let sep = Locale.current.decimalSeparator ?? "."
        if !amount.contains(".") && !amount.contains(",") {
            amount += sep
        }
    }
    
    private func deleteLastDigit() {
        if amount.count > 1 {
            amount = String(amount.dropLast())
        } else {
            amount = "0"
        }
    }
    
    private func getLocaleForCurrency(_ currencyCode: String) -> Locale {
        let localeMap: [String: String] = [
            "USD": "en_US", "EUR": "de_DE", "GBP": "en_GB", "JPY": "ja_JP",
            "CAD": "en_CA", "AUD": "en_AU", "CHF": "de_CH", "CNY": "zh_CN",
            "INR": "en_IN", "BRL": "pt_BR", "MXN": "es_MX", "KRW": "ko_KR"
        ]
        return Locale(identifier: localeMap[currencyCode] ?? "en_US")
    }
    
    private func formatDisplayAmount() -> String {
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        
        if amount == "0" || amount.isEmpty {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: 0)) ?? "0"
        }
        
        if let value = Double(amount) {
            let hasDecimal = amount.contains(".") || amount.contains(",")
            formatter.minimumFractionDigits = hasDecimal ? 0 : 0
            formatter.maximumFractionDigits = hasDecimal ? 2 : 0
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }
    
    private func addValueToAsset() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                let newValue = asset.currentValue + amountValue
                
                print("[AddValueToAssetSheet] Adding \(amountValue) to asset \(asset.id). New value: \(newValue)")
                
                try await viewModel.updateAsset(assetId: asset.id, currentValue: newValue)
                
                print("[AddValueToAssetSheet] Successfully updated asset")
                
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                print("[AddValueToAssetSheet] Error updating asset: \(error.localizedDescription)")
                await MainActor.run {
                    isAdding = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to add value: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Reduce Asset Value Sheet
struct ReduceAssetValueSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var amount: String = "0"
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.reduce_asset_value"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(asset.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Display amount
                    VStack(spacing: 8) {
                        Text(formatDisplayAmount())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                            .frame(height: 70)
                            .frame(maxWidth: .infinity)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Calculator keypad
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CalculatorButton(number: "1", action: { appendDigit("1") })
                            CalculatorButton(number: "2", action: { appendDigit("2") })
                            CalculatorButton(number: "3", action: { appendDigit("3") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "4", action: { appendDigit("4") })
                            CalculatorButton(number: "5", action: { appendDigit("5") })
                            CalculatorButton(number: "6", action: { appendDigit("6") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: "7", action: { appendDigit("7") })
                            CalculatorButton(number: "8", action: { appendDigit("8") })
                            CalculatorButton(number: "9", action: { appendDigit("9") })
                        }
                        
                        HStack(spacing: 16) {
                            CalculatorButton(number: Locale.current.decimalSeparator ?? ".", action: { appendDecimal() })
                            CalculatorButton(number: "0", action: { appendDigit("0") })
                            CalculatorButton(number: "⌫", action: { deleteLastDigit() })
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Reduce Button
                    Button(action: {
                        reduceAssetValue()
                    }) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(AppL10n.t("finance.reduce"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.orange.opacity(0.9),
                                                Color.orange.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .disabled(isProcessing || amount == "0" || amount.isEmpty)
                    .opacity(isProcessing || amount == "0" || amount.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func appendDigit(_ digit: String) {
        if amount == "0" {
            amount = digit
        } else {
            amount += digit
        }
        errorMessage = nil
    }
    
    private func appendDecimal() {
        let sep = Locale.current.decimalSeparator ?? "."
        if !amount.contains(".") && !amount.contains(",") {
            amount += sep
        }
    }
    
    private func deleteLastDigit() {
        if amount.count > 1 {
            amount = String(amount.dropLast())
        } else {
            amount = "0"
        }
    }
    
    private func getLocaleForCurrency(_ currencyCode: String) -> Locale {
        let localeMap: [String: String] = [
            "USD": "en_US", "EUR": "de_DE", "GBP": "en_GB", "JPY": "ja_JP",
            "CAD": "en_CA", "AUD": "en_AU", "CHF": "de_CH", "CNY": "zh_CN",
            "INR": "en_IN", "BRL": "pt_BR", "MXN": "es_MX", "KRW": "ko_KR"
        ]
        return Locale(identifier: localeMap[currencyCode] ?? "en_US")
    }
    
    private func formatDisplayAmount() -> String {
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        
        if amount == "0" || amount.isEmpty {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: 0)) ?? "0"
        }
        
        if let value = Double(amount) {
            let hasDecimal = amount.contains(".") || amount.contains(",")
            formatter.minimumFractionDigits = hasDecimal ? 0 : 0
            formatter.maximumFractionDigits = hasDecimal ? 2 : 0
            return formatter.string(from: NSNumber(value: value)) ?? "0"
        }
        
        return formatter.string(from: NSNumber(value: 0)) ?? "0"
    }
    
    private func reduceAssetValue() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        if amountValue > asset.currentValue {
            errorMessage = "Cannot reduce more than current value"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let newValue = asset.currentValue - amountValue
                
                print("[ReduceAssetValueSheet] Reducing \(amountValue) from asset \(asset.id). New value: \(newValue)")
                
                try await viewModel.updateAsset(assetId: asset.id, currentValue: newValue)
                
                print("[ReduceAssetValueSheet] Successfully updated asset")
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                print("[ReduceAssetValueSheet] Error updating asset: \(error.localizedDescription)")
                await MainActor.run {
                    isProcessing = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to reduce value: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Remove Asset Sheet
struct RemoveAssetSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isRemoving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.remove_asset"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(asset.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Warning message
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Text(AppL10n.t("finance.remove_asset_confirm"))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(AppL10n.t("finance.remove_goal_warning"))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Remove Button
                        Button(action: {
                            removeAsset()
                        }) {
                            HStack {
                                Spacer()
                                if isRemoving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.remove_asset"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.9),
                                                Color.red.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .disabled(isRemoving)
                        .opacity(isRemoving ? 0.6 : 1.0)
                        
                        // Cancel Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text(AppL10n.t("common.cancel"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func removeAsset() {
        isRemoving = true
        errorMessage = nil
        
        Task {
            do {
                print("[RemoveAssetSheet] Deleting asset: \(asset.id)")
                try await viewModel.deleteAsset(assetId: asset.id)
                
                print("[RemoveAssetSheet] Asset deleted successfully")
                
                await MainActor.run {
                    isRemoving = false
                    dismiss()
                }
            } catch {
                print("[RemoveAssetSheet] Error deleting asset: \(error.localizedDescription)")
                await MainActor.run {
                    isRemoving = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to remove asset: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// Calculator Button Component
struct CalculatorButton: View {
    let number: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Text(number)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .frame(width: 80, height: 80)
                .background {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.4),
                                        Color(white: 0.15).opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                }
        }
        .buttonStyle(CalculatorButtonStyle())
    }
}

struct CalculatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct GoalRow: View {
    let goal: Target
    @State private var showEditGoalSheet = false
    @ObservedObject var viewModel: FinanceViewModel
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    init(goal: Target, viewModel: FinanceViewModel) {
        self.goal = goal
        self.viewModel = viewModel
    }
    
    // Calculate period-specific spending for this goal
    private var periodSpending: Double {
        // For budget goals (goals with category), show spending in selected period
        if let goalCategory = goal.category, !goalCategory.isEmpty {
            return viewModel.getGoalSpending(for: goal)
        }
        // For other goals, use currentAmount (all-time)
        return goal.currentAmount
    }
    
    // Calculate progress percentage based on period spending vs limit
    private var periodProgressPercentage: Double {
        guard goal.targetAmount > 0 else { return 0 }
        // For budget goals, show how much of the limit has been spent
        if let goalCategory = goal.category, !goalCategory.isEmpty {
            return min((periodSpending / goal.targetAmount) * 100, 100)
        }
        // For savings goals, use standard progress
        return goal.progressPercentage
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Goal icon with premium glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.3),
                                Color(white: 0.15).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.95),
                                Color.red.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Goal details
            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 6) {
                    Text("\(Int(periodProgressPercentage))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .digit3D(baseColor: .white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    
                    // Show period spending for budget goals, currentAmount for savings
                    if let goalCategory = goal.category, !goalCategory.isEmpty {
                        Text(formatCurrency(periodSpending))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .digit3D(baseColor: .white.opacity(0.5))
                    } else {
                        Text(formatCurrency(goal.currentAmount))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .digit3D(baseColor: .white.opacity(0.5))
                    }
                    
                    Text(AppL10n.t("finance.of"))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatCurrency(goal.targetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .digit3D(baseColor: .white.opacity(0.5))
                }
                
                // Progress bar (red) - use period progress for budget goals
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 5)
                            .cornerRadius(2.5)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.8),
                                        Color.red.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(periodProgressPercentage / 100), height: 5)
                            .cornerRadius(2.5)
                    }
                }
                .frame(height: 5)
                .padding(.top, 6)
            }
            
            Spacer()
            
            // Edit button - opens menu with options
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showEditGoalSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.2).opacity(0.3),
                                    Color(white: 0.15).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .buttonStyle(PremiumSettingsButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
        .sheet(isPresented: $showEditGoalSheet) {
            EditGoalSheet(target: goal, viewModel: viewModel)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct AssetRow: View {
    let asset: Asset
    let isVirtualAsset: Bool
    @ObservedObject var viewModel: FinanceViewModel
    @State private var showEditAssetSheet = false
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    init(asset: Asset, isVirtualAsset: Bool = false, viewModel: FinanceViewModel) {
        self.asset = asset
        self.isVirtualAsset = isVirtualAsset
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Asset icon with premium glass effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.3),
                                Color(white: 0.15).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                
                Image(systemName: assetTypeIcon(asset.type))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                assetTypeColor(asset.type).opacity(0.95),
                                assetTypeColor(asset.type).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Asset details
            VStack(alignment: .leading, spacing: 5) {
                Text(asset.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 6) {
                    Text(getTranslatedAssetType(asset.type))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.3)
                    
                    if isVirtualAsset {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 11))
                        
                        Text(AppL10n.t("finance.auto"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .tracking(0.3)
                    }
                }
                
                // Show description for virtual assets (goals)
                if isVirtualAsset, let description = asset.description {
                    Text(description)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Value
            Text(formatCurrency(asset.currentValue))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .digit3D(baseColor: .white)
            
            // Edit button - only show for non-virtual assets
            if !isVirtualAsset {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showEditAssetSheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.2).opacity(0.3),
                                        Color(white: 0.15).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.95),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .buttonStyle(PremiumSettingsButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
        .sheet(isPresented: $showEditAssetSheet) {
            EditAssetSheet(asset: asset, viewModel: viewModel)
        }
    }
    
    private func assetTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "savings":
            return "wallet.pass.fill"
        case "investment":
            return "chart.line.uptrend.xyaxis"
        case "property":
            return "house.fill"
        case "vehicle":
            return "car.fill"
        case "cash":
            return "dollarsign.circle.fill"
        default:
            return "creditcard.fill"
        }
    }
    
    private func assetTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "savings":
            return .green
        case "investment":
            return .blue
        case "property":
            return .orange
        case "vehicle":
            return .purple
        case "cash":
            return .yellow
        default:
            return Color(red: 0.4, green: 0.49, blue: 0.92)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func getTranslatedAssetType(_ type: String) -> String {
        let keyMap: [String: String] = [
            "savings": "asset_type.savings",
            "investment": "asset_type.investment",
            "property": "asset_type.property",
            "vehicle": "asset_type.vehicle",
            "cash": "asset_type.cash"
        ]
        if let key = keyMap[type.lowercased()] {
            return AppL10n.t(key).uppercased()
        }
        return type.uppercased()
    }
}

struct XPLevelWidget: View {
    let xpStats: XPStats
    /// When true, uses smaller fonts and padding for sidebar / narrow contexts.
    var compact: Bool = false
    /// When set, shows an info (i) button on the progress row; tap opens XP explanation.
    var onInfoTap: (() -> Void)? = nil
    
    private var emojiSize: CGFloat { compact ? 32 : 40 }
    private var levelFontSize: CGFloat { compact ? 17 : 20 }
    private var titleFontSize: CGFloat { compact ? 12 : 14 }
    private var xpFontSize: CGFloat { compact ? 20 : 24 }
    private var xpLabelFontSize: CGFloat { compact ? 10 : 11 }
    private var progressLabelSize: CGFloat { compact ? 11 : 12 }
    private var stackSpacing: CGFloat { compact ? 14 : 20 }
    private var innerHPadding: CGFloat { compact ? 14 : 20 }
    private var innerVPadding: CGFloat { compact ? 14 : 18 }
    private var progressHeight: CGFloat { compact ? 8 : 10 }
    private var progressRadius: CGFloat { compact ? 4 : 5 }
    private var progressSpacing: CGFloat { compact ? 8 : 12 }
    private var glassRadius: CGFloat { compact ? 14 : 18 }
    private var outerHPadding: CGFloat { compact ? 0 : 20 }
    
    var body: some View {
        VStack(spacing: stackSpacing) {
            // Header with level info
            HStack {
                HStack(spacing: compact ? 12 : 16) {
                    Text(xpStats.level_emoji)
                        .font(.system(size: emojiSize))
                    
                    VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                        Text("\(AppL10n.t("finance.level")) \(xpStats.current_level)")
                            .font(.system(size: levelFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                        
                        Text(AppL10n.translatedLevelTitle(xpStats.level_title))
                            .font(.system(size: titleFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                    Text("\(xpStats.total_xp)")
                        .font(.system(size: xpFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .digit3D(baseColor: .white)
                    
                    Text(AppL10n.t("finance.xp"))
                        .font(.system(size: xpLabelFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }
            
            // Progress bar + info (i) on same row — "how XP works" next to progress
            VStack(alignment: .leading, spacing: progressSpacing) {
                HStack(spacing: 8) {
                    Text(xpStats.xp_to_next_level == 0 ? AppL10n.t("finance.xp_max_level") : "\(xpStats.xp_to_next_level) \(AppL10n.t("finance.xp_to_next_level"))")
                        .font(.system(size: progressLabelSize, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .digit3D(baseColor: .white.opacity(0.5))
                    
                    Spacer(minLength: 4)
                    
                    Text("\(xpStats.level_progress_percentage)%")
                        .font(.system(size: progressLabelSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .digit3D(baseColor: .white)
                    
                    if onInfoTap != nil {
                        Button(action: { onInfoTap?() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: compact ? 14 : 16))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: progressHeight)
                            .cornerRadius(progressRadius)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92),
                                        Color(red: 0.6, green: 0.4, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * CGFloat(xpStats.level_progress_percentage) / 100,
                                height: progressHeight
                            )
                            .cornerRadius(progressRadius)
                            .shadow(color: Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: progressHeight)
            }
        }
        .padding(.horizontal, innerHPadding)
        .padding(.vertical, innerVPadding)
        .liquidGlass(cornerRadius: glassRadius)
        .padding(.horizontal, outerHPadding)
    }
}

// Clean iOS-style CategoryRow for FinanceView
struct FinanceCategoryRow: View {
    let category: CategoryAnalytics
    var isSelected: Bool = false
    var trend: CategoryTrend? = nil
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Colored circle indicator - progressive design
            Circle()
                .fill(category.color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            
            // Category name and percentages - left aligned
            VStack(alignment: .leading, spacing: 4) {
                Text(CategoryDefinitions.shared.getTranslatedCategoryName(category.name))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Both percentages on the same line
                HStack(spacing: 8) {
                    // Category percentage
                    Text(String(format: "%.1f%%", category.percentage))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Trend percentage vs last year
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Image(systemName: trend.isPositive ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(trend.isPositive ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3))
                            
                            Text(String(format: "%.1f%%", abs(trend.percentageChange)))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(trend.isPositive ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color(red: 0.9, green: 0.3, blue: 0.3))
                        }
                    } else {
                        // Default trend if no data
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                            
                            Text("100.0%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Amount on the far right
            Text(formatCurrency(category.amount))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Base gradient background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.15).opacity(0.9),
                                Color(white: 0.12).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Category color overlay when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.2),
                                    category.color.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Border
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isSelected ? category.color.opacity(0.5) : Color.white.opacity(0.1),
                                isSelected ? category.color.opacity(0.3) : Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .contentShape(Rectangle())
    }
}

// Add Asset Sheet
struct AddAssetSheet: View {
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var assetName: String = ""
    @State private var assetType: String = "savings"
    @State private var currentValue: String = "0"
    @State private var description: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private let assetTypes = ["savings", "investment", "property", "vehicle", "cash", "other"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.add_asset"))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Asset Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.asset_name"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField(AppL10n.t("finance.placeholder.asset_name"), text: $assetName)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Asset Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.asset_type"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            Menu {
                                ForEach(assetTypes, id: \.self) { type in
                                    Button(action: {
                                        assetType = type
                                    }) {
                                        HStack {
                                            Text(type.capitalized)
                                            if assetType == type {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(assetType.capitalized)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Current Value
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.current_value"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("0", text: $currentValue)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Description (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.description_optional"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("Add a description...", text: $description, axis: .vertical)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }
                        
                        // Add Button
                        Button(action: {
                            addAsset()
                        }) {
                            HStack {
                                Spacer()
                                if isAdding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.add_asset"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.4, green: 0.49, blue: 0.92),
                                                    Color(red: 0.5, green: 0.55, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                        .disabled(isAdding || assetName.isEmpty || currentValue.isEmpty)
                        .opacity(isAdding || assetName.isEmpty || currentValue.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        
                        // Spacer to allow tapping empty space to dismiss keyboard
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func addAsset() {
        guard !assetName.isEmpty else {
            errorMessage = "Please enter an asset name"
            return
        }
        
        guard let value = currentValue.parseAmount(), value >= 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.addAsset(
                    name: assetName,
                    type: assetType,
                    currentValue: value,
                    description: description.isEmpty ? nil : description
                )
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Add Saving Goal Sheet
struct AddSavingGoalSheet: View {
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var goalTitle: String = ""
    @State private var targetAmount: String = "0"
    @State private var currentAmount: String = "0"
    @State private var description: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.add_saving_goal"))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Goal Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.goal_title"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField(AppL10n.t("finance.placeholder.goal_title"), text: $goalTitle)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Target Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.target_amount"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("0", text: $targetAmount)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Current Amount (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.current_amount_optional"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("0", text: $currentAmount)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Description (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.description_optional"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("Add a description...", text: $description, axis: .vertical)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }
                        
                        // Add Button
                        Button(action: {
                            addSavingGoal()
                        }) {
                            HStack {
                                Spacer()
                                if isAdding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.add_saving_goal"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.4, green: 0.49, blue: 0.92),
                                                    Color(red: 0.5, green: 0.55, blue: 0.95)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                        .disabled(isAdding || goalTitle.isEmpty || targetAmount.isEmpty)
                        .opacity(isAdding || goalTitle.isEmpty || targetAmount.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        
                        // Spacer to allow tapping empty space to dismiss keyboard
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func addSavingGoal() {
        guard !goalTitle.isEmpty else {
            errorMessage = "Please enter a goal title"
            return
        }
        
        guard let target = targetAmount.parseAmount(), target >= 0 else {
            errorMessage = "Please enter a valid target amount"
            return
        }
        
        let current = currentAmount.parseAmount() ?? 0.0
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.addTarget(
                    title: goalTitle,
                    description: description.isEmpty ? nil : description,
                    targetAmount: target,
                    currentAmount: current > 0 ? current : nil,
                    currency: userCurrency,
                    targetType: "savings"
                )
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Add Saving Limit Sheet
struct AddSavingLimitSheet: View {
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: String = "Salary"
    @State private var limitAmount: String = "0"
    @State private var description: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private var incomeCategories: [String] {
        CategoryDefinitions.shared.categories
            .filter { $0.id.hasPrefix("Income_") || $0.id == "Other" }
            .map { $0.name }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.add_saving_limit"))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.category"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            Menu {
                                ForEach(incomeCategories, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack {
                                            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category))
                                            if selectedCategory == category {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Limit Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.monthly_limit"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("0", text: $limitAmount)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Description (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.description_optional"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("Add a description...", text: $description, axis: .vertical)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }
                        
                        // Add Button
                        Button(action: {
                            addSavingLimit()
                        }) {
                            HStack {
                                Spacer()
                                if isAdding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.add_saving_limit"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.green.opacity(0.8),
                                                    Color.green.opacity(0.6)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                        .disabled(isAdding || limitAmount.isEmpty)
                        .opacity(isAdding || limitAmount.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        
                        // Spacer to allow tapping empty space to dismiss keyboard
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func addSavingLimit() {
        guard let limit = limitAmount.parseAmount(), limit >= 0 else {
            errorMessage = "Please enter a valid limit amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                // Create title in format "Monthly Limit: [Category]"
                let translatedCategory = CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory)
                let title = "\(AppL10n.t("finance.monthly_limit")): \(translatedCategory)"
                
                try await viewModel.addTarget(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    targetAmount: limit,
                    currentAmount: nil,
                    currency: userCurrency,
                    targetType: "budget",
                    category: selectedCategory
                )
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Add Spending Limit Sheet
struct AddSpendingLimitSheet: View {
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: String = CategoryDefinitions.defaultCategory
    @State private var limitAmount: String = "0"
    @State private var description: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private var expenseCategories: [String] {
        CategoryDefinitions.shared.categories
            .filter { !$0.id.hasPrefix("Income_") }
            .map { $0.name }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(AppL10n.t("finance.add_spending_limit"))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.category"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            Menu {
                                ForEach(expenseCategories, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack {
                                            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category))
                                            if selectedCategory == category {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory))
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Limit Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.monthly_limit"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("0", text: $limitAmount)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Description (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppL10n.t("finance.description_optional"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("Add a description...", text: $description, axis: .vertical)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                        }
                        
                        // Add Button
                        Button(action: {
                            addSpendingLimit()
                        }) {
                            HStack {
                                Spacer()
                                if isAdding {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.add_spending_limit"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.red.opacity(0.8),
                                                    Color.red.opacity(0.6)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                        .disabled(isAdding || limitAmount.isEmpty)
                        .opacity(isAdding || limitAmount.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        
                        // Spacer to allow tapping empty space to dismiss keyboard
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func addSpendingLimit() {
        guard let limit = limitAmount.parseAmount(), limit >= 0 else {
            errorMessage = "Please enter a valid limit amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                // Create title in format "Monthly Limit: [Category]"
                let translatedCategory = CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory)
                let title = "\(AppL10n.t("finance.monthly_limit")): \(translatedCategory)"
                
                try await viewModel.addTarget(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    targetAmount: limit,
                    currentAmount: nil,
                    currency: userCurrency,
                    targetType: "budget",
                    category: selectedCategory
                )
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// Month Picker Sheet
struct MonthPickerSheet: View {
    @Binding var selectedMonth: Date
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    private var maxDate: Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateInterval(of: .month, for: now)?.start ?? now
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text(AppL10n.t("finance.select_month"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 32)
                    
                    // Month and Year Picker (styled to look like single calendar)
                    HStack(spacing: 0) {
                        // Month Picker
                        Picker("Month", selection: Binding(
                            get: {
                                Calendar.current.component(.month, from: selectedMonth)
                            },
                            set: { newMonth in
                                let calendar = Calendar.current
                                let year = calendar.component(.year, from: selectedMonth)
                                let currentYear = calendar.component(.year, from: maxDate)
                                let currentMonth = calendar.component(.month, from: maxDate)
                                
                                // If selecting current year, don't allow months beyond current month
                                if year == currentYear && newMonth > currentMonth {
                                    return
                                }
                                
                                if let newDate = calendar.date(from: DateComponents(year: year, month: newMonth, day: 1)) {
                                    if newDate <= maxDate {
                                        selectedMonth = newDate
                                    }
                                }
                            }
                        )) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(from: month))
                                    .foregroundColor(.white)
                                    .tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .colorScheme(.dark)
                        
                        // Year Picker
                        Picker("Year", selection: Binding(
                            get: {
                                Calendar.current.component(.year, from: selectedMonth)
                            },
                            set: { newYear in
                                let calendar = Calendar.current
                                let month = calendar.component(.month, from: selectedMonth)
                                let currentYear = calendar.component(.year, from: maxDate)
                                let currentMonth = calendar.component(.month, from: maxDate)
                                
                                // If selecting current year, don't allow months beyond current month
                                if newYear == currentYear && month > currentMonth {
                                    if let newDate = calendar.date(from: DateComponents(year: newYear, month: currentMonth, day: 1)) {
                                        selectedMonth = newDate
                                    }
                                } else if let newDate = calendar.date(from: DateComponents(year: newYear, month: month, day: 1)) {
                                    if newDate <= maxDate {
                                        selectedMonth = newDate
                                    }
                                }
                            }
                        )) {
                            ForEach(2000...Calendar.current.component(.year, from: maxDate), id: \.self) { year in
                                Text(String(year))
                                    .foregroundColor(.white)
                                    .tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .colorScheme(.dark)
                        .accentColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                    }
                    .padding(.horizontal, 20)
                    .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            onCancel()
                        }) {
                            Text(AppL10n.t("common.cancel"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 12)
                        
                        Button(action: {
                            onConfirm()
                        }) {
                            Text(AppL10n.t("settings.done"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PremiumSettingsButtonStyle())
                        .liquidGlass(cornerRadius: 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Helper Functions
    func monthName(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: month, day: 1))!
        return formatter.string(from: date)
    }
    
    func monthAbbreviation(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: month, day: 1))!
        return formatter.string(from: date)
    }
    
    func getTranslatedAssetType(_ type: String) -> String {
        let keyMap: [String: String] = [
            "savings": "asset_type.savings",
            "investment": "asset_type.investment",
            "property": "asset_type.property",
            "vehicle": "asset_type.vehicle",
            "cash": "asset_type.cash"
        ]
        if let key = keyMap[type.lowercased()] {
            return AppL10n.t(key).uppercased()
        }
        return type.uppercased()
    }
}

// Add Transaction Sheet
struct AddTransactionSheet: View {
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var transactionType: String = "expense"
    @State private var amount: String = ""
    @State private var selectedCategory: String = CategoryDefinitions.defaultCategory
    @State private var description: String = ""
    @State private var selectedDate: Date = Date()
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    private let transactionTypes = ["expense", "income"]
    
    private var categories: [String] {
        if transactionType == "income" {
            // Only show income categories for income transactions
            return CategoryDefinitions.shared.categories
                .filter { $0.id.hasPrefix("Income_") || $0.id == "Other" }
                .map { $0.name }
        } else {
            // Show all expense categories (exclude income categories)
            return CategoryDefinitions.shared.categories
                .filter { !$0.id.hasPrefix("Income_") }
                .map { $0.name }
        }
    }
    
    // Get display name for category (translated)
    private func getCategoryDisplayName(_ categoryName: String) -> String {
        return CategoryDefinitions.shared.getTranslatedCategoryName(categoryName)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        typeSelectorView
                        amountFieldView
                        categoryPickerView
                        descriptionFieldView
                        datePickerView
                        errorMessageView
                        addButtonView
                        
                        // Spacer to allow tapping empty space to dismiss keyboard
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(AppL10n.t("finance.add_transaction"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    private var typeSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.type"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            HStack(spacing: 12) {
                ForEach(transactionTypes, id: \.self) { type in
                    typeButton(for: type)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func typeButton(for type: String) -> some View {
        Button(action: {
            transactionType = type
            // Reset category to default when switching transaction type
            if type == "income" {
                // Set to first income category or "Other"
                selectedCategory = categories.first ?? CategoryDefinitions.defaultCategory
            } else {
                selectedCategory = CategoryDefinitions.defaultCategory
            }
        }) {
            HStack {
                Spacer()
                Text(type.capitalized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(transactionType == type ? .white : .white.opacity(0.6))
                Spacer()
            }
            .padding(.vertical, 12)
            .background(typeButtonBackground(for: type))
            .overlay(typeButtonOverlay(for: type))
        }
    }
    
    private func typeButtonBackground(for type: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(transactionType == type ? 
                  (type == "expense" ? Color.red.opacity(0.2) : Color.green.opacity(0.2)) :
                  Color.white.opacity(0.1))
    }
    
    private func typeButtonOverlay(for type: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(transactionType == type ? 
                    (type == "expense" ? Color.red.opacity(0.5) : Color.green.opacity(0.5)) :
                    Color.clear, lineWidth: 1)
    }
    
    private var amountFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.amount"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            TextField("0" + (Locale.current.decimalSeparator ?? ".") + "00", text: $amount)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
    }
    
    private var categoryPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.category"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            Menu {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category))
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                    HStack {
                        Text(categories.contains(selectedCategory) ? CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory) : CategoryDefinitions.shared.getTranslatedCategoryName(categories.first ?? CategoryDefinitions.defaultCategory))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .onChange(of: transactionType) { oldValue, newValue in
                // Ensure selected category is valid for the new transaction type
                if !categories.contains(selectedCategory) {
                    selectedCategory = categories.first ?? CategoryDefinitions.defaultCategory
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var descriptionFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.description"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            TextField(AppL10n.t("finance.placeholder.transaction_description"), text: $description)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
    }
    
    private var datePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.date"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .accentColor(Color(red: 0.4, green: 0.49, blue: 0.92))
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 20)
        }
    }
    
    private var addButtonView: some View {
        Button(action: {
            addTransaction()
        }) {
            HStack {
                Spacer()
                if isAdding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(AppL10n.t("finance.add_transaction"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .frame(height: 56)
            .background(addButtonBackground)
        }
        .disabled(isAdding || amount.isEmpty)
        .opacity(isAdding || amount.isEmpty ? 0.6 : 1.0)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    private var addButtonBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.49, blue: 0.92),
                            Color(red: 0.5, green: 0.55, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private func addTransaction() {
        guard let amountValue = amount.parseAmount(), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        // Ensure selected category is valid for current transaction type
        let validCategory = categories.contains(selectedCategory) ? selectedCategory : (categories.first ?? CategoryDefinitions.defaultCategory)
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.addTransaction(
                    type: transactionType,
                    amount: amountValue,
                    category: validCategory,
                    description: description.isEmpty ? "Transaction" : description,
                    date: selectedDate
                )
                
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = "Failed to add transaction: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Edit Transaction Sheet
struct EditTransactionSheet: View {
    let transaction: TransactionItem
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var transactionType: String
    @State private var amount: String
    @State private var selectedCategory: String
    @State private var description: String
    @State private var selectedDate: Date
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showDeleteSheet = false
    
    private let transactionTypes = ["expense", "income"]
    
    private var categories: [String] {
        if transactionType == "income" {
            return CategoryDefinitions.shared.categories
                .filter { $0.id.hasPrefix("Income_") || $0.id == "Other" }
                .map { $0.name }
        } else {
            return CategoryDefinitions.shared.categories
                .filter { !$0.id.hasPrefix("Income_") }
                .map { $0.name }
        }
    }
    
    // Get display name for category (translated)
    private func getCategoryDisplayName(_ categoryName: String) -> String {
        return CategoryDefinitions.shared.getTranslatedCategoryName(categoryName)
    }
    
    init(transaction: TransactionItem, viewModel: FinanceViewModel) {
        self.transaction = transaction
        self.viewModel = viewModel
        
        // Initialize state with transaction values
        _transactionType = State(initialValue: transaction.type)
        _amount = State(initialValue: String(format: "%.2f", transaction.amount))
        _selectedCategory = State(initialValue: CategoryDefinitions.shared.normalizeCategory(transaction.category))
        _description = State(initialValue: transaction.description)
        
        // Parse date from transaction
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: transaction.date) ?? Date()
        _selectedDate = State(initialValue: date)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        typeSelectorView
                        amountFieldView
                        categoryPickerView
                        descriptionFieldView
                        datePickerView
                        errorMessageView
                        updateButtonView
                        deleteButtonView
                        
                        Spacer()
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hideKeyboard()
                            }
                    }
                }
                .dismissKeyboardOnSwipe()
            }
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        updateTransaction()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                    .disabled(isUpdating)
                }
            }
            .sheet(isPresented: $showDeleteSheet) {
                DeleteTransactionSheet(transaction: transaction, viewModel: viewModel)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text(AppL10n.t("finance.edit_transaction"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    private var typeSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.type"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(spacing: 12) {
                ForEach(transactionTypes, id: \.self) { type in
                    Button(action: {
                        transactionType = type
                        if !categories.contains(selectedCategory) {
                            selectedCategory = categories.first ?? CategoryDefinitions.defaultCategory
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text(type == "income" ? AppL10n.t("transaction.income") : AppL10n.t("transaction.expense"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(transactionType == type ? .white : .white.opacity(0.6))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(typeButtonBackground(for: type))
                        .overlay(typeButtonOverlay(for: type))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func typeButtonBackground(for type: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(transactionType == type ? 
                  (type == "expense" ? Color.red.opacity(0.2) : Color.green.opacity(0.2)) :
                  Color.white.opacity(0.1))
    }
    
    private func typeButtonOverlay(for type: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(transactionType == type ? 
                    (type == "expense" ? Color.red.opacity(0.5) : Color.green.opacity(0.5)) :
                    Color.clear, lineWidth: 1)
    }
    
    private var amountFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.amount"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            TextField("0" + (Locale.current.decimalSeparator ?? ".") + "00", text: $amount)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
    }
    
    private var categoryPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.category"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            Menu {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category))
                            if selectedCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(categories.contains(selectedCategory) ? CategoryDefinitions.shared.getTranslatedCategoryName(selectedCategory) : CategoryDefinitions.shared.getTranslatedCategoryName(categories.first ?? CategoryDefinitions.defaultCategory))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .onChange(of: transactionType) { oldValue, newValue in
                if !categories.contains(selectedCategory) {
                    selectedCategory = categories.first ?? CategoryDefinitions.defaultCategory
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var descriptionFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.description"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            TextField(AppL10n.t("finance.placeholder.transaction_description"), text: $description)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .padding(.horizontal, 20)
    }
    
    private var datePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppL10n.t("finance.date"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
            
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .accentColor(Color(red: 0.4, green: 0.49, blue: 0.92))
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.red.opacity(0.8))
                .padding(.horizontal, 20)
        }
    }
    
    private var updateButtonView: some View {
        Button(action: {
            updateTransaction()
        }) {
            HStack {
                Spacer()
                if isUpdating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(AppL10n.t("finance.update_transaction"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .frame(height: 56)
            .background(updateButtonBackground)
        }
        .disabled(isUpdating || amount.isEmpty)
        .opacity(isUpdating || amount.isEmpty ? 0.6 : 1.0)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var updateButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.49, blue: 0.92),
                        Color(red: 0.5, green: 0.55, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var deleteButtonView: some View {
        Button(action: {
            showDeleteSheet = true
        }) {
            Text(AppL10n.t("finance.delete_transaction"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.red.opacity(0.9))
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
    
    private func updateTransaction() {
        guard let amountValue = amount.parseAmount(), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        let validCategory = categories.contains(selectedCategory) ? selectedCategory : (categories.first ?? CategoryDefinitions.defaultCategory)
        
        isUpdating = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.updateTransaction(
                    transactionId: transaction.id,
                    type: transactionType,
                    amount: amountValue,
                    category: validCategory,
                    description: description.isEmpty ? "Transaction" : description,
                    date: selectedDate
                )
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    let msg = error.localizedDescription
                    errorMessage = msg.hasPrefix("Failed to update") ? msg : "Failed to update transaction: \(msg)"
                }
            }
        }
    }
}

// Delete Transaction Sheet
struct DeleteTransactionSheet: View {
    let transaction: TransactionItem
    @ObservedObject var viewModel: FinanceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isDeleting = false
    @State private var errorMessage: String?
    
    private var userCurrency: String {
        UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = userCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text(AppL10n.t("finance.delete_transaction"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(AppL10n.t("finance.delete_transaction_confirm"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    // Transaction details
                    VStack(spacing: 16) {
                        HStack {
                            Text("\(AppL10n.t("finance.description")):")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(transaction.description)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text(AppL10n.t("finance.amount_label"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(formatCurrency(transaction.amount))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(transaction.type == "transfer" ? .orange : (transaction.type == "income" ? .green : .red))
                                .digit3D(baseColor: transaction.type == "transfer" ? .orange : (transaction.type == "income" ? .green : .red))
                        }
                        
                        HStack {
                            Text(AppL10n.t("finance.category_label"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(CategoryDefinitions.shared.normalizeCategory(transaction.category))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            deleteTransaction()
                        }) {
                            HStack {
                                Spacer()
                                if isDeleting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(AppL10n.t("finance.delete_transaction"))
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.9),
                                                Color.red.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .disabled(isDeleting)
                        .opacity(isDeleting ? 0.6 : 1.0)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Text(AppL10n.t("common.cancel"))
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .frame(height: 56)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppL10n.t("settings.done")) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                }
            }
        }
    }
    
    private func deleteTransaction() {
        isDeleting = true
        errorMessage = nil
        
        Task {
            do {
                print("[DeleteTransactionSheet] Deleting transaction: \(transaction.id)")
                try await viewModel.deleteTransaction(transactionId: transaction.id)
                
                print("[DeleteTransactionSheet] Transaction deleted successfully")
                
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("[DeleteTransactionSheet] Error deleting transaction: \(error.localizedDescription)")
                await MainActor.run {
                    isDeleting = false
                    let errorDesc = error.localizedDescription
                    if errorDesc.contains("cannot connect") || errorDesc.contains("timed out") {
                        errorMessage = "Could not connect to server. Please check:\n1. Backend is running\n2. Backend URL is correct"
                    } else {
                        errorMessage = "Failed to delete transaction: \(errorDesc)"
                    }
                }
            }
        }
    }
}

// MARK: - Chart Components

struct BalanceLineChart: View {
    let data: [MonthlyBalance]
    let currency: String
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text(AppL10n.t("finance.no_data_available"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 200)
        } else {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let maxBalance = data.map { $0.balance }.max() ?? 1
                let minBalance = data.map { $0.balance }.min() ?? 0
                let range = max(maxBalance - minBalance, 1)
                
                ZStack {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<5) { i in
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                            if i < 4 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Chart line
                    Path { path in
                        for (index, point) in data.enumerated() {
                            let x = CGFloat(index) / CGFloat(max(data.count - 1, 1)) * width
                            let normalizedBalance = (point.balance - minBalance) / range
                            let y = height - (normalizedBalance * height * 0.8) - (height * 0.1)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.9),
                                Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Data points
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                        let x = CGFloat(index) / CGFloat(max(data.count - 1, 1)) * width
                        let normalizedBalance = (point.balance - minBalance) / range
                        let y = height - (normalizedBalance * height * 0.8) - (height * 0.1)
                        
                        Circle()
                            .fill(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                    
                    // X-axis labels
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                                Text(formatMonth(point.month))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .frame(height: 200)
        }
    }
}

struct IncomeExpenseBarChart: View {
    let data: [MonthlyIncomeExpense]
    let currency: String
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text(AppL10n.t("finance.no_data_available"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 200)
        } else {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let maxValue = data.map { max($0.income, $0.expenses) }.max() ?? 1
                let barWidth = (width - CGFloat((data.count - 1) * 8)) / CGFloat(data.count)
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                        VStack(spacing: 4) {
                            // Bars
                            ZStack(alignment: .bottom) {
                                // Income bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.green.opacity(0.8),
                                                Color.green.opacity(0.6)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth * 0.45, height: max(2, (point.income / maxValue) * height * 0.7))
                                
                                // Expense bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.red.opacity(0.8),
                                                Color.red.opacity(0.6)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth * 0.45, height: max(2, (point.expenses / maxValue) * height * 0.7))
                                    .offset(x: barWidth * 0.45 + 2)
                            }
                            
                            // Month label
                            Text(formatMonth(point.month))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: barWidth)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 200)
        }
    }
}

// MARK: - Comparison Views

struct TrendIndicator: View {
    let change: Double
    let isPositive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%.1f%%", abs(change)))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .digit3D(baseColor: isPositive ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
        }
        .foregroundColor(isPositive ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((isPositive ? Color.green : Color.red).opacity(0.15))
        )
    }
}

struct PremiumTrendIndicator: View {
    let change: Double
    let isPositive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: 12, weight: .bold))
            Text(String(format: "%.1f%%", abs(change)))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .digit3D(baseColor: .white)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: isPositive ? [
                            Color.green.opacity(0.9),
                            Color.green.opacity(0.7)
                        ] : [
                            Color.red.opacity(0.9),
                            Color.red.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: isPositive ? [
                                    Color.green.opacity(0.5),
                                    Color.green.opacity(0.3)
                                ] : [
                                    Color.red.opacity(0.5),
                                    Color.red.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: (isPositive ? Color.green : Color.red).opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

struct MonthToMonthComparisonView: View {
    @ObservedObject var viewModel: FinanceViewModel
    let currency: String
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(AppL10n.t("finance.month_to_month"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Income comparison
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppL10n.t("finance.income"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text(formatCurrency(viewModel.monthlyIncome))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                    Spacer()
                    let change = viewModel.getMonthToMonthChange(type: .income)
                    TrendIndicator(change: change.percentage, isPositive: change.value >= 0)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Expenses comparison
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppL10n.t("finance.expenses"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text(formatCurrency(viewModel.monthlyExpenses))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                    Spacer()
                    let change = viewModel.getMonthToMonthChange(type: .expenses)
                    TrendIndicator(change: change.percentage, isPositive: change.value <= 0)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Enhanced Comparison Components

struct ComparisonPeriodSelectorView: View {
    @ObservedObject var viewModel: FinanceViewModel
    @State private var isDragging: Bool = false
    @State private var currentSliderValue: Double = 1.0 // Track current slider position for magnification
    
    // Convert slider value to ComparisonPeriod
    private func valueToPeriod(_ value: Double) -> ComparisonPeriod {
        let rounded = Int(value.rounded())
        let clamped = max(1, min(12, rounded))
        return ComparisonPeriod(rawValue: clamped) ?? .oneMonth
    }
    
    // Convert ComparisonPeriod to slider value
    private func periodToValue(_ period: ComparisonPeriod) -> Double {
        return Double(period.rawValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppL10n.t("finance.months"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                Color(red: 0.5, green: 0.55, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Ruler-style month labels on top
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let sliderPadding: CGFloat = 16
                    let availableWidth = width - sliderPadding * 2
                    
                    ZStack(alignment: .leading) {
                        // Draw ruler marks for all months 1-12
                        ForEach(1...12, id: \.self) { month in
                            let normalizedPosition = (Double(month - 1) / Double(12 - 1))
                            let position = sliderPadding + normalizedPosition * availableWidth
                            
                            // Calculate distance from slider position
                            let distance = abs(Double(month) - currentSliderValue)
                            
                            // Determine if this is the selected digit (very close to slider)
                            let isSelected = distance < 0.5
                            
                            // Uniform spacing for all digits
                            let frameWidth: CGFloat = 36 // Same width for all digits
                            let offsetX: CGFloat = -18 // Uniform offset for centering
                            
                            if isSelected {
                                // Selected digit: bold, bigger, bright white
                                Text("\(month)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: frameWidth)
                                    .offset(x: position + offsetX)
                                    .animation(.interpolatingSpring(stiffness: 120, damping: 15), value: currentSliderValue)
                            } else {
                                // Unselected digits: regular weight, smaller, grey
                                let maxDistance: Double = 5.5
                                let normalizedDistance = min(distance / maxDistance, 1.0)
                                let easedDistance = 1.0 - pow(1.0 - normalizedDistance, 3)
                                
                                // Scale factor for unselected: smaller and decreases with distance
                                let scaleFactor = 0.65 + (1.0 - easedDistance) * 0.15 // Range: 0.65 to 0.8
                                let fontSize = 22.0 * scaleFactor // Base size 22, scales down
                                
                                // Grey color with low opacity for unselected digits
                                let greyOpacity = 0.4 + (1.0 - easedDistance) * 0.15 // Range: 0.4 to 0.55
                                
                                Text("\(month)")
                                    .font(.system(size: fontSize, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(greyOpacity))
                                    .frame(width: frameWidth)
                                    .scaleEffect(scaleFactor)
                                    .offset(x: position + offsetX)
                                    .animation(.interpolatingSpring(stiffness: 120, damping: 15), value: currentSliderValue)
                            }
                        }
                    }
                }
                .frame(height: 40)
                .padding(.bottom, 4)
                
                // Custom slider with better touch handling
                VStack(spacing: 0) {
                    Slider(
                        value: Binding(
                            get: { periodToValue(viewModel.comparisonPeriod) },
                            set: { newValue in
                                // Update current slider value for real-time magnification effect
                                currentSliderValue = newValue
                                
                                if !isDragging {
                                    isDragging = true
                                }
                                let newPeriod = valueToPeriod(newValue)
                                // Only update if period actually changed to avoid unnecessary updates
                                if viewModel.comparisonPeriod != newPeriod {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    // Update period without reloading data immediately for smooth interaction
                                    viewModel.comparisonPeriod = newPeriod
                                }
                            }
                        ),
                        in: 1...12,
                        step: 1
                    )
                    .tint(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.49, blue: 0.92),
                                Color(red: 0.5, green: 0.55, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                    )
                    .onChange(of: viewModel.comparisonPeriod) { _, _ in
                        // Update slider value when period changes externally
                        currentSliderValue = periodToValue(viewModel.comparisonPeriod)
                        // Reset dragging state when period changes externally
                        isDragging = false

                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                isDragging = false
                                // Reload data when drag ends to ensure graphs have correct data
                                // But don't show loading state if we already have data
                                viewModel.loadHistoricalData()
                            }
                    )
                    .onAppear {
                        // Initialize slider value
                        currentSliderValue = periodToValue(viewModel.comparisonPeriod)
                        // Ensure default is 1 month
                        if viewModel.comparisonPeriod != .oneMonth {
                            viewModel.comparisonPeriod = .oneMonth
                            currentSliderValue = periodToValue(.oneMonth)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 18)
    }
}

struct EnhancedMonthToMonthComparisonView: View {
    @ObservedObject var viewModel: FinanceViewModel
    let currency: String
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppL10n.t("finance.month_to_month"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Income comparison
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green.opacity(0.9))
                            Text(AppL10n.t("finance.income"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(formatCurrency(viewModel.monthlyIncome))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                    
                    Spacer()
                    
                    let change = viewModel.getMonthToMonthChange(type: .income)
                    VStack(alignment: .trailing, spacing: 4) {
                        PremiumTrendIndicator(change: change.percentage, isPositive: change.value >= 0)
                        Text(formatCurrency(abs(change.value)))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .digit3D(baseColor: .white.opacity(0.5))
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.2),
                                    Color.green.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.green.opacity(0.4),
                                            Color.green.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.green.opacity(0.15), radius: 12, x: 0, y: 4)
                )
                
                // Expenses comparison
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red.opacity(0.9))
                            Text(AppL10n.t("finance.expenses"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(formatCurrency(viewModel.monthlyExpenses))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                    
                    Spacer()
                    
                    let change = viewModel.getMonthToMonthChange(type: .expenses)
                    VStack(alignment: .trailing, spacing: 4) {
                        PremiumTrendIndicator(change: change.percentage, isPositive: change.value <= 0)
                        Text(formatCurrency(abs(change.value)))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .digit3D(baseColor: .white.opacity(0.5))
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.2),
                                    Color.red.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.4),
                                            Color.red.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.red.opacity(0.15), radius: 12, x: 0, y: 4)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
        )
    }
}

struct EnhancedInteractiveBalanceChart: View {
    let data: [ComparisonPeriodData]
    let currency: String
    @ObservedObject var viewModel: FinanceViewModel
    
    @State private var selectedIndex: Int? = nil
    @State private var animatedProgress: CGFloat = 0
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    // Calculate cumulative cash available for each month
    private func getCashAvailableData() -> [(month: Date, value: Double)] {
        let sortedData = data.sorted { $0.month < $1.month }
        var cumulative: Double = 0
        return sortedData.map { point in
            cumulative += point.balance
            return (month: point.month, value: cumulative)
        }
    }
    
    // Calculate net worth for each month (assets + cumulative cash)
    private func getNetWorthData() -> [(month: Date, value: Double)] {
        let sortedData = data.sorted { $0.month < $1.month }
        var cumulative: Double = 0
        return sortedData.map { point in
            cumulative += point.balance
            return (month: point.month, value: totalAssets + cumulative)
        }
    }
    
    // Get total assets value (including goals and targets)
    private var totalAssets: Double {
        let assetsValue = viewModel.assets.reduce(0) { $0 + $1.currentValue }
        let goalsValue = viewModel.goals.reduce(0) { $0 + $1.currentAmount }
        let targetsValue = viewModel.targets.reduce(0) { $0 + $1.currentAmount }
        return assetsValue + goalsValue + targetsValue
    }
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text(AppL10n.t("finance.no_data_available"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 280)
        } else {
            VStack(spacing: 0) {
                // Balance chart content removed - showing empty state
                EmptyView()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) {
                    animatedProgress = 1.0
                }
            }
            .onTapGesture {
                if selectedIndex != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedIndex = nil
                    }
                }
            }
        }
    }
}

// Detail sheet for showing balance information
struct BalanceDetailSheet: View {
    let data: ComparisonPeriodData
    let cashAvailable: Double
    let assets: Double
    let currency: String
    
    @Environment(\.dismiss) var dismiss
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(formatFullDate(data.month))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(AppL10n.t("finance.financial_overview"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    
                    // Balance Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                            Text(AppL10n.t("finance.monthly_balance"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text(formatCurrency(data.balance))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.25),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.4), lineWidth: 1.5)
                            )
                    )
                    
                    // Income and Expenses
                    HStack(spacing: 12) {
                        // Income
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                                Text(AppL10n.t("finance.income"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(data.income))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Expenses
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.3))
                                Text(AppL10n.t("finance.expenses"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(data.expenses))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Cash Available
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                            Text(AppL10n.t("finance.cash_available"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text(formatCurrency(cashAvailable))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                        Text(AppL10n.t("finance.cumulative_balance_up_to"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.2),
                                        Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3), lineWidth: 1.5)
                            )
                    )
                    
                    // Assets
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                            Text(AppL10n.t("finance.total_assets"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text(formatCurrency(assets))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                        Text(AppL10n.t("finance.all_assets_and_goals"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.2),
                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}

struct EnhancedNetWorthChart: View {
    let data: [ComparisonPeriodData]
    let currency: String
    @ObservedObject var viewModel: FinanceViewModel
    
    @State private var selectedIndex: Int? = nil
    @State private var animatedProgress: CGFloat = 0
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    // Get total assets value (including goals and targets)
    private var totalAssets: Double {
        let assetsValue = viewModel.assets.reduce(0) { $0 + $1.currentValue }
        let goalsValue = viewModel.goals.reduce(0) { $0 + $1.currentAmount }
        let targetsValue = viewModel.targets.reduce(0) { $0 + $1.currentAmount }
        return assetsValue + goalsValue + targetsValue
    }
    
    // Calculate net worth for each month (assets + cumulative cash)
    private func getNetWorthData() -> [(month: Date, value: Double)] {
        let sortedData = data.sorted { $0.month < $1.month }
        var cumulative: Double = 0
        return sortedData.map { point in
            cumulative += point.balance
            return (month: point.month, value: totalAssets + cumulative)
        }
    }
    
    // Calculate cumulative income for each month
    private func getIncomeData() -> [(month: Date, value: Double)] {
        let sortedData = data.sorted { $0.month < $1.month }
        var cumulative: Double = 0
        return sortedData.map { point in
            cumulative += point.income
            return (month: point.month, value: cumulative)
        }
    }
    
    // Calculate cumulative expenses for each month
    private func getExpensesData() -> [(month: Date, value: Double)] {
        let sortedData = data.sorted { $0.month < $1.month }
        var cumulative: Double = 0
        return sortedData.map { point in
            cumulative += point.expenses
            return (month: point.month, value: cumulative)
        }
    }
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text(AppL10n.t("finance.no_data_available"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 280)
        } else {
            VStack(spacing: 0) {
                // Two separate info cards with big icons - Always visible, show income/expenses when selected
                let sortedData = data.sorted { $0.month < $1.month }
                let netWorthData = getNetWorthData()
                let displayData: ComparisonPeriodData? = {
                    if let selectedIndex = selectedIndex, selectedIndex < sortedData.count {
                        return sortedData[selectedIndex]
                    }
                    return nil
                }()
                
                // Single Net Worth Card - Full width
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppL10n.t("finance.net_worth"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            if let displayData = displayData {
                                Text("\(AppL10n.t("finance.income_label")) \(formatCurrency(displayData.income)) | \(AppL10n.t("finance.expenses_label")) \(formatCurrency(displayData.expenses))")
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    if let selectedIndex = selectedIndex, selectedIndex < netWorthData.count {
                        Text(formatCurrency(netWorthData[selectedIndex].value))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    } else {
                        let latestNetWorth = netWorthData.last?.value ?? totalAssets
                        Text(formatCurrency(latestNetWorth))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.15),
                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.25),
                                            Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.25)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Premium Line Chart
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let horizontalPadding: CGFloat = 20
                    let chartWidth = width - (horizontalPadding * 2)
                    let chartHeight = height - 35 // Space for month labels
                    
                    let netWorthData = getNetWorthData()
                    let incomeData = getIncomeData()
                    let expensesData = getExpensesData()
                    
                    if netWorthData.isEmpty {
                        EmptyView()
                    } else {
                        // Calculate range including all data to handle negatives properly
                        let allValues = netWorthData.map { $0.value } + incomeData.map { $0.value } + expensesData.map { $0.value }
                        let maxValue = allValues.max() ?? 1
                        let minValue = allValues.min() ?? 0
                        // Add padding to ensure values don't touch borders
                        let padding = max(abs(maxValue - minValue) * 0.1, abs(minValue) * 0.1)
                        let adjustedMin = minValue - padding
                        let adjustedMax = maxValue + padding
                        let range = max(adjustedMax - adjustedMin, 1)
                        
                        ZStack {
                        // Premium grid lines with gradient
                        VStack(spacing: 0) {
                            ForEach(0..<5) { i in
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.02)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                                if i < 4 {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        // Blue gradient fill under income line (reduced opacity)
                        Path { path in
                            for (index, point) in incomeData.enumerated() {
                                let x = CGFloat(index) / CGFloat(max(incomeData.count - 1, 1)) * chartWidth + horizontalPadding
                                let normalizedValue = (point.value - adjustedMin) / range
                                let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: chartHeight))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            if let lastPoint = incomeData.last {
                                let lastIndex = incomeData.count - 1
                                let x = CGFloat(lastIndex) / CGFloat(max(incomeData.count - 1, 1)) * chartWidth + horizontalPadding
                                path.addLine(to: CGPoint(x: x, y: chartHeight))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.2),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.08),
                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(animatedProgress)
                        
                        // Purple gradient fill under expenses line (reduced opacity)
                        Path { path in
                            for (index, point) in expensesData.enumerated() {
                                let x = CGFloat(index) / CGFloat(max(expensesData.count - 1, 1)) * chartWidth + horizontalPadding
                                let normalizedValue = (point.value - adjustedMin) / range
                                let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: chartHeight))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            if let lastPoint = expensesData.last {
                                let lastIndex = expensesData.count - 1
                                let x = CGFloat(lastIndex) / CGFloat(max(expensesData.count - 1, 1)) * chartWidth + horizontalPadding
                                path.addLine(to: CGPoint(x: x, y: chartHeight))
                                path.closeSubpath()
                            }
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.2),
                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.08),
                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(animatedProgress)
                        
                        // Blue income line (reduced glow)
                        Path { path in
                            for (index, point) in incomeData.enumerated() {
                                let x = CGFloat(index) / CGFloat(max(incomeData.count - 1, 1)) * chartWidth + horizontalPadding
                                let normalizedValue = (point.value - adjustedMin) / range
                                let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            Color(red: 0.4, green: 0.49, blue: 0.92),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.2), radius: 3, x: 0, y: 0)
                        
                        // Purple expenses line (reduced glow)
                        Path { path in
                            for (index, point) in expensesData.enumerated() {
                                let x = CGFloat(index) / CGFloat(max(expensesData.count - 1, 1)) * chartWidth + horizontalPadding
                                let normalizedValue = (point.value - adjustedMin) / range
                                let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            Color(red: 0.6, green: 0.4, blue: 0.9),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.2), radius: 3, x: 0, y: 0)
                        
                        // Interactive data points for income line (blue)
                        ForEach(Array(incomeData.enumerated()), id: \.offset) { index, point in
                            let x = CGFloat(index) / CGFloat(max(incomeData.count - 1, 1)) * chartWidth + horizontalPadding
                            let normalizedValue = (point.value - adjustedMin) / range
                            let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                            let isSelected = selectedIndex == index
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedIndex == index {
                                        selectedIndex = nil
                                    } else {
                                        selectedIndex = index
                                    }
                                }
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }) {
                                ZStack {
                                    // Reduced glow effect when selected
                                    if isSelected {
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.3),
                                                        Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.0)
                                                    ],
                                                    center: .center,
                                                    startRadius: 6,
                                                    endRadius: 15
                                                )
                                            )
                                            .frame(width: 30, height: 30)
                                    }
                                    
                                    // Outer glow (reduced)
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(isSelected ? 0.25 : 0.15),
                                                    Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.0)
                                                ],
                                                center: .center,
                                                startRadius: 4,
                                                endRadius: 12
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                    
                                    // Middle ring
                                    Circle()
                                        .fill(Color.white.opacity(isSelected ? 0.3 : 0.2))
                                        .frame(width: isSelected ? 16 : 14, height: isSelected ? 16 : 14)
                                    
                                    // Inner point (blue)
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.49, blue: 0.92))
                                        .frame(width: isSelected ? 10 : 8, height: isSelected ? 10 : 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
                                        )
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .position(x: x, y: y)
                        }
                        
                        // Interactive data points for expenses line (purple)
                        ForEach(Array(expensesData.enumerated()), id: \.offset) { index, point in
                            let x = CGFloat(index) / CGFloat(max(expensesData.count - 1, 1)) * chartWidth + horizontalPadding
                            let normalizedValue = (point.value - adjustedMin) / range
                            let y = chartHeight - (normalizedValue * chartHeight * 0.8) - (chartHeight * 0.1)
                            let isSelected = selectedIndex == index
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedIndex == index {
                                        selectedIndex = nil
                                    } else {
                                        selectedIndex = index
                                    }
                                }
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }) {
                                ZStack {
                                    // Reduced glow effect when selected
                                    if isSelected {
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [
                                                        Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.3),
                                                        Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.0)
                                                    ],
                                                    center: .center,
                                                    startRadius: 6,
                                                    endRadius: 15
                                                )
                                            )
                                            .frame(width: 30, height: 30)
                                    }
                                    
                                    // Outer glow (reduced)
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(isSelected ? 0.25 : 0.15),
                                                    Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.0)
                                                ],
                                                center: .center,
                                                startRadius: 4,
                                                endRadius: 12
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                    
                                    // Middle ring
                                    Circle()
                                        .fill(Color.white.opacity(isSelected ? 0.3 : 0.2))
                                        .frame(width: isSelected ? 16 : 14, height: isSelected ? 16 : 14)
                                    
                                    // Inner point (purple)
                                    Circle()
                                        .fill(Color(red: 0.6, green: 0.4, blue: 0.9))
                                        .frame(width: isSelected ? 10 : 8, height: isSelected ? 10 : 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
                                        )
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .position(x: x, y: y)
                        }
                        
                        // X-axis labels
                        VStack {
                            Spacer()
                            HStack(spacing: 0) {
                                ForEach(Array(incomeData.enumerated()), id: \.offset) { index, point in
                                    Text(formatMonth(point.month))
                                        .font(.system(size: 11, weight: selectedIndex == index ? .semibold : .medium, design: .rounded))
                                        .foregroundColor(selectedIndex == index ? Color(red: 0.4, green: 0.49, blue: 0.92) : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    }
                }
                .frame(height: 200)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) {
                    animatedProgress = 1.0
                }
            }
            .onTapGesture {
                if selectedIndex != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedIndex = nil
                    }
                }
            }
        }
    }
}

// Detail sheet for showing net worth information
struct NetWorthDetailSheet: View {
    let data: MonthlyNetWorth
    let currency: String
    
    @Environment(\.dismiss) var dismiss
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(formatFullDate(data.month))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(AppL10n.t("finance.net_worth_overview"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    
                    // Net Worth Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                            Text(AppL10n.t("finance.total_net_worth"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text(formatCurrency(data.netWorth))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .digit3D(baseColor: .white)
                        Text(AppL10n.t("finance.assets_plus_cash"))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.25),
                                        Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.4), lineWidth: 1.5)
                            )
                    )
                    
                    // Breakdown
                    HStack(spacing: 12) {
                        // Assets
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                Text(AppL10n.t("finance.assets"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(data.assets))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                            Text(AppL10n.t("finance.all_assets_goals"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Cash Available
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                                Text(AppL10n.t("finance.cash"))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Text(formatCurrency(data.cashAvailable))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                            Text(AppL10n.t("finance.cumulative_balance"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}

struct EnhancedIncomeExpenseBarChart: View {
    let data: [ComparisonPeriodData]
    let currency: String
    var isExpanded: Bool = false
    
    @State private var selectedIndex: Int? = nil
    @State private var barAnimationProgress: Double = 0
    @State private var hasAnimated = false
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func formatFullMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppL10n.localeIdentifier(for: AppL10n.currentLanguageCode()))
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        if data.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text(AppL10n.t("finance.no_data_available"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 300)
        } else {
            GeometryReader { geometry in
                let width = geometry.size.width
                let chartHeight: CGFloat = 200
                let infoCardsHeight: CGFloat = 80
                let monthLabelHeight: CGFloat = 35
                let totalHeight = chartHeight + infoCardsHeight + monthLabelHeight
                // Filter out months with no meaningful data (all values are zero or very small)
                let filteredData = data.filter { point in
                    point.income > 0.01 || point.expenses > 0.01 || abs(point.balance) > 0.01
                }
                let maxValue = max(filteredData.map { max($0.income, $0.expenses, abs($0.balance)) }.max() ?? 1, 1)
                let sortedData = filteredData.sorted { $0.month < $1.month }
                let barSpacing: CGFloat = 12
                let horizontalPadding: CGFloat = 16
                let chartWidth = width - (horizontalPadding * 2)
                let totalSpacing = barSpacing * CGFloat(max(0, sortedData.count - 1))
                let availableWidth = chartWidth - totalSpacing
                let barGroupWidth = availableWidth / CGFloat(sortedData.count)
                // Optimized bar width: ensure bars are visible but not too wide, with good separation
                let barWidth = min(barGroupWidth * 0.25, 20)
                // Optimal gap between bars: ensures clear separation while keeping bars centered
                let gapBetweenBars: CGFloat = max(barGroupWidth * 0.06, 4)
                
                VStack(spacing: 0) {
                    // Two separate info cards (like Net Worth and Assets + Cash) - Always visible
                    let displayData: ComparisonPeriodData = {
                        if let selectedIndex = selectedIndex, selectedIndex < sortedData.count {
                            return sortedData[selectedIndex]
                        } else {
                            // Show totals when nothing is selected
                            let totalIncome = sortedData.reduce(0) { $0 + $1.income }
                            let totalExpenses = sortedData.reduce(0) { $0 + $1.expenses }
                            let totalBalance = totalIncome - totalExpenses
                            return ComparisonPeriodData(
                                id: "total",
                                month: sortedData.last?.month ?? Date(),
                                income: totalIncome,
                                expenses: totalExpenses,
                                balance: totalBalance,
                                incomeChange: 0,
                                expensesChange: 0,
                                balanceChange: 0
                            )
                        }
                    }()
                    
                    HStack(spacing: 8) {
                        // Income Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.4))
                                Text(AppL10n.t("finance.income"))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Text(formatCurrency(displayData.income))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.7, blue: 0.4).opacity(0.2),
                                            Color(red: 0.3, green: 0.7, blue: 0.4).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.3, green: 0.7, blue: 0.4).opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Expense Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                                Text(AppL10n.t("finance.expense"))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Text(formatCurrency(displayData.expenses))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.2),
                                            Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Balance Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: displayData.balance >= 0 ? "equal.circle.fill" : "minus.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(displayData.balance >= 0 ? Color(red: 0.4, green: 0.49, blue: 0.92) : Color(red: 0.9, green: 0.5, blue: 0.3))
                                Text(AppL10n.t("finance.balance_label"))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Text(formatCurrency(displayData.balance))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (displayData.balance >= 0 ? Color(red: 0.4, green: 0.49, blue: 0.92) : Color(red: 0.9, green: 0.5, blue: 0.3)).opacity(0.2),
                                            (displayData.balance >= 0 ? Color(red: 0.4, green: 0.49, blue: 0.92) : Color(red: 0.9, green: 0.5, blue: 0.3)).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke((displayData.balance >= 0 ? Color(red: 0.4, green: 0.49, blue: 0.92) : Color(red: 0.9, green: 0.5, blue: 0.3)).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 12)
                    
                    // Chart area: show "No data available" when no bars to display, otherwise show bars
                    if sortedData.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(.white.opacity(0.3))
                            Text(AppL10n.t("finance.no_data_available"))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(height: chartHeight + monthLabelHeight)
                        .frame(maxWidth: .infinity)
                    } else {
                    ZStack(alignment: .bottom) {
                        // Bars - Clean and professional, perfectly centered and separated
                        let totalBarsWidth = barGroupWidth * CGFloat(sortedData.count) + barSpacing * CGFloat(max(0, sortedData.count - 1))
                        
                        // Background grid lines - start from baseline (top of month labels) and extend upward
                        let numberOfGridLines: Int = 5 // Number of horizontal grid lines
                        let lineSpacing = chartHeight / CGFloat(numberOfGridLines - 1)
                        
                        // Grid lines: aligned with bars width, baseline at bottom (top of month labels), extending upward
                        HStack {
                            Spacer()
                            ZStack(alignment: .bottom) {
                                ForEach(0..<numberOfGridLines, id: \.self) { index in
                                    Rectangle()
                                        .fill(index == 0 ? Color.white.opacity(0.1) : Color.white.opacity(0.06))
                                        .frame(width: totalBarsWidth, height: 1)
                                        .offset(y: -CGFloat(index) * lineSpacing)
                                }
                            }
                            .frame(height: chartHeight, alignment: .bottom)
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding)
                        
                        // Calculate the total width of the three bars group (3 bars + 2 gaps)
                        let threeBarsGroupWidth = (barWidth * 3) + (gapBetweenBars * 2)
                        
                        HStack {
                            Spacer()
                            HStack(alignment: .bottom, spacing: barSpacing) {
                            ForEach(Array(sortedData.enumerated()), id: \.element.id) { index, point in
                                VStack(spacing: 0) {
                                    // Bar group container
                                    let isSelected = selectedIndex == index
                                    let hasSelection = selectedIndex != nil
                                    let shouldGreyOut = hasSelection && !isSelected
                                    
                                    // Use HStack to properly separate the three bars horizontally
                                    HStack(alignment: .bottom, spacing: gapBetweenBars) {
                                        // Income bar - Green
                                        let incomeHeight = (point.income / maxValue) * chartHeight * 0.85 * barAnimationProgress
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                shouldGreyOut
                                                    ? Color.white.opacity(0.15)
                                                    : Color(red: 0.3, green: 0.7, blue: 0.4)
                                            )
                                            .frame(width: barWidth, height: max(2, incomeHeight))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        shouldGreyOut
                                                            ? Color.white.opacity(0.08)
                                                            : Color.white.opacity(isSelected ? 0.25 : 0.15),
                                                        lineWidth: isSelected ? 1.5 : 1
                                                    )
                                            )
                                            .shadow(
                                                color: Color.black.opacity(shouldGreyOut ? 0.05 : (isSelected ? 0.15 : 0.1)),
                                                radius: shouldGreyOut ? 2 : (isSelected ? 6 : 4),
                                                x: 0,
                                                y: shouldGreyOut ? 1 : (isSelected ? 2 : 1.5)
                                            )
                                        
                                        // Expense bar - Red
                                        let expenseHeight = (point.expenses / maxValue) * chartHeight * 0.85 * barAnimationProgress
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                shouldGreyOut
                                                    ? Color.white.opacity(0.15)
                                                    : Color(red: 0.9, green: 0.3, blue: 0.3)
                                            )
                                            .frame(width: barWidth, height: max(2, expenseHeight))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        shouldGreyOut
                                                            ? Color.white.opacity(0.08)
                                                            : Color.white.opacity(isSelected ? 0.25 : 0.15),
                                                        lineWidth: isSelected ? 1.5 : 1
                                                    )
                                            )
                                            .shadow(
                                                color: Color.black.opacity(shouldGreyOut ? 0.05 : (isSelected ? 0.15 : 0.1)),
                                                radius: shouldGreyOut ? 2 : (isSelected ? 6 : 4),
                                                x: 0,
                                                y: shouldGreyOut ? 1 : (isSelected ? 2 : 1.5)
                                            )
                                        
                                        // Balance bar - Blue/Orange
                                        let balanceHeight = abs(point.balance) / maxValue * chartHeight * 0.85 * barAnimationProgress
                                        let balanceColor = point.balance >= 0 
                                            ? Color(red: 0.4, green: 0.49, blue: 0.92) 
                                            : Color(red: 0.9, green: 0.5, blue: 0.3)
                                        
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                shouldGreyOut
                                                    ? Color.white.opacity(0.15)
                                                    : balanceColor
                                            )
                                            .frame(width: barWidth, height: max(8, balanceHeight))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        shouldGreyOut
                                                            ? Color.white.opacity(0.08)
                                                            : Color.white.opacity(isSelected ? 0.25 : 0.15),
                                                        lineWidth: isSelected ? 1.5 : 1
                                                    )
                                            )
                                            .shadow(
                                                color: Color.black.opacity(shouldGreyOut ? 0.05 : (isSelected ? 0.15 : 0.1)),
                                                radius: shouldGreyOut ? 2 : (isSelected ? 6 : 4),
                                                x: 0,
                                                y: shouldGreyOut ? 1 : (isSelected ? 2 : 1.5)
                                            )
                                    }
                                    .frame(width: threeBarsGroupWidth)
                                    .frame(width: barGroupWidth, alignment: .center) // Center the three bars within the group
                                    .opacity(shouldGreyOut ? 0.35 : 1.0)
                                    .frame(height: chartHeight, alignment: .bottom)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if selectedIndex == index {
                                                selectedIndex = nil
                                            } else {
                                                selectedIndex = index
                                            }
                                        }
                                    }
                                    
                                    // Selection indicator line - positioned under the center of the three bars
                                    if isSelected {
                                        Rectangle()
                                            .fill(Color(red: 0.4, green: 0.49, blue: 0.92))
                                            .frame(width: threeBarsGroupWidth * 0.9, height: 3)
                                            .cornerRadius(1.5)
                                            .frame(width: barGroupWidth, alignment: .center)
                                            .padding(.top, 4)
                                    }
                                    
                                    // Month label - Positioned below the selection line
                                    Text(formatMonth(point.month))
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                                        .foregroundColor(
                                            isSelected 
                                                ? Color(red: 0.4, green: 0.49, blue: 0.92) 
                                                : (shouldGreyOut ? .white.opacity(0.3) : .white.opacity(0.7))
                                        )
                                        .frame(width: barGroupWidth, alignment: .center)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.top, isSelected ? 4 : 12)
                                }
                            }
                            }
                            .frame(width: totalBarsWidth, height: chartHeight + monthLabelHeight, alignment: .bottom)
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    .frame(height: chartHeight + monthLabelHeight)
                    }
                }
                .frame(width: width, height: totalHeight)
                .clipped()
            }
            .frame(height: 300)
            .onChange(of: isExpanded) { _, newValue in
                if newValue {
                    // Reset first, then animate - ensures bars grow every time section opens
                    barAnimationProgress = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85, blendDuration: 0)) {
                            barAnimationProgress = 1.0
                        }
                    }
                } else {
                    // Reset immediately when section closes (no animation needed)
                    barAnimationProgress = 0
                }
            }
            .onAppear {
                // Animate bars when view first appears if already expanded
                // Only animate once to prevent double updates
                if isExpanded && !hasAnimated && !data.isEmpty {
                    hasAnimated = true
                    barAnimationProgress = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85, blendDuration: 0)) {
                            barAnimationProgress = 1.0
                        }
                    }
                } else if !data.isEmpty {
                    // If data is already loaded, set progress immediately without animation
                    barAnimationProgress = 1.0
                    hasAnimated = true
                }
            }
            .onChange(of: data.count) { oldValue, newValue in
                // Reset animation state when data changes significantly (e.g., new month loaded)
                if oldValue == 0 && newValue > 0 {
                    hasAnimated = false
                    barAnimationProgress = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85, blendDuration: 0)) {
                            barAnimationProgress = 1.0
                            hasAnimated = true
                        }
                    }
                } else if newValue > 0 && !hasAnimated {
                    // Data updated but haven't animated yet
                    barAnimationProgress = 1.0
                    hasAnimated = true
                }
            }
            .onTapGesture {
                if selectedIndex != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedIndex = nil
                    }
                }
            }
        }
    }
}

// Apple Watch-style 3D Donut Chart - Clean and refined
struct DonutChartView3D: View {
    let categories: [CategoryAnalytics]
    var selectedCategory: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 10
            let innerRadius = radius * 0.6
            
            ZStack {
                // Draw segments with Apple Watch-style clean 3D effect
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    let isSelected = selectedCategory == category.name
                    let shouldShowColor = selectedCategory == nil || isSelected
                    let segmentColor = shouldShowColor ? category.color : Color.white.opacity(0.15)
                    
                    // Main segment with smooth radial-style gradient (Apple Watch style)
                    DonutSegmentShape(
                        category: category,
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        center: center,
                        radius: radius,
                        innerRadius: innerRadius
                    )
                    .fill(
                        // Clean gradient from lighter top to darker bottom (Apple Watch style)
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: segmentColor.opacity(1.0), location: 0.0),
                                .init(color: segmentColor.opacity(0.98), location: 0.4),
                                .init(color: segmentColor.opacity(0.92), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Subtle shadow for depth (Apple Watch minimal shadow style)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .shadow(color: segmentColor.opacity(0.1), radius: 1, x: 0, y: 0.5)
                    .animation(.easeInOut(duration: 0.5), value: selectedCategory)
                }
            }
        }
    }
    
    private func startAngle(for index: Int) -> Double {
        var angle: Double = -90 // Start from top
        for i in 0..<index {
            angle += categories[i].percentage * 3.6 // 360 / 100
        }
        return angle
    }
    
    private func endAngle(for index: Int) -> Double {
        var angle: Double = -90
        for i in 0...index {
            angle += categories[i].percentage * 3.6
        }
        return angle
    }
}

#Preview {
    FinanceView()
}