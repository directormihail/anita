//
//  ChatView.swift
//  ANITA
//
//  Chat interface matching webapp design
//

import SwiftUI

private let aiConsentKey = "anita_ai_consent_given"

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @FocusState private var isInputFocused: Bool
    @State private var isSidebarPresented = false
    @State private var showUpgradeView = false
    @State private var showAIConsentSheet = false
    @State private var isConnectingBankSync = false
    @State private var bankLinkError: String?
    @State private var showBankLinkErrorAlert = false
    @State private var showBankConnectConfirm = false
    /// Quick-start grid stays visible until the user sends their first message; greeting sits under the buttons.
    private var showQuickStartChrome: Bool {
        !viewModel.messages.contains { $0.role == "user" }
    }
    
    /// Before sending to AI we must have user consent (App Store AI disclosure). If not yet given, show sheet; on Continue, set consent and send.
    private func requestSendMessage() {
        if UserDefaults.standard.bool(forKey: aiConsentKey) {
            viewModel.sendMessage()
        } else {
            showAIConsentSheet = true
        }
    }
    
    private func resolvedWelcomeHookText(for message: ChatMessage) -> String {
        if !viewModel.welcomeHookBody.isEmpty { return viewModel.welcomeHookBody }
        let lead = viewModel.welcomeTypewriterLead
        if !lead.isEmpty, message.content.hasPrefix(lead) {
            return String(message.content.dropFirst(lead.count))
        }
        return message.content
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Main content with edge-swipe to open sidebar (thin strip so hamburger button stays tappable)
            mainContentView
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 12)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width > 50 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            isSidebarPresented = true
                                        }
                                    }
                                }
                        )
                }
                .blur(radius: isSidebarPresented ? 8 : 0)
                .scaleEffect(isSidebarPresented ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSidebarPresented)
            
            // Sidebar overlay
            if isSidebarPresented {
                // Dimming overlay
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSidebarPresented = false
                        }
                    }
                
                // Sidebar menu — proper width for card + list
                HStack(spacing: 0) {
                    SidebarMenu(isPresented: $isSidebarPresented)
                        .frame(width: min(UIScreen.main.bounds.width * 0.72, 340))
                    
                    Spacer()
                }
                .transition(.move(edge: .leading))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSidebarPresented)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewConversation"))) { _ in
            viewModel.startNewConversation()
            viewModel.ensureWelcomeGreetingIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
            if let conversationId = notification.object as? String {
                Task {
                    await viewModel.loadMessages(conversationId: conversationId)
                }
            }
        }
        .onAppear {
            Task { await subscriptionManager.refresh() }
            if viewModel.currentConversationId == nil, viewModel.messages.isEmpty {
                viewModel.ensureWelcomeGreetingIfNeeded()
            }
            // If we have a current conversation but no messages loaded, try to load them
            if let conversationId = viewModel.currentConversationId, viewModel.messages.isEmpty {
                Task {
                    print("[ChatView] onAppear: Loading messages for conversation: \(conversationId)")
                    await viewModel.loadMessages(conversationId: conversationId)
                }
            }
        }
        .sheet(isPresented: $showUpgradeView) {
            UpgradeView()
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIConsentSheetView(
                onContinue: {
                    UserDefaults.standard.set(true, forKey: aiConsentKey)
                    showAIConsentSheet = false
                    viewModel.sendMessage()
                },
                onNotNow: {
                    showAIConsentSheet = false
                }
            )
        }
        .onChange(of: viewModel.showPaywallForLimitReached) { _, shouldShow in
            if shouldShow {
                showUpgradeView = true
                viewModel.showPaywallForLimitReached = false
            }
        }
        .onChange(of: showUpgradeView) { _, isShowing in
            if !isShowing {
                Task { await SubscriptionManager.shared.refresh() }
            }
        }
        .alert(
            AppL10n.t("bank.connect_deletes_manual_title"),
            isPresented: $showBankConnectConfirm
        ) {
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
            Button(AppL10n.t("bank.connect_deletes_manual_continue")) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await BankLinkFlow.run(
                        subscriptionManager: subscriptionManager,
                        userManager: userManager,
                        onNeedsPremium: { showUpgradeView = true },
                        isConnecting: $isConnectingBankSync,
                        errorMessage: $bankLinkError,
                        onRefresh: {}
                    )
                    if let err = bankLinkError, !err.isEmpty {
                        showBankLinkErrorAlert = true
                    }
                }
            }
        } message: {
            Text(
                "\(AppL10n.t("bank.connect_deletes_manual_intro"))\n\n\(AppL10n.t("bank.connect_deletes_manual_warning"))"
            )
        }
        .alert(AppL10n.t("chat.error"), isPresented: $showBankLinkErrorAlert) {
            Button(AppL10n.t("common.ok"), role: .cancel) {
                bankLinkError = nil
            }
        } message: {
            Text(bankLinkError ?? "")
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top navigation bar — title/subtitle are geometrically centered; menu & upgrade sit in a side rail.
                ZStack {
                    HStack(alignment: .center, spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSidebarPresented.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .liquidGlass(cornerRadius: 16)
                        }
                        .padding(.leading, 16)
                        
                        Spacer(minLength: 0)
                        
                        Group {
                            if subscriptionManager.isPremium {
                                ChatHeaderBankConnectButton(
                                    isConnecting: isConnectingBankSync,
                                    bankLinked: userManager.hasEstablishedBankSync,
                                    action: {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        showBankConnectConfirm = true
                                    }
                                )
                            } else {
                                ChatHeaderUpgradeGlassPill(onUpgrade: { showUpgradeView = true })
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    
                    VStack(spacing: 2) {
                        Text("ANITA")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .textCase(.uppercase)
                            .kerning(1.2)
                        Text(subscriptionManager.subscriptionDisplayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                            .textCase(.uppercase)
                            .kerning(1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.black)
                
                // Messages list and/or quick-start welcome (greeting bubble + task grid until first user message)
                ScrollViewReader { proxy in
                    ScrollView {
                        if showQuickStartChrome {
                            VStack(spacing: 0) {
                                if !viewModel.messages.isEmpty {
                                    LazyVStack(alignment: .leading, spacing: 16) {
                                        ForEach(viewModel.messages) { message in
                                            if message.id == ChatViewModel.welcomeGreetingMessageId {
                                                TypewriterWelcomeMessageView(
                                                    leadLine: viewModel.welcomeTypewriterLead,
                                                    hookText: resolvedWelcomeHookText(for: message),
                                                    message: message,
                                                    viewModel: viewModel
                                                )
                                                .id(viewModel.welcomeHookBody + viewModel.welcomeTypewriterLead)
                                            } else {
                                                MessageBubble(message: message, viewModel: viewModel)
                                                    .id(message.id)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                                }
                                
                                Text(AppL10n.t("chat.notifications_hint"))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.top, 8)
                                
                                Spacer(minLength: 12)
                            }
                            .padding(.top, 12)
                        } else {
                            // Messages list
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message, viewModel: viewModel)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    CurrencyLoadingAnimation()
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 25)
                            .onEnded { value in
                                let startX = value.startLocation.x
                                let horizontal = value.translation.width
                                let vertical = abs(value.translation.height)
                                if startX < 100, horizontal > 60, horizontal > vertical {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isSidebarPresented = true
                                    }
                                }
                            }
                    )
                    .onChange(of: viewModel.messages.count) { _, _ in
                        guard let lastMessage = viewModel.messages.last else { return }
                        if showQuickStartChrome {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        } else {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input area - matching image design
                VStack(spacing: 0) {
                    if showQuickStartChrome {
                        ChatInputQuickActionsScrollBar(
                            blockManualTransactionChips: userManager.blocksManualTransactions,
                            onAddIncome: {
                                viewModel.inputText = AppL10n.t("chat.add_income")
                                requestSendMessage()
                            },
                            onAddExpense: {
                                viewModel.inputText = AppL10n.t("chat.add_expense")
                                requestSendMessage()
                            },
                            onSetTarget: {
                                if !subscriptionManager.isPremium {
                                    showUpgradeView = true
                                } else {
                                    viewModel.inputText = AppL10n.t("chat.set_target")
                                    requestSendMessage()
                                }
                            },
                            onAnalytics: {
                                if !subscriptionManager.isPremium {
                                    showUpgradeView = true
                                } else {
                                    viewModel.inputText = AppL10n.t("chat.analytics")
                                    requestSendMessage()
                                }
                            }
                        )
                    }
                    HStack(spacing: 12) {
                        // Text input
                        TextField(AppL10n.t("chat.ask_finance"), text: $viewModel.inputText, axis: .vertical)
                            .focused($isInputFocused)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .liquidGlass(cornerRadius: 24)
                            .lineLimit(1...4)
                            .disabled(viewModel.isLoading)
                        
                        // Send button - always visible, disabled when empty
                        Button(action: {
                            requestSendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor((viewModel.isLoading || viewModel.inputText.isEmpty) ? .gray : .white)
                                .frame(width: 40, height: 40)
                                .financeSolidGlassCircle()
                        }
                        .disabled(viewModel.isLoading || viewModel.inputText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black)
                }
                
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
                    .financeSolidGlassSection(cornerRadius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.red.opacity(0.55), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

// MARK: - Scrollable quick actions above chat input (same look as legacy grid tiles)
private struct ChatInputQuickActionsScrollBar: View {
    var blockManualTransactionChips: Bool = false
    let onAddIncome: () -> Void
    let onAddExpense: () -> Void
    let onSetTarget: () -> Void
    let onAnalytics: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !blockManualTransactionChips {
                    EnhancedTaskScrollChip(
                        icon: "plus",
                        iconColor: Color.green,
                        title: AppL10n.t("chat.add_income"),
                        action: onAddIncome
                    )
                    EnhancedTaskScrollChip(
                        icon: "minus",
                        iconColor: Color.red,
                        title: AppL10n.t("chat.add_expense"),
                        action: onAddExpense
                    )
                }
                EnhancedTaskScrollChip(
                    icon: "target",
                    iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                    title: AppL10n.t("chat.set_target"),
                    action: onSetTarget
                )
                EnhancedTaskScrollChip(
                    icon: "chart.pie.fill",
                    iconColor: Color.orange,
                    title: AppL10n.t("chat.analytics"),
                    action: onAnalytics
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(Color.black)
    }
}

/// Compact liquid-glass pills for the input toolbar (`cornerRadius` ≤ 11 → app compact glass tile).
private struct EnhancedTaskScrollChip: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.22))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        }
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [iconColor.opacity(0.98), iconColor.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.93))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.78)
            }
            .padding(.leading, 8)
            .padding(.trailing, 11)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .liquidGlass(cornerRadius: 11)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(EnhancedTaskButtonStyle())
        .accessibilityLabel(title)
    }
}

struct EnhancedTaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

// Quick Action Button Component - Enhanced design
struct QuickActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlass(cornerRadius: 12)
        }
        .buttonStyle(QuickActionButtonStyle())
    }
}

struct QuickActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Typewriter welcome (quick-start greeting only)
/// Uses plain `Text` for the hook (not `TextFormatter.formatResponse`) so partial strings while typing don’t get mangled or cut off.
private struct TypewriterWelcomeMessageView: View {
    let leadLine: String
    let hookText: String
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var visibleUnitCount = 0
    @State private var selectedFeedback: String?
    @State private var showCopyConfirmation = false
    @State private var typingTask: Task<Void, Never>?
    
    init(leadLine: String, hookText: String, message: ChatMessage, viewModel: ChatViewModel) {
        self.leadLine = leadLine
        self.hookText = hookText
        self.message = message
        self.viewModel = viewModel
        _selectedFeedback = State(initialValue: message.feedbackType)
    }
    
    private var sequences: [String] {
        Self.splitComposedSequences(hookText)
    }
    
    private var visibleHookText: String {
        let seq = sequences
        guard visibleUnitCount > 0, !seq.isEmpty else { return "" }
        let n = min(visibleUnitCount, seq.count)
        return seq.prefix(n).joined()
    }
    
    private var typingComplete: Bool {
        !sequences.isEmpty && visibleUnitCount >= sequences.count
    }
    
    private var trimmedLead: String {
        leadLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if !trimmedLead.isEmpty {
                    Text(trimmedLead)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: UIScreen.main.bounds.width - 48, alignment: .leading)
                        .padding(.bottom, 14)
                        .transaction { $0.animation = nil }
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(visibleHookText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(7)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: UIScreen.main.bounds.width - 56, alignment: .leading)
                        .transaction { $0.animation = nil }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.065))
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    }
                }
                
                if typingComplete {
                    HStack(spacing: 16) {
                        FeedbackButton(
                            icon: "hand.thumbsup",
                            isSelected: selectedFeedback == "like",
                            action: {
                                let newFeedback = selectedFeedback == "like" ? nil : "like"
                                selectedFeedback = newFeedback
                                Task {
                                    await viewModel.saveFeedback(
                                        messageId: message.id,
                                        feedbackType: newFeedback
                                    )
                                }
                            }
                        )
                        FeedbackButton(
                            icon: "hand.thumbsdown",
                            isSelected: selectedFeedback == "dislike",
                            action: {
                                let newFeedback = selectedFeedback == "dislike" ? nil : "dislike"
                                selectedFeedback = newFeedback
                                Task {
                                    await viewModel.saveFeedback(
                                        messageId: message.id,
                                        feedbackType: newFeedback
                                    )
                                }
                            }
                        )
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            showCopyConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopyConfirmation = false
                            }
                        }) {
                            Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(showCopyConfirmation ? .white : .gray)
                                .frame(width: 32, height: 32)
                                .liquidGlass(cornerRadius: 16)
                        }
                    }
                    .padding(.top, 12)
                    .transaction { $0.animation = nil }
                }
            }
            Spacer(minLength: 0)
        }
        .transaction { $0.animation = nil }
        .onAppear(perform: startTyping)
        .onDisappear {
            typingTask?.cancel()
            typingTask = nil
        }
        .onChange(of: hookText) { _, _ in
            restartTyping()
        }
    }
    
    private func restartTyping() {
        typingTask?.cancel()
        visibleUnitCount = 0
        startTyping()
    }
    
    private func startTyping() {
        typingTask?.cancel()
        let seq = Self.splitComposedSequences(hookText)
        guard !seq.isEmpty else {
            visibleUnitCount = 0
            return
        }
        typingTask = Task {
            for i in 1...seq.count {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    visibleUnitCount = i
                }
                if i < seq.count {
                    let pause = Self.delayNanos(after: seq[i - 1])
                    try? await Task.sleep(nanoseconds: pause)
                }
            }
        }
    }
    
    private static func delayNanos(after unit: String) -> UInt64 {
        if unit == "\n" { return 95_000_000 }
        if unit == " " { return 14_000_000 }
        if let c = unit.first, ".!?".contains(c) { return 52_000_000 }
        return 28_000_000
    }
    
    private static func splitComposedSequences(_ s: String) -> [String] {
        var out: [String] = []
        s.enumerateSubstrings(in: s.startIndex..<s.endIndex, options: .byComposedCharacterSequences) { substring, _, _, _ in
            if let substring { out.append(String(substring)) }
        }
        return out
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    @State private var selectedFeedback: String? // "like" or "dislike"
    @State private var showCopyConfirmation = false
    
    var isUser: Bool {
        message.role == "user"
    }
    
    init(message: ChatMessage, viewModel: ChatViewModel) {
        self.message = message
        self.viewModel = viewModel
        _selectedFeedback = State(initialValue: message.feedbackType)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser {
                Spacer()
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                if isUser {
                    // User message: Dark gray bubble with white text, right-aligned
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(red: 0.25, green: 0.25, blue: 0.25)) // Dark gray
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                        .onTapGesture {
                            // Dismiss keyboard when tapping on message
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                } else {
                    // ANITA message: Formatted structured text, left-aligned, no bubble
                    // Match webapp's structured message display with GPT-like spacing
                    VStack(alignment: .leading, spacing: 0) {
                        Text(TextFormatter.formatResponse(message.content))
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.9, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                            .lineSpacing(6)
                            .kerning(0.2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Dismiss keyboard when tapping on message content
                                // This won't interfere with text selection (which uses long press)
                                // or buttons (which are in a separate container below)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    
                    // Like/Dislike/Copy/Check Goal buttons (only for ANITA messages)
                    // Buttons are placed outside the text VStack to ensure they have priority
                    // Buttons will work even when keyboard is open - they have natural priority over background gestures
                    HStack(spacing: 16) {
                        FeedbackButton(
                            icon: "hand.thumbsup",
                            isSelected: selectedFeedback == "like",
                            action: {
                                let newFeedback = selectedFeedback == "like" ? nil : "like"
                                selectedFeedback = newFeedback
                                Task {
                                    await viewModel.saveFeedback(
                                        messageId: message.id,
                                        feedbackType: newFeedback
                                    )
                                }
                            }
                        )
                        
                        FeedbackButton(
                            icon: "hand.thumbsdown",
                            isSelected: selectedFeedback == "dislike",
                            action: {
                                let newFeedback = selectedFeedback == "dislike" ? nil : "dislike"
                                selectedFeedback = newFeedback
                                Task {
                                    await viewModel.saveFeedback(
                                        messageId: message.id,
                                        feedbackType: newFeedback
                                    )
                                }
                            }
                        )
                        
                        // Copy button
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            showCopyConfirmation = true
                            // Hide confirmation after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopyConfirmation = false
                            }
                        }) {
                            Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(showCopyConfirmation ? .white : .gray)
                                .frame(width: 32, height: 32)
                                .liquidGlass(cornerRadius: 16)
                        }
                        
                        // Check Goal button only (limit button hidden for now — show only confirmation)
                        if let targetId = message.targetId, message.targetType != "budget" {
                            CheckGoalButton(targetId: targetId)
                        }
                    }
                    // Buttons are in a separate container, so they won't be affected by the text tap gesture
                    // Buttons have natural priority in SwiftUI and will work even when keyboard is open
                }
            }
            
            if !isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct FeedbackButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 32, height: 32)
                .liquidGlass(cornerRadius: 16)
        }
    }
}

