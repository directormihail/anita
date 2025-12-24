//
//  FinanceView.swift
//  ANITA
//
//  Finance page matching webapp design
//

import SwiftUI

struct FinanceView: View {
    @State private var totalBalance: Double = 0.0
    @State private var monthlyIncome: Double = 0.0
    @State private var monthlyExpenses: Double = 0.0
    @State private var transactions: [TransactionItem] = []
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
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
                        
                        Text(formatCurrency(totalBalance))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 32) {
                            VStack(spacing: 4) {
                                Text("Income")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(formatCurrency(monthlyIncome))
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            Divider()
                                .frame(height: 30)
                                .background(Color(white: 0.2))
                            
                            VStack(spacing: 4) {
                                Text("Expenses")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(formatCurrency(monthlyExpenses))
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(white: 0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // Transactions Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                // Add transaction
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if transactions.isEmpty {
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
                                ForEach(transactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                            }
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct TransactionItem: Identifiable {
    let id: String
    let type: String // "income" or "expense"
    let amount: Double
    let category: String
    let description: String
    let date: Date
}

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
                    
                    Text(transaction.date, style: .date)
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
                .background(Color(white: 0.2))
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
}

#Preview {
    FinanceView()
}

