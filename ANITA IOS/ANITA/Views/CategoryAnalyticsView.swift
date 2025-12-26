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
                        
                        Text("Category Analysis")
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
                                
                                Text("CATEGORIES")
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
                            
                            Text("No category data available")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Add transactions to see category analysis")
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
                Text("Category Analysis")
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
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 20
            let innerRadius = radius * 0.6
            
            ZStack {
                // Draw segments
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    DonutSegment(
                        category: category,
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        center: center,
                        radius: radius,
                        innerRadius: innerRadius
                    )
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

struct DonutSegment: View {
    let category: CategoryAnalytics
    let startAngle: Double
    let endAngle: Double
    let center: CGPoint
    let radius: CGFloat
    let innerRadius: CGFloat
    
    var body: some View {
        Path { path in
            let startRad = startAngle * .pi / 180
            let endRad = endAngle * .pi / 180
            
            // Outer arc
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .radians(startRad),
                endAngle: .radians(endRad),
                clockwise: false
            )
            
            // Line to inner arc
            let innerStartX = center.x + cos(startRad) * innerRadius
            let innerStartY = center.y + sin(startRad) * innerRadius
            path.addLine(to: CGPoint(x: innerStartX, y: innerStartY))
            
            // Inner arc (reverse)
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: .radians(endRad),
                endAngle: .radians(startRad),
                clockwise: true
            )
            
            // Close path
            path.closeSubpath()
        }
        .fill(category.color)
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
            Text(category.name)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "€0.00"
    }
}

#Preview {
    CategoryAnalyticsView()
}

