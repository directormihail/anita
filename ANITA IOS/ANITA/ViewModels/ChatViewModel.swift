//
//  ChatViewModel.swift
//  ANITA
//
//  ViewModel for chat functionality with conversation persistence
//

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    @Published var currentConversationId: String?
    @Published var conversations: [Conversation] = []
    
    private let networkService = NetworkService.shared
    private let supabaseService = SupabaseService.shared
    private let userManager = UserManager.shared
    private let userId: String
    
    init(userId: String? = nil) {
        self.userId = userId ?? userManager.userId
        Task {
            await loadConversations()
        }
    }
    
    // Load conversations from Supabase
    func loadConversations() async {
        do {
            // Always use authenticated user ID if available, otherwise fall back to stored userId
            let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
            print("[ChatViewModel] Loading conversations for userId: \(currentUserId)")
            let response = try await networkService.getConversations(userId: currentUserId)
            await MainActor.run {
                conversations = response.conversations
                print("[ChatViewModel] Loaded \(conversations.count) conversations")
            }
        } catch {
            print("[ChatViewModel] Error loading conversations: \(error.localizedDescription)")
        }
    }
    
    // Load messages for a conversation
    func loadMessages(conversationId: String) async {
        do {
            // Always use authenticated user ID if available
            let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
            print("[ChatViewModel] Loading messages for conversation: \(conversationId), userId: \(currentUserId)")
            let response = try await networkService.getMessages(conversationId: conversationId, userId: currentUserId)
            
            print("[ChatViewModel] Received \(response.messages.count) messages from backend")
            
            // Convert Supabase messages to ChatMessage format
            // Database uses 'anita' for assistant messages, but we support both 'anita' and 'assistant' for backwards compatibility
            let loadedMessages = response.messages.compactMap { msg -> ChatMessage? in
                // Log each message for debugging
                print("[ChatViewModel] Processing message - id: \(msg.id), messageId: \(msg.messageId ?? "nil"), sender: \(msg.sender ?? "nil"), messageText length: \(msg.messageText?.count ?? 0)")
                
                // Skip messages with no content
                guard let messageText = msg.messageText, !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("[ChatViewModel] Skipping message with empty content: \(msg.id)")
                    return nil
                }
                
                // Determine role based on sender
                // If sender is nil or empty, try to infer from context or default to assistant
                let role: String
                let senderValue = msg.sender?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if senderValue == "user" {
                    role = "user"
                } else if senderValue == "anita" || senderValue == "assistant" || senderValue.isEmpty {
                    // Default to assistant if sender is anita, assistant, or nil/empty
                    role = "assistant"
                    if senderValue.isEmpty {
                        print("[ChatViewModel] Sender is nil/empty for message \(msg.id), defaulting to assistant")
                    }
                } else {
                    // Unknown sender value - log it but still process the message
                    print("[ChatViewModel] Unknown sender '\(msg.sender ?? "nil")' for message \(msg.id), defaulting to assistant")
                    role = "assistant"
                }
                
                let messageId = msg.messageId ?? msg.id
                let timestamp = ISO8601DateFormatter().date(from: msg.createdAt) ?? Date()
                
                return ChatMessage(
                    id: messageId,
                    role: role,
                    content: messageText,
                    timestamp: timestamp
                )
            }
            
            print("[ChatViewModel] Successfully loaded \(loadedMessages.count) messages")
            
            await MainActor.run {
                messages = loadedMessages
                currentConversationId = conversationId
                print("[ChatViewModel] Updated messages array with \(messages.count) messages")
            }
        } catch {
            print("[ChatViewModel] Error loading messages: \(error.localizedDescription)")
            if let networkError = error as? NetworkError {
                print("[ChatViewModel] Network error details: \(networkError.localizedDescription)")
            }
            await MainActor.run {
                errorMessage = "Failed to load conversation: \(error.localizedDescription)"
            }
        }
    }
    
    // Create a new conversation
    func createConversation(title: String) async throws -> String {
        // Check if user is authenticated before creating conversation
        guard userManager.isAuthenticated, let authenticatedUserId = userManager.currentUser?.id else {
            let error = NSError(
                domain: "ChatViewModel",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Please sign in to create conversations. Go to Settings to sign in or sign up."]
            )
            throw error
        }
        
        // Use authenticated user ID instead of potentially local UUID
        let actualUserId = authenticatedUserId
        print("[ChatViewModel] Creating conversation with authenticated userId: \(actualUserId), title: \(title)")
        do {
            let response = try await networkService.createConversation(userId: actualUserId, title: title)
            let conversationId = response.conversation.id
            print("[ChatViewModel] Conversation created successfully: \(conversationId)")
            currentConversationId = conversationId
            
            // Reload conversations list
            await loadConversations()
            
            // Notify SidebarViewModel to refresh its conversation list
            NotificationCenter.default.post(name: NSNotification.Name("ConversationCreated"), object: conversationId)
            
            return conversationId
        } catch {
            print("[ChatViewModel] Error creating conversation: \(error.localizedDescription)")
            // Check if it's a foreign key constraint error
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("foreign key") || errorDesc.contains("user not found") || errorDesc.contains("does not exist") {
                let authError = NSError(
                    domain: "ChatViewModel",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "User not found. Please sign in or sign up first. Go to Settings to authenticate."]
                )
                throw authError
            }
            throw error
        }
    }
    
    // Save a message to Supabase
    func saveMessage(_ message: ChatMessage, conversationId: String) async {
        do {
            print("[ChatViewModel] Saving message: \(message.id) to conversation: \(conversationId)")
            // Convert "assistant" role to "anita" for database compatibility
            // Database schema only allows 'user' or 'anita' as sender values
            let sender = message.role == "assistant" ? "anita" : message.role
            
            // Always use authenticated user ID if available
            let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
            
            _ = try await networkService.saveMessage(
                userId: currentUserId,
                conversationId: conversationId,
                messageId: message.id,
                messageText: message.content,
                sender: sender
            )
            print("[ChatViewModel] Message saved successfully")
        } catch {
            print("[ChatViewModel] Error saving message: \(error.localizedDescription)")
            // Don't throw - message is already displayed, saving is secondary
        }
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
                // First, check backend connection
                print("[ChatViewModel] Checking backend connection...")
                do {
                    _ = try await networkService.checkHealth()
                    print("[ChatViewModel] Backend connection OK")
                } catch {
                    print("[ChatViewModel] Backend connection failed: \(error.localizedDescription)")
                    await MainActor.run {
                        errorMessage = "Cannot connect to backend. Please check:\n1. Backend is running on port 3001\n2. Backend URL is correct in Settings\n3. Device and backend are on same network"
                        isLoading = false
                        if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                            messages.remove(at: index)
                        }
                        inputText = messageText
                    }
                    return
                }
                
                // Create conversation if needed
                var conversationId = currentConversationId
                if conversationId == nil {
                    print("[ChatViewModel] Creating new conversation...")
                    let title = messageText.count > 50 ? String(messageText.prefix(50)) + "..." : messageText
                    do {
                        conversationId = try await createConversation(title: title)
                        print("[ChatViewModel] Conversation created: \(conversationId ?? "nil")")
                    } catch {
                        print("[ChatViewModel] Failed to create conversation: \(error.localizedDescription)")
                        let errorDesc = error.localizedDescription
                        var userFriendlyError = errorDesc
                        
                        // Provide more helpful error messages for authentication issues
                        if errorDesc.contains("sign in") || errorDesc.contains("authenticate") || errorDesc.contains("User not found") {
                            userFriendlyError = "Please sign in to use ANITA. Go to Settings → Sign In to authenticate your account."
                        } else if errorDesc.contains("foreign key") || errorDesc.contains("does not exist") {
                            userFriendlyError = "User account not found. Please sign in or sign up first. Go to Settings to authenticate."
                        }
                        
                        await MainActor.run {
                            errorMessage = userFriendlyError
                            isLoading = false
                            if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                                messages.remove(at: index)
                            }
                            inputText = messageText
                        }
                        return
                    }
                }
                
                // Save user message
                if let convId = conversationId {
                    print("[ChatViewModel] Saving user message to conversation: \(convId)")
                    await saveMessage(userMessage, conversationId: convId)
                }
                
                // Convert messages to API format
                let apiMessages = messages.map { msg in
                    ChatMessageRequest(role: msg.role, content: msg.content)
                }
                
                print("[ChatViewModel] Sending chat message to backend...")
                // Always use authenticated user ID if available
                let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
                // Pass userId and conversationId for context-aware responses
                let response = try await networkService.sendChatMessage(
                    messages: apiMessages,
                    userId: currentUserId,
                    conversationId: conversationId
                )
                print("[ChatViewModel] Received response from backend")
                
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: response.response
                )
                
                await MainActor.run {
                    messages.append(assistantMessage)
                    isLoading = false
                }
                
                // Save assistant message
                if let convId = conversationId {
                    print("[ChatViewModel] Saving assistant message to conversation: \(convId)")
                    await saveMessage(assistantMessage, conversationId: convId)
                    
                    // Notify SidebarViewModel to refresh after message is saved
                    // This ensures the conversation list shows the updated conversation
                    NotificationCenter.default.post(name: NSNotification.Name("ConversationUpdated"), object: convId)
                }
            } catch {
                print("[ChatViewModel] Error sending message: \(error)")
                let errorDesc = error.localizedDescription
                var userFriendlyError = errorDesc
                
                // Provide more helpful error messages
                if errorDesc.contains("timed out") || errorDesc.contains("timeout") {
                    userFriendlyError = "Request timed out. Please check your internet connection and try again."
                } else if errorDesc.contains("cannot find host") || errorDesc.contains("cannot connect") {
                    userFriendlyError = "Cannot connect to backend server. Please check:\n1. Backend is running\n2. Backend URL in Settings is correct\n3. Device and backend are on same network"
                } else if errorDesc.contains("The Internet connection appears to be offline") {
                    userFriendlyError = "No internet connection. Please check your network settings."
                }
                
                await MainActor.run {
                    errorMessage = userFriendlyError
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
    
    // Start a new conversation
    func startNewConversation() {
        messages = []
        currentConversationId = nil
    }
    
    // Save feedback for a message
    func saveFeedback(messageId: String, feedbackType: String?) async {
        guard let authenticatedUserId = userManager.currentUser?.id else {
            print("[ChatViewModel] Cannot save feedback: user not authenticated")
            return
        }
        
        // If feedbackType is nil, we're removing feedback (toggle off)
        // For now, we'll just save the feedback when it's set
        guard let feedbackType = feedbackType else {
            print("[ChatViewModel] Feedback type is nil, skipping save")
            return
        }
        
        do {
            print("[ChatViewModel] Saving feedback: \(feedbackType) for message: \(messageId)")
            _ = try await networkService.saveMessageFeedback(
                userId: authenticatedUserId,
                messageId: messageId,
                conversationId: currentConversationId,
                feedbackType: feedbackType
            )
            
            // Update the message's feedback type in the local array
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    let updatedMessage = messages[index]
                    // Create a new message with updated feedback
                    let newMessage = ChatMessage(
                        id: updatedMessage.id,
                        role: updatedMessage.role,
                        content: updatedMessage.content,
                        timestamp: updatedMessage.timestamp,
                        feedbackType: feedbackType
                    )
                    messages[index] = newMessage
                }
            }
            
            print("[ChatViewModel] Feedback saved successfully")
        } catch {
            print("[ChatViewModel] Error saving feedback: \(error.localizedDescription)")
            // Don't show error to user - feedback is non-critical
        }
    }
}