// Check Goal Button Component - matches background style with blue text/icon
struct CheckGoalButton: View {
    let targetId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Post notification to switch to Finance tab and scroll to target
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToTarget"),
                object: targetId
            )
            
            // Switch to Finance tab (index 1)
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToFinanceTab"),
                object: nil
            )
        }) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                
                Text(AppL10n.t("chat.check_goal"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 32)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(CheckGoalButtonStyle())
    }
}

// Check Limit Button Component - matches background style with red text/icon
struct CheckLimitButton: View {
    let targetId: String
    let category: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Post notification to switch to Finance tab and scroll to target
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToTarget"),
                object: targetId
            )
            
            // If category is available, post notification to filter transactions by category
            if let category = category {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FilterTransactionsByCategory"),
                    object: category
                )
            }
            
            // Switch to Finance tab (index 1)
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToFinanceTab"),
                object: nil
            )
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 16, weight: .semibold))
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
                
                Text(AppL10n.t("chat.check_limit"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 32)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(CheckLimitButtonStyle())
    }
}

struct CheckGoalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CheckLimitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Premium header — “Connect” pill before bank link; gold crown in glass circle when linked (matches Upgrade header crown).
private struct ChatHeaderBankConnectButton: View {
    let isConnecting: Bool
    let bankLinked: Bool
    let action: () -> Void
    
