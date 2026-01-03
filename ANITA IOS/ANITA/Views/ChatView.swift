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
                                Text("Upgrade")
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
                            // Welcome screen matching the image
                            VStack(spacing: 24) {
                                // Greeting
                                VStack(spacing: 8) {
                                    Text("Hi, I'm ANITA")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Your Personal Finance Assistant. I can help you:")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 40)
                                
                                // Capability bullet points (clickable)
                                VStack(alignment: .leading, spacing: 20) {
                                    ClickableFeatureBullet(
                                        icon: "doc.text.fill",
                                        title: "Record transactions",
                                        description: "Track your income and expenses",
                                        action: {
                                            viewModel.inputText = "Record a transaction"
                                            viewModel.sendMessage()
                                        }
                                    )
                                    
                                    ClickableFeatureBullet(
                                        icon: "target",
                                        title: "Set targets",
                                        description: "Create and manage your financial goals",
                                        action: {
                                            viewModel.inputText = "Set a target"
                                            viewModel.sendMessage()
                                        }
                                    )
                                    
                                    ClickableFeatureBullet(
                                        icon: "chart.bar.fill",
                                        title: "Analytics",
                                        description: "Get insights into your spending patterns",
                                        action: {
                                            viewModel.inputText = "Show analytics"
                                            viewModel.sendMessage()
                                        }
                                    )
                                    
                                    ClickableFeatureBullet(
                                        icon: "message.fill",
                                        title: "Talk about finances",
                                        description: "Ask me anything about your money",
                                        action: {
                                            viewModel.inputText = "Tell me about my finances"
                                            viewModel.sendMessage()
                                        }
                                    )
                                }
                                .padding(.horizontal, 32)
                                
                                Text("Start a conversation to begin managing your finances!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
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
                    .onChange(of: viewModel.messages.count) {
                        if !showWelcomeScreen, let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Quick action buttons (only show on welcome screen)
                if showWelcomeScreen {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            QuickActionButton(title: "Add Income") {
                                viewModel.inputText = "Add income"
                                viewModel.sendMessage()
                            }
                            
                            QuickActionButton(title: "Add Expense") {
                                viewModel.inputText = "Add expense"
                                viewModel.sendMessage()
                            }
                            
                            QuickActionButton(title: "Set a Target") {
                                viewModel.inputText = "Set a target"
                                viewModel.sendMessage()
                            }
                            
                            QuickActionButton(title: "Analytics") {
                                viewModel.inputText = "Show analytics"
                                viewModel.sendMessage()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                }
                
                // Input area - matching image design
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Text input
                        TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                            .focused($isInputFocused)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .liquidGlass(cornerRadius: 24)
                            .lineLimit(1...4)
                            .disabled(viewModel.isLoading)
                        
                        // Microphone or Send button
                        if viewModel.inputText.isEmpty {
                            Button(action: {
                                // Voice recording
                            }) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color(white: 0.12), in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        } else {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.isLoading ? .gray : .white)
                                    .frame(width: 40, height: 40)
                                    .background(Color(white: 0.12), in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            .disabled(viewModel.isLoading)
                        }
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
                            Text("Error")
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

// Clickable Feature Bullet Component matching WelcomeView design
struct ClickableFeatureBullet: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(alignment: .top, spacing: 16) {
                // Bullet point icon
                VStack {
                    ZStack {
                        // Glass circle background
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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Spacer()
                }
                .padding(.top, 2)
                
                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text(description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
        }
        .buttonStyle(FeatureBulletButtonStyle())
    }
}

struct FeatureBulletButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Quick Action Button Component
struct QuickActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(cornerRadius: 8)
        }
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
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    
                    // Like/Dislike/Copy buttons (only for ANITA messages)
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
                    }
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

