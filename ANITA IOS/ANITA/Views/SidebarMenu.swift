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
                            .liquidGlass(cornerRadius: 16)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Progress/XP Section (Fixed)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.85))
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color(red: 0.5, green: 0.6, blue: 0.85))
                                    .scaleEffect(0.8)
                            } else {
                                Text("\(viewModel.xp) \(AppL10n.t("finance.xp"))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.85))
                                    .digit3D(baseColor: Color(red: 0.5, green: 0.6, blue: 0.85))
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
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 10)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.5, green: 0.6, blue: 0.85))
                                .frame(
                                    width: geometry.size.width * progressPercentage,
                                    height: 10
                                )
                        }
                    }
                    .frame(height: 10)
                    
                    Text("\(viewModel.xpToNextLevel) \(AppL10n.t("finance.xp_to_next_level"))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .digit3D(baseColor: .gray)
                    
                    // Level Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(AppL10n.t("finance.level")) \(viewModel.level)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 0.85))
                                .digit3D(baseColor: Color(red: 0.5, green: 0.6, blue: 0.85))
                            
                            Text(getTranslatedLevelTitle(viewModel.levelTitle))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                // Conversations Section Header (Fixed)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if viewModel.isLoading {
                            Text("\(AppL10n.t("sidebar.conversations"))...")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(AppL10n.t("sidebar.conversations")) (\(viewModel.conversations.count))")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    
                    // Scrollable Conversations List
                    ScrollView {
                        VStack(spacing: 0) {
                            if viewModel.isLoading && viewModel.conversations.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .padding()
                            } else if viewModel.conversations.isEmpty {
                                Text(AppL10n.t("sidebar.no_conversations"))
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
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(AppL10n.t("sidebar.connection_error"))
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.red.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable {
                        viewModel.refresh()
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }
    
    private var progressPercentage: Double {
        let totalXP = Double(viewModel.xp + viewModel.xpToNextLevel)
        return totalXP > 0 ? Double(viewModel.xp) / totalXP : 0
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
    
    private func getTranslatedLevelTitle(_ title: String) -> String {
        let titleMap: [String: String] = [
            "NEWCOMER": "level.newcomer",
            "WEALTH BUILDER": "level.wealth_builder",
            "SAVER": "level.saver",
            "INVESTOR": "level.investor",
            "FINANCIAL GURU": "level.financial_guru",
            "MILLIONAIRE": "level.millionaire"
        ]
        if let key = titleMap[title.uppercased()] {
            return AppL10n.t(key)
        }
        return title
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
            return AppL10n.t("common.today")
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInYesterday(date) {
            return AppL10n.t("common.yesterday")
        }
        
        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo < 7 {
            return "\(daysAgo) \(AppL10n.t("common.days_ago"))"
        }
        
        // Use user's date format preference from UserDefaults
        let dateFormat = UserDefaults.standard.string(forKey: "anita_date_format") ?? "MM/DD/YYYY"
        let displayFormatter = DateFormatter()
        
        // Map date format strings to DateFormatter patterns
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

#Preview {
    SidebarMenu(isPresented: .constant(true))
}

