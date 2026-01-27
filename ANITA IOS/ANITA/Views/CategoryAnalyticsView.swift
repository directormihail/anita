//
//  CategoryAnalyticsView.swift
//  ANITA
//
//  Category Analysis view with donut chart and category list
//

import SwiftUI

struct CategoryAnalyticsView: View {
    @StateObject private var viewModel = CategoryAnalyticsViewModel()
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        Text(AppL10n.t("finance.category_analysis"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .padding()
                    } else if let data = viewModel.categoryData {
                        // Donut Chart
                        ZStack {
                            DonutChartView(categories: data.categories)
                                .frame(height: 280)
                                .padding(.horizontal, 20)
                            
                            // Center text
                            VStack(spacing: 4) {
                                Text("\(data.categoryCount)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(AppL10n.t("finance.categories"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // Category List
                        VStack(spacing: 0) {
                            ForEach(data.categories) { category in
                                CategoryRow(category: category)
                                
                                if category.id != data.categories.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 76)
                                }
                            }
                        }
                        .liquidGlass(cornerRadius: 12)
                        .padding(.horizontal, 20)
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text(AppL10n.t("finance.no_category_data"))
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text(AppL10n.t("finance.add_transactions_for_analysis"))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(AppL10n.t("finance.category_analysis"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.refresh()
        }
    }
}

struct DonutChartView: View {
    let categories: [CategoryAnalytics]
    var selectedCategory: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 10
            let innerRadius = radius * 0.6
            
            ZStack {
                // Draw segments with perfect rendering
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    let isSelected = selectedCategory == category.name
                    // Show original color if no selection OR if this category is selected
                    // Show grey if a selection exists AND this is not the selected one
                    let shouldShowColor = selectedCategory == nil || isSelected
                    let segmentColor = shouldShowColor ? category.color : Color.white.opacity(0.15)
                    
                    DonutSegmentShape(
                        category: category,
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        center: center,
                        radius: radius,
                        innerRadius: innerRadius
                    )
                    .fill(segmentColor)
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

// Perfect donut segment using Shape protocol for smooth rendering
struct DonutSegmentShape: Shape {
    let category: CategoryAnalytics
    let startAngle: Double
    let endAngle: Double
    let center: CGPoint
    let radius: CGFloat
    let innerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let startRad = startAngle * .pi / 180
        let endRad = endAngle * .pi / 180
        
        // Calculate start point for outer arc
        let outerStartX = center.x + cos(startRad) * radius
        let outerStartY = center.y + sin(startRad) * radius
        
        // Calculate end point for inner arc
        let innerEndX = center.x + cos(endRad) * innerRadius
        let innerEndY = center.y + sin(endRad) * innerRadius
        
        // Start from outer start point
        path.move(to: CGPoint(x: outerStartX, y: outerStartY))
        
        // Draw outer arc (perfectly smooth)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(radians: startRad),
            endAngle: Angle(radians: endRad),
            clockwise: false
        )
        
        // Line to inner arc end point
        path.addLine(to: CGPoint(x: innerEndX, y: innerEndY))
        
        // Draw inner arc (reverse direction, perfectly smooth)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: endRad),
            endAngle: Angle(radians: startRad),
            clockwise: true
        )
        
        // Close path back to start
        path.closeSubpath()
        
        return path
    }
}

struct CategoryRow: View {
    let category: CategoryAnalytics
    
    var body: some View {
        HStack(spacing: 16) {
            // Colored circle
            Circle()
                .fill(category.color)
                .frame(width: 44, height: 44)
            
            // Category name
            Text(CategoryDefinitions.shared.getTranslatedCategoryName(category.name))
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            // Amount
            Text(formatCurrency(category.amount))
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let currency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    CategoryAnalyticsView()
}