    /// rgba(0, 80, 255, 0.2)
    private let pillFill = Color(red: 0, green: 80 / 255, blue: 1).opacity(0.2)
    private let borderBlue = Color(red: 0, green: 122 / 255, blue: 1)
    private let glowColor = Color(red: 0, green: 122 / 255, blue: 1).opacity(0.5)
    /// `UpgradeView` premium crown gold
    private let premiumGold = Color(red: 0.91, green: 0.72, blue: 0.2)
    
    var body: some View {
        Group {
            if bankLinked {
                ZStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.9)))
                            .scaleEffect(0.88)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        premiumGold.opacity(0.95),
                                        premiumGold.opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: premiumGold.opacity(0.35), radius: 8, x: 0, y: 0)
                    }
                }
                .frame(width: 32, height: 32)
                .liquidGlass(cornerRadius: 16)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(AppL10n.t("bank.sync_bank")). \(AppL10n.t("chat.header_bank_pill_linked"))")
            } else {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.95)))
                                .scaleEffect(0.78)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        Text(AppL10n.t("chat.header_bank_pill_connect"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        Capsule(style: .continuous)
                            .fill(pillFill)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(borderBlue, lineWidth: 1)
                            )
                    }
                }
                .buttonStyle(.plain)
                .shadow(color: glowColor, radius: 5, x: 0, y: 0)
                .disabled(isConnecting)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(AppL10n.t("bank.sync_bank")). \(AppL10n.t("chat.header_bank_pill_connect"))")
                .accessibilityHint(AppL10n.t("bank.sync_bank_hint"))
            }
        }
    }
}

