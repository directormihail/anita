//
//  FinanceView.swift
//  ANITA
//
//  Finance page matching webapp design
//

import SwiftUI

struct FinanceView: View {
    @StateObject private var viewModel = FinanceViewModel()
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Finance Overview")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }
                    
                        // Balance Card
                        VStack(spacing: 16) {
                            Text("Total Balance")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(formatCurrency(viewModel.totalBalance))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 32) {
                                VStack(spacing: 4) {
                                    Text("Income")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(formatCurrency(viewModel.monthlyIncome))
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                                
                            Divider()
                                .frame(height: 30)
                                .background(Color.white.opacity(0.1))
                                
                                VStack(spacing: 4) {
                                    Text("Expenses")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(formatCurrency(viewModel.monthlyExpenses))
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal, 20)
                        
                        // Category Analytics Button
                        NavigationLink(destination: CategoryAnalyticsView()) {
                            HStack {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                
                                Text("Category Analysis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .liquidGlass(cornerRadius: 12)
                            .padding(.horizontal, 20)
                        }
                        
                        // Targets Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Targets")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            if viewModel.targets.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No targets set")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.targets.prefix(3)) { target in
                                        TargetRow(target: target)
                                        
                                        if target.id != viewModel.targets.prefix(3).last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Assets Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Assets")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            if viewModel.assets.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No assets tracked")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.assets.prefix(3)) { asset in
                                        AssetRow(asset: asset)
                                        
                                        if asset.id != viewModel.assets.prefix(3).last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.leading, 76)
                                        }
                                    }
                                }
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
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
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Implement add transaction
                                    // This could open a sheet or navigate to add transaction view
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    .padding()
                            } else if viewModel.transactions.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    
                                    Text("No transactions yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Add your first transaction to start tracking")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.transactions) { transaction in
                                        TransactionRow(transaction: transaction)
                                    }
                                }
                                .liquidGlass(cornerRadius: 12)
                                .padding(.horizontal, 20)
                            }
                            
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 100)
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
            viewModel.refresh()
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// TransactionItem is now defined in Models.swift

struct TransactionRow: View {
    let transaction: TransactionItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            Circle()
                .fill(
                    transaction.type == "income" 
                        ? Color.green.opacity(0.2)
                        : Color.red.opacity(0.2)
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: categoryIcon(transaction.category))
                        .font(.system(size: 18))
                        .foregroundColor(
                            transaction.type == "income" 
                                ? .green
                                : .red
                        )
                )
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(transaction.category)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(formatDate(transaction.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Amount
            Text(formatAmount(transaction.amount))
                .font(.headline)
                .foregroundColor(
                    transaction.type == "income" 
                        ? .green
                        : .red
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        
        if transaction.id != "last" {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 76)
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
        let sign = transaction.type == "income" ? "+" : "-"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
        return "\(sign)\(formatted)"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct TargetRow: View {
    let target: Target
    
    var body: some View {
        HStack(spacing: 16) {
            // Target icon
            Circle()
                .fill(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "target")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                )
            
            // Target details
            VStack(alignment: .leading, spacing: 4) {
                Text(target.title)
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(Int(target.progressPercentage))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(formatCurrency(target.currentAmount))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("of")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatCurrency(target.targetAmount))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .frame(width: geometry.size.width * CGFloat(target.progressPercentage / 100), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = target.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "€0"
    }
}

struct AssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: 16) {
            // Asset icon
            Circle()
                .fill(assetTypeColor(asset.type).opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: assetTypeIcon(asset.type))
                        .font(.system(size: 18))
                        .foregroundColor(assetTypeColor(asset.type))
                )
            
            // Asset details
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.body)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(asset.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Value
            Text(formatCurrency(asset.currentValue))
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private func assetTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "savings":
            return "banknote.fill"
        case "investment":
            return "chart.line.uptrend.xyaxis"
        case "property":
            return "house.fill"
        case "vehicle":
            return "car.fill"
        case "cash":
            return "dollarsign.circle.fill"
        default:
            return "wallet.pass.fill"
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = asset.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "€0"
    }
}

struct XPLevelWidget: View {
    let xpStats: XPStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with level info
            HStack {
                // Level emoji and number
                HStack(spacing: 12) {
                    Text(xpStats.level_emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level \(xpStats.current_level)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(xpStats.level_title)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Total XP
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(xpStats.total_xp)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("XP")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(xpStats.xp_to_next_level) XP to next level")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(xpStats.level_progress_percentage)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
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
                                height: 8
                            )
                            .cornerRadius(4)
                            .shadow(color: Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 16)
    }
}

#Preview {
    FinanceView()
}

