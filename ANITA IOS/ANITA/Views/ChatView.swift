//
//  ChatView.swift
//  ANITA
//
//  Chat interface matching webapp design
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var isSidebarPresented = false
    @State private var showUpgradeView = false
    
    // Check if we should show the welcome screen (no messages yet)
    private var showWelcomeScreen: Bool {
        viewModel.messages.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Main content
            mainContentView
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
                
                // Sidebar menu
                HStack(spacing: 0) {
                    SidebarMenu(isPresented: $isSidebarPresented)
                        .frame(width: UIScreen.main.bounds.width * 0.85)
                    
                    Spacer()
                }
                .transition(.move(edge: .leading))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSidebarPresented)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewConversation"))) { _ in
            // Start a new conversation by clearing messages
            viewModel.startNewConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversation"))) { notification in
            if let conversationId = notification.object as? String {
                Task {
                    await viewModel.loadMessages(conversationId: conversationId)
                }
            }
        }
        .onAppear {
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
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top navigation bar
                ZStack {
                    HStack {
                        // Hamburger menu with notification dot
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
                        
                        Spacer()
                        
                        // ANITA text
                        Text("ANITA")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 16)
                    }
                    
                    // Plan information - centered
                    HStack(spacing: 8) {
                        Text("Ultimate")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            showUpgradeView = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Text(AppL10n.t("chat.upgrade"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                
                                // Beautiful yellow notification badge
                                ZStack {
                                    // Outer glow
                                    Circle()
                                        .fill(Color.yellow.opacity(0.4))
                                        .frame(width: 10, height: 10)
                                        .blur(radius: 2)
                                    
                                    // Main badge
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.85, blue: 0.1),
                                                    Color(red: 1.0, green: 0.75, blue: 0.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 8, height: 8)
                                        .overlay {
                                            Circle()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                                        }
                                        .shadow(color: Color.yellow.opacity(0.6), radius: 2, x: 0, y: 1)
                                }
                                .offset(x: 2, y: -2)
                            }
                        }
                        .liquidGlass(cornerRadius: 8)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.black)
                
                // Messages list or Welcome screen
                ScrollViewReader { proxy in
                    ScrollView {
                        if showWelcomeScreen {
                            // Premium filled welcome screen
                            ScrollView {
                                VStack(spacing: 0) {
                                    // Premium welcome card - more substantial
                                    VStack(spacing: 18) {
                                        VStack(spacing: 8) {
                                            Text(AppL10n.t("chat.welcome_title"))
                                                .font(.system(size: 32, weight: .bold, design: .rounded))
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
                                                .multilineTextAlignment(.center)
                                            
                                            Text(AppL10n.t("chat.welcome_subtitle"))
                                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.75))
                                                .multilineTextAlignment(.center)
                                        }
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.15))
                                            .padding(.vertical, 4)
                                        
                                        // Simple explanation text
                                        Text(AppL10n.t("chat.welcome_body"))
                                            .font(.system(size: 15, weight: .regular, design: .rounded))
                                            .foregroundColor(.white.opacity(0.65))
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 32)
                                    .liquidGlass(cornerRadius: 16)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 12)
                                    
                                    // Task options in 2x2 grid - premium spacing with full text visibility
                                    VStack(spacing: 12) {
                                        // Row 1
                                        HStack(spacing: 12) {
                                            EnhancedTaskButton(
                                                icon: "plus",
                                                iconColor: Color.green,
                                                title: "Add Income",
                                                action: {
                                                    viewModel.inputText = "Add income"
                                                    viewModel.sendMessage()
                                                }
                                            )
                                            
                                            EnhancedTaskButton(
                                                icon: "minus",
                                                iconColor: Color.red,
                                                title: "Add Expense",
                                                action: {
                                                    viewModel.inputText = "Add expense"
                                                    viewModel.sendMessage()
                                                }
                                            )
                                        }
                                        
                                        // Row 2
                                        HStack(spacing: 12) {
                                            EnhancedTaskButton(
                                                icon: "target",
                                                iconColor: Color(red: 0.4, green: 0.49, blue: 0.92),
                                                title: "Set a Target",
                                                action: {
                                                    viewModel.inputText = "Set a target"
                                                    viewModel.sendMessage()
                                                }
                                            )
                                            
                                            EnhancedTaskButton(
                                                icon: "chart.pie.fill",
                                                iconColor: Color.orange,
                                                title: "Analytics",
                                                action: {
                                                    viewModel.inputText = "Show analytics"
                                                    viewModel.sendMessage()
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                    .padding(.bottom, 20)
                                }
                            }
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
                    .onChange(of: viewModel.messages.count) { oldValue, newValue in
                        if !showWelcomeScreen, let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input area - matching image design
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Text input
                        TextField("Ask about finance", text: $viewModel.inputText, axis: .vertical)
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
                            viewModel.sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor((viewModel.isLoading || viewModel.inputText.isEmpty) ? .gray : .white)
                                .frame(width: 40, height: 40)
                                .background(Color(white: 0.12), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
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
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

// Enhanced Task Button Component - Matching FinanceView design with smaller icons and full text
struct EnhancedTaskButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                // Icon with premium glass effect matching FinanceView
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
                    
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    iconColor.opacity(0.95),
                                    iconColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 40)
                
                // Title text - ensure all letters are visible with proper scaling
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 64)
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(EnhancedTaskButtonStyle())
    }
}

struct EnhancedTaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
                        
                        // Check Goal/Limit button (only shown when targetId is present)
                        if let targetId = message.targetId {
                            if message.targetType == "budget" {
                                // For budget targets, we need to get the category from the target
                                // For now, we'll pass nil and fetch it when needed
                                CheckLimitButton(targetId: targetId, category: message.category)
                            } else {
                                CheckGoalButton(targetId: targetId)
                            }
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


struct CurrencyLoadingAnimation: View {
    @State private var animationOffsets: [CGFloat] = [0, 0, 0]
    @State private var animationTimers: [Timer] = []
    
    private let currencies = ["€", "$", "¥"]
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

#Preview {
    ChatView()
}

