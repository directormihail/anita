//
//  ChatViewModel.swift
//  ANITA
//
//  ViewModel for chat functionality
//

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    
    private let networkService = NetworkService.shared
    private let userId: String
    
    init(userId: String = UUID().uuidString) {
        self.userId = userId
        // Add welcome message
        messages.append(ChatMessage(
            role: "assistant",
            content: "Hello! I'm ANITA, your personal finance AI assistant. How can I help you today? 💰"
        ))
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(role: "user", content: inputText)
        messages.append(userMessage)
        
        let messageText = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Convert messages to API format
                let apiMessages = messages.map { msg in
                    ChatMessageRequest(role: msg.role, content: msg.content)
                }
                
                let response = try await networkService.sendChatMessage(messages: apiMessages)
                
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: response.response
                )
                
                await MainActor.run {
                    messages.append(assistantMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    // Remove the user message if sending failed
                    if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                        messages.remove(at: index)
                    }
                    inputText = messageText // Restore input text
                }
            }
        }
    }
}

