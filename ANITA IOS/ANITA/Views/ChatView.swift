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
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
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
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input area - matching webapp style
                VStack(spacing: 0) {
                    Divider()
                        .background(Color(white: 0.2))
                    
                    HStack(spacing: 12) {
                        // Attachment button
                        Button(action: {
                            // File attachment functionality
                        }) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        
                        // Text input
                        HStack {
                            TextField("Type your message...", text: $viewModel.inputText, axis: .vertical)
                                .focused($isInputFocused)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.1))
                                .cornerRadius(20)
                                .lineLimit(1...4)
                                .disabled(viewModel.isLoading)
                        }
                        
                        // Send or microphone button
                        if viewModel.inputText.isEmpty {
                            Button(action: {
                                // Voice recording
                            }) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color(red: 0.4, green: 0.49, blue: 0.92))
                                    .clipShape(Circle())
                            }
                        } else {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(viewModel.isLoading ? Color.gray : Color(red: 0.4, green: 0.49, blue: 0.92))
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
        .navigationBarHidden(true)
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