/// Matches `UpgradeView` primary Continue CTA — same paywall blue gradient, rim, and shadow.
private struct ChatHeaderUpgradeGlassPill: View {
    var onUpgrade: () -> Void
    
    private static let gradientTop = Color(red: 0.11, green: 0.62, blue: 1.0)
    private static let gradientBottom = Color(red: 0.20, green: 0.47, blue: 1.0)
    
    var body: some View {
        Button(action: onUpgrade) {
            Text(AppL10n.t("chat.upgrade"))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Self.gradientTop, Self.gradientBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
        }
        .buttonStyle(.plain)
        .shadow(color: Color.blue.opacity(0.18), radius: 10, x: 0, y: 5)
    }
}

struct CurrencyLoadingAnimation: View {
    @State private var animationOffsets: [CGFloat] = [0, 0, 0]
    @State private var animationTimers: [Timer] = []
    
    private let currencies = ["$", "€", "¥"]
    private let jumpHeight: CGFloat = 8
    private let bounceDuration: Double = 0.6 // Time for one bounce (up and down)
    private let delayBetween: Double = 0.2 // Delay between each symbol
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<currencies.count, id: \.self) { index in
                Text(currencies[index])
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .offset(y: animationOffsets[index])
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        // Start each symbol's animation with a delay
        for index in 0..<currencies.count {
            let delay = Double(index) * delayBetween
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateSymbol(at: index)
            }
        }
    }
    
    private func animateSymbol(at index: Int) {
        // Create a repeating bounce animation for this symbol
        let timer = Timer.scheduledTimer(withTimeInterval: bounceDuration * 2 + delayBetween * Double(currencies.count), repeats: true) { _ in
            // Bounce up
            withAnimation(.easeOut(duration: bounceDuration / 2)) {
                animationOffsets[index] = -jumpHeight
            }
            
            // Bounce down
            DispatchQueue.main.asyncAfter(deadline: .now() + bounceDuration / 2) {
                withAnimation(.easeIn(duration: bounceDuration / 2)) {
                    animationOffsets[index] = 0
                }
            }
        }
        
        // Start immediately
        withAnimation(.easeOut(duration: bounceDuration / 2)) {
            animationOffsets[index] = -jumpHeight
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + bounceDuration / 2) {
            withAnimation(.easeIn(duration: bounceDuration / 2)) {
                animationOffsets[index] = 0
            }
        }
        
        animationTimers.append(timer)
    }
    
    private func stopAnimation() {
        animationTimers.forEach { $0.invalidate() }
        animationTimers.removeAll()
        animationOffsets = [0, 0, 0]
    }
}

// MARK: - AI consent (App Store third-party AI disclosure)
struct AIConsentSheetView: View {
    var onContinue: () -> Void
    var onNotNow: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                Text(AppL10n.t("chat.ai_consent_title"))
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                Text(AppL10n.t("chat.ai_consent_message"))
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer(minLength: 20)
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(AppL10n.t("chat.ai_consent_continue"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.4, green: 0.49, blue: 0.92))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    Button(action: onNotNow) {
                        Text(AppL10n.t("chat.ai_consent_not_now"))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

#Preview {
    ChatView()
}

