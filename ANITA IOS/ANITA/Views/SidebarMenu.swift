//
//  SidebarMenu.swift
//  ANITA
//
//  Sidebar menu matching the mobile design
//

import SwiftUI

struct SidebarMenu: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = SidebarViewModel()
    
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
                                // TODO: Implement upgrade action
                                // This could open a checkout session or navigate to upgrade view
                                handleUpgrade()
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
                        
                        // Progress/XP Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.green)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("\(viewModel.xp) XP")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    // TODO: Show XP info modal
                                    print("XP info tapped")
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
                                        .fill(Color.white.opacity(0.1))
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
                            
                            Text(". \(viewModel.xpToNextLevel) to next level")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            // Level Card
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Level \(viewModel.level)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    Text(viewModel.levelTitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .liquidGlass(cornerRadius: 12)
                        }
                        .padding(.horizontal, 16)
                        
                        // Conversations Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if viewModel.isLoading {
                                    Text("Conversations...")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("Conversations (\(viewModel.conversations.count))")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    handleNewConversation()
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Conversations List
                            if viewModel.isLoading && viewModel.conversations.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .padding()
                            } else if viewModel.conversations.isEmpty {
                                Text("No conversations yet")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.conversations) { conversation in
                                        ConversationRow(conversation: conversation) {
                                            handleConversationTap(conversation.id)
                                        }
                                        
                                        if conversation.id != viewModel.conversations.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.leading, 16)
                                        }
                                    }
                                }
                                .liquidGlass(cornerRadius: 12)
                            }
                            
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.refresh()
        }
    }
    }
    
    private var progressPercentage: Double {
        let totalXP = Double(viewModel.xp + viewModel.xpToNextLevel)
        return totalXP > 0 ? Double(viewModel.xp) / totalXP : 0
    }
    
    private func handleUpgrade() {
        // TODO: Implement upgrade flow
        // This could open a checkout session or navigate to upgrade view
        print("Upgrade button tapped")
    }
    
    private func handleNewConversation() {
        // Close sidebar and start new conversation
        isPresented = false
        // TODO: Trigger new conversation in ChatView
        // This could use a notification or environment object
        NotificationCenter.default.post(name: NSNotification.Name("NewConversation"), object: nil)
    }
    
    private func handleConversationTap(_ conversationId: String) {
        // Close sidebar and open conversation
        isPresented = false
        // TODO: Load conversation in ChatView
        NotificationCenter.default.post(name: NSNotification.Name("OpenConversation"), object: conversationId)
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
        .liquidGlass(cornerRadius: 12)
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
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: {
            onTap()
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

