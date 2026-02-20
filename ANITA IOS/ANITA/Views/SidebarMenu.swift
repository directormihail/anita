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
    @ObservedObject private var xpStore = XPStore.shared

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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .liquidGlass(cornerRadius: 14)
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // XP / Level card — compact variant (from shared store)
                Group {
                    if let xpStats = xpStore.xpStats {
                        XPLevelWidget(xpStats: xpStats, compact: true)
                    } else {
                        // Loading placeholder: compact card shape
                        VStack(spacing: 14) {
                            HStack {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 64, height: 17)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 80, height: 12)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 40, height: 20)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 20, height: 10)
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 100, height: 11)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 28, height: 11)
                                }
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 8)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .liquidGlass(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                
                // Conversations Section — aligned padding with card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if viewModel.isLoading {
                            Text("\(AppL10n.t("sidebar.conversations"))...")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(AppL10n.t("sidebar.conversations")) (\(viewModel.conversations.count))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .digit3D(baseColor: .white)
                        }
                        Spacer(minLength: 4)
                        Button(action: { handleNewConversation() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    
                    // Scrollable Conversations List
                    ScrollView {
                        VStack(spacing: 0) {
                            if viewModel.isLoading && viewModel.conversations.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.vertical, 20)
                            } else if viewModel.conversations.isEmpty {
                                Text(AppL10n.t("sidebar.no_conversations"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 16)
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
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(AppL10n.t("sidebar.connection_error"))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.red)
                                    Text(errorMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable { viewModel.refresh() }
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
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

// XP Info sheet — ANITA design: liquid glass, white/gray hierarchy, no blue
struct XPInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Header: title + close (same as sidebar)
                HStack {
                    Text(AppL10n.t("xp_info.title"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .liquidGlass(cornerRadius: 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Content card — liquid glass like rest of ANITA
                VStack(alignment: .leading, spacing: 18) {
                    row(icon: "flame.fill", text: AppL10n.t("xp_info.earn"))
                    row(icon: "chart.bar.fill", text: AppL10n.t("xp_info.bar"))
                    row(icon: "star.fill", text: AppL10n.t("xp_info.levels"))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(cornerRadius: 16)
                .padding(.horizontal, 20)
                
                Spacer(minLength: 24)
                
                // Primary action — liquid glass button, white text (no blue)
                Button(action: { dismiss() }) {
                    Text(AppL10n.t("xp_info.got_it"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .liquidGlass(cornerRadius: 14)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
    
    private func row(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
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
        let userCurrency = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
        let localeId: String
        switch userCurrency {
        case "USD": localeId = "en_US"
        case "EUR": localeId = "de_DE"
        case "CHF": localeId = "de_CH"
        default: localeId = "en_US"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = Locale(identifier: localeId)
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: abs(amount))) ?? "0.00"
        let sign = showSign ? (isPositive ? "+" : "-") : ""
        return "\(sign)\(formatted)"
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
        Button(action: { onTap() }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(formatDate(conversation.date, isToday: conversation.isToday))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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

