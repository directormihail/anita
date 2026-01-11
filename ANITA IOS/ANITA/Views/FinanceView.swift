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

struct FinanceView: View {
    @StateObject private var viewModel = FinanceViewModel()
    @StateObject private var categoryViewModel = CategoryAnalyticsViewModel()
    @State private var isSpendingLimitsExpanded = false
    @State private var isSavingGoalsExpanded = false
    @State private var isCategoryAnalysisExpanded = false
    @State private var isAssetsExpanded = false
    @State private var selectedCategory: String? = nil
    @State private var showAddAssetSheet = false
    @State private var showMonthPicker = false
    @State private var tempSelectedMonth: Date = Date()
    
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
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // Month Picker - Premium iOS Design
                        HStack {
                            Button(action: {
                                let calendar = Calendar.current
                                if let previousMonth = calendar.date(byAdding: .month, value: -1, to: viewModel.selectedMonth) {
                                    viewModel.changeMonth(to: previousMonth)
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                                    .background {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
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
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("Tap to change")
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
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
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                                    .background {
                                        Circle()
                                            .fill(Color.white.opacity(0.1))
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
                        .padding(.top, 8)
                        
                        // Balance Card - Premium iOS Design
                        VStack(spacing: 28) {
                            VStack(spacing: 12) {
                                Text("Total Balance")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                                
                                Text(formatCurrency(viewModel.totalBalance))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
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
                                    .shadow(color: Color.white.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            
                            HStack(spacing: 48) {
                                VStack(spacing: 8) {
                                    Text("Income")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .textCase(.uppercase)
                                        .tracking(0.8)
                                    Text(formatCurrency(viewModel.monthlyIncome))
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.green.opacity(0.98),
                                                    Color.green.opacity(0.85)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 1, height: 44)
                                
                                VStack(spacing: 8) {
                                    Text("Expenses")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .textCase(.uppercase)
                                        .tracking(0.8)
                                    Text(formatCurrency(viewModel.monthlyExpenses))
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.red.opacity(0.98),
                                                    Color.red.opacity(0.85)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 32)
                        .liquidGlass(cornerRadius: 24)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Category Analysis Section
                        VStack(alignment: .leading, spacing: 14) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)) {
                                    isCategoryAnalysisExpanded.toggle()
                                    if isCategoryAnalysisExpanded && categoryViewModel.categoryData == nil {
                                        categoryViewModel.loadData()
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
                                    
                                    Text("Category Analysis")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .rotationEffect(.degrees(isCategoryAnalysisExpanded ? 90 : 0))
                                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCategoryAnalysisExpanded)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            if isCategoryAnalysisExpanded {
                                if categoryViewModel.isLoading {
                                    ProgressView()
                                        .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .liquidGlass(cornerRadius: 14)
                                        .padding(.horizontal, 20)
                                        .transition(.expandSection)
                                } else if let data = categoryViewModel.categoryData {
                                    VStack(spacing: 20) {
                                        // Perfect Donut Chart - iOS style with smooth rendering
                                        GeometryReader { geometry in
                                            let chartSize = min(geometry.size.width, geometry.size.height)
                                            let radius = chartSize / 2 - 10
                                            let innerRadius = radius * 0.6
                                            let innerCircleDiameter = innerRadius * 2
                                            
                                            ZStack {
                                                DonutChartView(categories: data.categories, selectedCategory: selectedCategory)
                                                    .drawingGroup() // Ensures smooth rendering
                                                
                                                // Center text - shows selected category or total count, constrained to inner circle
                                                VStack(spacing: 6) {
                                                    if let selectedCategory = selectedCategory,
                                                       let category = data.categories.first(where: { $0.name == selectedCategory }) {
                                                        Text(String(format: "%.1f%%", category.percentage))
                                                            .font(.system(size: min(36, innerCircleDiameter * 0.3), weight: .bold, design: .rounded))
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
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.5)
                                                        
                                                        Text(category.name.uppercased())
                                                            .font(.system(size: min(10, innerCircleDiameter * 0.08), weight: .semibold, design: .rounded))
                                                            .foregroundColor(.white.opacity(0.5))
                                                            .tracking(0.8)
                                                            .textCase(.uppercase)
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.6)
                                                    } else {
                                                        Text("\(data.categoryCount)")
                                                            .font(.system(size: min(36, innerCircleDiameter * 0.3), weight: .bold, design: .rounded))
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
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.5)
                                                        
                                                        Text("CATEGORIES")
                                                            .font(.system(size: min(10, innerCircleDiameter * 0.08), weight: .semibold, design: .rounded))
                                                            .foregroundColor(.white.opacity(0.5))
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
                                        .frame(height: 220)
                                        .padding(.vertical, 24)
                                        .opacity(isCategoryAnalysisExpanded ? 1 : 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: isCategoryAnalysisExpanded)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategory)
                                        
                                        // Category List with scrollable behavior
                                        if !data.categories.isEmpty {
                                            let rowHeight: CGFloat = 68 // Clean iOS spacing (14px padding top/bottom + 40px content)
                                            let dividerHeight: CGFloat = 1
                                            let maxVisibleRows: CGFloat = 3.5
                                            let itemCount = CGFloat(data.categories.count)
                                            let calculatedHeight: CGFloat = {
                                                if itemCount <= maxVisibleRows {
                                                    let fullRows = floor(itemCount)
                                                    let partialRow = itemCount - fullRows
                                                    let dividers = max(0, fullRows - 1)
                                                    return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                                                } else {
                                                    return 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                                                }
                                            }()
                                            
                                            ScrollView {
                                                VStack(spacing: 8) {
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
                                                                isSelected: selectedCategory == category.name
                                                            )
                                                        }
                                                        .buttonStyle(PlainButtonStyle())
                                                        .opacity(isCategoryAnalysisExpanded ? 1 : 0)
                                                        .animation(
                                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                                .delay(Double(index) * 0.025),
                                                            value: isCategoryAnalysisExpanded
                                                        )
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                            }
                                            .frame(height: calculatedHeight)
                                            .clipped()
                                        }
                                    }
                                    .liquidGlass(cornerRadius: 18)
                                    .padding(.horizontal, 20)
                                    .transition(.expandSection)
                                } else {
                                    VStack(spacing: 8) {
                                        Text("No category data available")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 36)
                                    .liquidGlass(cornerRadius: 18)
                                    .padding(.horizontal, 20)
                                    .transition(.expandSection)
                                }
                            }
                        }
                        
                        // Spending Limits Section
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
                                    
                                    Text("Spending Limits")
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
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            if isSpendingLimitsExpanded {
                                if viewModel.goals.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("No spending limits set")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
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
                                    let itemCount = CGFloat(viewModel.goals.count)
                                    let calculatedHeight: CGFloat = {
                                        if itemCount <= maxVisibleRows {
                                            // Show all items with dividers
                                            let fullRows = floor(itemCount)
                                            let partialRow = itemCount - fullRows
                                            let dividers = max(0, fullRows - 1)
                                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                                        } else {
                                            // Show exactly 3.5 rows (3 full + 0.5 partial = 297.5px + 2px dividers)
                                            // This ensures the 4th row is only partially visible
                                            return 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                                        }
                                    }()
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            ForEach(Array(viewModel.goals.enumerated()), id: \.element.id) { index, goal in
                                                GoalRow(goal: goal, viewModel: viewModel)
                                                    .opacity(isSpendingLimitsExpanded ? 1 : 0)
                                                    .animation(
                                                        .spring(response: 0.4, dampingFraction: 0.8)
                                                            .delay(Double(index) * 0.025),
                                                        value: isSpendingLimitsExpanded
                                                    )
                                                
                                                if index < viewModel.goals.count - 1 {
                                                    PremiumDivider()
                                                        .padding(.leading, 76)
                                                        .opacity(isSpendingLimitsExpanded ? 1 : 0)
                                                        .animation(
                                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                                .delay(Double(index) * 0.025 + 0.01),
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
                        
                        // Saving Goals Section
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
                                    
                                    Text("Saving Goals")
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
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            if isSavingGoalsExpanded {
                                if viewModel.targets.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("No saving goals set")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
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
                                    let itemCount = CGFloat(viewModel.targets.count)
                                    let calculatedHeight: CGFloat = {
                                        if itemCount <= maxVisibleRows {
                                            // Show all items with dividers
                                            let fullRows = floor(itemCount)
                                            let partialRow = itemCount - fullRows
                                            let dividers = max(0, fullRows - 1)
                                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                                        } else {
                                            // Show exactly 3.5 rows (3 full + 0.5 partial = 297.5px + 2px dividers)
                                            // This ensures the 4th row is only partially visible
                                            return 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                                        }
                                    }()
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            ForEach(Array(viewModel.targets.enumerated()), id: \.element.id) { index, target in
                                                TargetRow(target: target, viewModel: viewModel)
                                                    .opacity(isSavingGoalsExpanded ? 1 : 0)
                                                    .animation(
                                                        .spring(response: 0.4, dampingFraction: 0.8)
                                                            .delay(Double(index) * 0.025),
                                                        value: isSavingGoalsExpanded
                                                    )
                                                
                                                if index < viewModel.targets.count - 1 {
                                                    PremiumDivider()
                                                        .padding(.leading, 76)
                                                        .opacity(isSavingGoalsExpanded ? 1 : 0)
                                                        .animation(
                                                            .spring(response: 0.4, dampingFraction: 0.8)
                                                                .delay(Double(index) * 0.025 + 0.01),
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
                        
                        // Assets Section
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
                                    
                                    Text("Assets")
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
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(PremiumSettingsButtonStyle())
                            
                            if isAssetsExpanded {
                                // Total Assets Summary (shown when expanded)
                                if !comprehensiveAssets.isEmpty {
                                    HStack {
                                        Text("TOTAL ASSETS")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.4))
                                            .tracking(0.8)
                                        
                                        Spacer()
                                        
                                        Text(formatCurrency(totalAssetsValue))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 18)
                                    .liquidGlass(cornerRadius: 18)
                                    .padding(.horizontal, 20)
                                    .transition(.expandSection)
                                }
                                
                                if comprehensiveAssets.isEmpty {
                                    // Empty state with Add Asset button
                                    Button(action: {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        showAddAssetSheet = true
                                    }) {
                                        VStack(spacing: 16) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 48, weight: .light))
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.8),
                                                            Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.6)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                            
                                            Text("No assets tracked")
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.5))
                                            
                                            Text("Tap to add your first asset")
                                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 36)
                                    }
                                    .buttonStyle(PremiumSettingsButtonStyle())
                                    .liquidGlass(cornerRadius: 18)
                                    .padding(.horizontal, 20)
                                    .transition(.expandSection)
                                } else {
                                    // Row height: ~85px (28px vertical padding + ~57px content height)
                                    let rowHeight: CGFloat = 85
                                    let dividerHeight: CGFloat = 1
                                    let maxVisibleRows: CGFloat = 3.5
                                    let itemCount = CGFloat(comprehensiveAssets.count)
                                    let calculatedHeight: CGFloat = {
                                        if itemCount <= maxVisibleRows {
                                            // Show all items with dividers
                                            let fullRows = floor(itemCount)
                                            let partialRow = itemCount - fullRows
                                            let dividers = max(0, fullRows - 1)
                                            return fullRows * rowHeight + partialRow * rowHeight + CGFloat(dividers) * dividerHeight
                                        } else {
                                            // Show exactly 3.5 rows (3 full + 0.5 partial = 297.5px + 2px dividers)
                                            // This ensures the 4th row is only partially visible
                                            return 3 * rowHeight + 0.5 * rowHeight + 2 * dividerHeight
                                        }
                                    }()
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            // Add Asset button as first item in the list (matching AssetRow design)
                                            Button(action: {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                                showAddAssetSheet = true
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
                                                        Text("Add Asset")
                                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                                            .foregroundColor(.white.opacity(0.95))
                                                        
                                                        HStack(spacing: 6) {
                                                            Text("NEW")
                                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                                .foregroundColor(.white.opacity(0.5))
                                                                .tracking(0.3)
                                                        }
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
                        
                        // XP Level Widget
                        if let xpStats = viewModel.xpStats {
                            XPLevelWidget(xpStats: xpStats)
                                .padding(.horizontal, 20)
                        }
                        
                        // Transactions Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Transactions")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
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
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Implement add transaction
                                    // This could open a sheet or navigate to add transaction view
                                }) {
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
                                        
                                        Image(systemName: "plus")
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
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    .padding()
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .liquidGlass(cornerRadius: 18)
                                    .padding(.horizontal, 20)
                            } else if viewModel.transactions.isEmpty {
                                VStack(spacing: 16) {
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
                                    
                                    Text("No transactions yet")
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text("Add your first transaction to start tracking")
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 52)
                                .frame(height: 200)
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            } else {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(viewModel.transactions) { transaction in
                                            TransactionRow(transaction: transaction)
                                        }
                                    }
                                }
                                .frame(height: 400)
                                .liquidGlass(cornerRadius: 18)
                                .padding(.horizontal, 20)
                            }
                            
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                .background(Color.black)
                .navigationBarHidden(true)
            }
            .background(Color.black)
        }
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            Task { @MainActor in
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showAddAssetSheet) {
            AddAssetSheet(viewModel: viewModel)
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
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// TransactionItem is now defined in Models.swift

struct TransactionRow: View {
    let transaction: TransactionItem
    
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
                                (transaction.type == "income" 
                                    ? Color.green.opacity(0.95)
                                    : Color.red.opacity(0.95)),
                                (transaction.type == "income" 
                                    ? Color.green.opacity(0.8)
                                    : Color.red.opacity(0.8))
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
                
                HStack(spacing: 6) {
                    Text(transaction.category.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.3)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    
                    Text(formatDate(transaction.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatAmount(transaction.amount))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            (transaction.type == "income" 
                                ? Color.green.opacity(0.95)
                                : Color.red.opacity(0.95)),
                            (transaction.type == "income" 
                                ? Color.green.opacity(0.8)
                                : Color.red.opacity(0.8))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
        
        if transaction.id != "last" {
            PremiumDivider()
                .padding(.leading, 82)
        }
    }
    
    private func categoryIcon(_ category: String) -> String {
        let lowercased = category.lowercased()
        if lowercased.contains("food") || lowercased.contains("restaurant") {
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
        } else {
            return "dollarsign.circle.fill"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
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

struct TargetRow: View {
    let target: Target
    @State private var showEditGoalSheet = false
    @ObservedObject var viewModel: FinanceViewModel
    
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
                        .foregroundColor(isCompleted ? Color.green.opacity(0.9) : .white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    
                    Text(formatCurrency(target.currentAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("of")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatCurrency(target.targetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
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
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Amount to Goal")
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
                        
                        // Row 4: ., 0, ⌫
                        HStack(spacing: 16) {
                            CalculatorButton(number: ".", action: { appendDecimal() })
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
                                Text("Add")
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
                    Button("Done") {
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
        // Check if decimal separator already exists
        // Store internally as "." for Double parsing, but display will use correct separator
        if !amount.contains(".") && !amount.contains(",") {
            // Always use "." internally for parsing, formatter will display correctly
            amount += "."
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
        
        // Parse the amount value
        if let value = Double(amount) {
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
    
    private func addMoneyToGoal() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isAdding = true
        errorMessage = nil
        
        Task {
            do {
                let userId = viewModel.userId
                let newCurrentAmount = target.currentAmount + amountValue
                
                print("[AddMoneyToGoalSheet] Adding \(amountValue) to goal \(target.id). New amount: \(newCurrentAmount)")
                
                // Update target's currentAmount
                let updatedTarget = try await NetworkService.shared.updateTarget(
                    userId: userId,
                    targetId: target.id,
                    currentAmount: newCurrentAmount
                )
                
                print("[AddMoneyToGoalSheet] Successfully updated goal. New current amount: \(updatedTarget.target.currentAmount)")
                
                await MainActor.run {
                    isAdding = false
                    dismiss()
                    // Refresh the goals list
                    viewModel.refresh()
                }
            } catch {
                print("[AddMoneyToGoalSheet] Error updating goal: \(error.localizedDescription)")
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
                        Text("Change Amount")
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
                        
                        // Row 4: ., 0, ⌫
                        HStack(spacing: 16) {
                            CalculatorButton(number: ".", action: { appendDecimal() })
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
                                Text("Save")
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
                    Button("Done") {
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
        // Check if decimal separator already exists
        if !amount.contains(".") && !amount.contains(",") {
            // Always use "." internally for parsing, formatter will display correctly
            amount += "."
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
        
        // Parse the amount value
        if let value = Double(amount) {
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
        guard let amountValue = Double(amount), amountValue > 0 else {
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
                        Text("Edit Goal")
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
                                    
                                    Text("Add Money")
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
                                    
                                    Text("Take Money")
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
                                    
                                    Text("Change Amount")
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
                                
                                Text("Remove")
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
                    Button("Done") {
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
                        Text("Edit Asset")
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
                                Text("Add Value")
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
                                Text("Reduce Value")
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
                                Text("Remove Asset")
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
                    Button("Done") {
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Take Amount from Goal")
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
                            CalculatorButton(number: ".", action: { appendDecimal() })
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
                                Text("Take")
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
                    Button("Done") {
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
            amount += "."
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
        
        if let value = Double(amount) {
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
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        if amountValue > target.currentAmount {
            errorMessage = "Cannot take more than current amount"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let userId = viewModel.userId
                let newCurrentAmount = target.currentAmount - amountValue
                
                print("[TakeMoneyFromGoalSheet] Taking \(amountValue) from goal \(target.id). New amount: \(newCurrentAmount)")
                
                // Update target's currentAmount
                let updatedTarget = try await NetworkService.shared.updateTarget(
                    userId: userId,
                    targetId: target.id,
                    currentAmount: newCurrentAmount
                )
                
                print("[TakeMoneyFromGoalSheet] Successfully updated goal. New current amount: \(updatedTarget.target.currentAmount)")
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    // Refresh the goals list
                    viewModel.refresh()
                }
            } catch {
                print("[TakeMoneyFromGoalSheet] Error updating goal: \(error.localizedDescription)")
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
                        Text("Remove Goal")
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
                        
                        Text("Are you sure you want to remove this goal?")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("This action cannot be undone.")
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
                                    Text("Remove Goal")
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
                                Text("Cancel")
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
                    Button("Done") {
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
                        Text("Remove Budget")
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
                        
                        Text("Are you sure you want to remove this budget?")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("This action cannot be undone.")
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
                                    Text("Remove Budget")
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
                                Text("Cancel")
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
                    Button("Done") {
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Value to Asset")
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
                            CalculatorButton(number: ".", action: { appendDecimal() })
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
                                Text("Add")
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
                    Button("Done") {
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
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        if !amount.contains(".") && !amount.contains(",") {
            amount += "."
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Reduce Asset Value")
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
                            CalculatorButton(number: ".", action: { appendDecimal() })
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
                                Text("Reduce")
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
                    Button("Done") {
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
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let locale = getLocaleForCurrency(userCurrency)
        if !amount.contains(".") && !amount.contains(",") {
            amount += "."
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
                        Text("Remove Asset")
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
                        
                        Text("Are you sure you want to remove this asset?")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("This action cannot be undone.")
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
                                    Text("Remove Asset")
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
                                Text("Cancel")
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
                    Button("Done") {
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
    
    init(goal: Target, viewModel: FinanceViewModel) {
        self.goal = goal
        self.viewModel = viewModel
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
                    Text("\(Int(goal.progressPercentage))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 11))
                    
                    Text(formatCurrency(goal.currentAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("of")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(formatCurrency(goal.targetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Progress bar (red)
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
                            .frame(width: geometry.size.width * CGFloat(goal.progressPercentage / 100), height: 5)
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
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct AssetRow: View {
    let asset: Asset
    let isVirtualAsset: Bool
    @ObservedObject var viewModel: FinanceViewModel
    @State private var showEditAssetSheet = false
    
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
                    Text(asset.type.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.3)
                    
                    if isVirtualAsset {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 11))
                        
                        Text("AUTO")
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
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
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct XPLevelWidget: View {
    let xpStats: XPStats
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with level info
            HStack {
                // Level emoji and number
                HStack(spacing: 16) {
                    Text(xpStats.level_emoji)
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Level \(xpStats.current_level)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
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
                        
                        Text(xpStats.level_title)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Total XP
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(xpStats.total_xp)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
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
                    
                    Text("XP")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(xpStats.xp_to_next_level) XP to next level")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    Text("\(xpStats.level_progress_percentage)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 10)
                            .cornerRadius(5)
                        
                        // Progress fill
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
                                height: 10
                            )
                            .cornerRadius(5)
                            .shadow(color: Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .liquidGlass(cornerRadius: 20)
    }
}

// Clean iOS-style CategoryRow for FinanceView
struct FinanceCategoryRow: View {
    let category: CategoryAnalytics
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Premium glass circle with category color
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(isSelected ? 0.5 : 0.3),
                                Color(white: 0.15).opacity(isSelected ? 0.4 : 0.2)
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
                                        Color.white.opacity(isSelected ? 0.4 : 0.2),
                                        Color.white.opacity(isSelected ? 0.3 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .shadow(color: isSelected ? category.color.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                Circle()
                    .fill(category.color)
                    .frame(width: 32, height: 32)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            
            // Category details
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.95))
                    .lineLimit(1)
                
                Text(String(format: "%.1f%%", category.percentage))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.white.opacity(isSelected ? 0.8 : 0.5))
            }
            
            Spacer()
            
            // Amount
            Text(formatCurrency(category.amount))
                .font(.system(size: 17, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isSelected ? 1.0 : 0.98),
                            Color.white.opacity(isSelected ? 0.95 : 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Group {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.15),
                                    category.color.opacity(0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            category.color.opacity(0.4),
                                            category.color.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: category.color.opacity(0.2), radius: 8, x: 0, y: 2)
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.08),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        )
        .contentShape(Capsule())
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
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
                            Text("Add Asset")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Asset Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Asset Name")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            TextField("e.g., Savings Account", text: $assetName)
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
                            Text("Asset Type")
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
                            Text("Current Value")
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
                            Text("Description (Optional)")
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
                                    Text("Add Asset")
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
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
        
        guard let value = Double(currentValue), value >= 0 else {
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
                        Text("Select Month")
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
                            Text("Cancel")
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
                            Text("Done")
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
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func monthName(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: month, day: 1))!
        return formatter.string(from: date)
    }
}

#Preview {
    FinanceView()
}

