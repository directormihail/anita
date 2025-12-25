//
//  SidebarMenu.swift
//  ANITA
//
//  Sidebar menu matching the mobile design
//

import SwiftUI

struct SidebarMenu: View {
    @Binding var isPresented: Bool
    @State private var balance: Double = 570.06
    @State private var income: Double = 1600.00
    @State private var expense: Double = 1029.94
    @State private var xp: Int = 254
    @State private var xpToNextLevel: Int = 196
    @State private var level: Int = 3
    @State private var levelTitle: String = "BUDGET APPRENTICE"
    @State private var conversations: [ConversationItem] = [
        ConversationItem(title: "Friendly Check-In Chat", date: Date(), isToday: true),
        ConversationItem(title: "Show my analytics", date: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(), isToday: false),
        ConversationItem(title: "Show my analytics", date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), isToday: false),
        ConversationItem(title: "Show my analytics", date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), isToday: false),
        ConversationItem(title: "Food Expense Budgeting", date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(), isToday: false),
        ConversationItem(title: "Show my analytics", date: Date(timeIntervalSince1970: 1734480000), isToday: false) // 12/17/2025
    ]
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top header with close button
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Ultimate Plan section
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yellow)
                                
                                Text("Ultimate Plan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                // Upgrade action
                            }) {
                                Text("Upgrade")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Financial Overview Cards
                        VStack(spacing: 12) {
                            // Balance Card
                            FinancialCard(
                                icon: "dollarsign.circle.fill",
                                title: "Balance",
                                value: balance,
                                isPositive: true,
                                showSign: false
                            )
                            
                            // Income Card
                            FinancialCard(
                                icon: "arrow.up.circle.fill",
                                title: "Income",
                                value: income,
                                isPositive: true,
                                showSign: true
                            )
                            
                            // Expense Card
                            FinancialCard(
                                icon: "dollarsign.circle.fill",
                                title: "Expense",
                                value: expense,
                                isPositive: false,
                                showSign: true
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // Progress/XP Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                    
                                    Text("\(xp) XP")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    // Info action
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(white: 0.2))
                                        .frame(height: 4)
                                    
                                    // Progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(
                                            width: geometry.size.width * progressPercentage,
                                            height: 4
                                        )
                                }
                            }
                            .frame(height: 4)
                            
                            Text(". \(xpToNextLevel) to next level")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // Level Card
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Level \(level)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    Text(levelTitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        
                        // Conversations Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Conversations (\(conversations.count))")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    // New conversation action
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Conversations List
                            VStack(spacing: 0) {
                                ForEach(conversations) { conversation in
                                    ConversationRow(conversation: conversation)
                                    
                                    if conversation.id != conversations.last?.id {
                                        Divider()
                                            .background(Color(white: 0.2))
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var progressPercentage: Double {
        let totalXP = Double(xp + xpToNextLevel)
        return totalXP > 0 ? Double(xp) / totalXP : 0
    }
}

// Financial Card Component
struct FinancialCard: View {
    let icon: String
    let title: String
    let value: Double
    let isPositive: Bool
    let showSign: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(formatValue(value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isPositive ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    private func formatValue(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0,00"
        let sign = showSign ? (isPositive ? "+" : "-") : ""
        return "\(sign)\(formatted) €"
    }
}

// Conversation Item Model
struct ConversationItem: Identifiable {
    let id: String
    let title: String
    let date: Date
    let isToday: Bool
    
    init(id: String = UUID().uuidString, title: String, date: Date, isToday: Bool) {
        self.id = id
        self.title = title
        self.date = date
        self.isToday = isToday
    }
}

// Conversation Row Component
struct ConversationRow: View {
    let conversation: ConversationItem
    
    var body: some View {
        Button(action: {
            // Open conversation
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatDate(conversation.date, isToday: conversation.isToday))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date, isToday: Bool) -> String {
        if isToday {
            return "Today"
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo < 7 {
            return "\(daysAgo) days ago"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    SidebarMenu(isPresented: .constant(true))
}

