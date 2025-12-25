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
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top navigation bar
                HStack {
                    // Hamburger menu with notification dot
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSidebarPresented.toggle()
                        }
                    }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            
                            // Notification dot
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                                .offset(x: 6, y: -6)
                        }
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // ANITA text
                    Text("ANITA")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.trailing, 16)
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
                                
                                // Capability cards
                                VStack(spacing: 16) {
                                    CapabilityCard(
                                        icon: "doc.text.fill",
                                        title: "Record transactions",
                                        description: "Track your income and expenses"
                                    )
                                    
                                    CapabilityCard(
                                        icon: "target",
                                        title: "Set targets",
                                        description: "Create and manage your financial goals"
                                    )
                                    
                                    CapabilityCard(
                                        icon: "chart.bar.fill",
                                        title: "Analytics",
                                        description: "Get insights into your spending patterns"
                                    )
                                    
                                    CapabilityCard(
                                        icon: "bubble.left.and.bubble.right.fill",
                                        title: "Talk about finances",
                                        description: "Ask me anything about your money"
                                    )
                                }
                                .padding(.horizontal, 20)
                                
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
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(Color(red: 0.4, green: 0.49, blue: 0.92))
                                        Text("ANITA is thinking...")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
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
                            .background(Color(white: 0.15))
                            .cornerRadius(24)
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
                                    .background(Color(white: 0.2))
                                    .clipShape(Circle())
                            }
                        } else {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(viewModel.isLoading ? Color.gray : Color(white: 0.2))
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
    }

// Capability Card Component
struct CapabilityCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
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
                .background(Color(white: 0.15))
                .cornerRadius(8)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !isUser {
                // ANITA avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.49, blue: 0.92), Color(red: 0.5, green: 0.6, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("A")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isUser 
                            ? Color(red: 0.4, green: 0.49, blue: 0.92)
                            : Color(white: 0.15)
                    )
                    .cornerRadius(18)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isUser ? .trailing : .leading)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if isUser {
                // User avatar
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ChatView()
}
