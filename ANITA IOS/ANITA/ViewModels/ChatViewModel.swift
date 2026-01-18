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
    
    // Track pending transaction input
    private var pendingTransactionType: String? = nil // "income" or "expense"
    
    private let networkService = NetworkService.shared
    private let supabaseService = SupabaseService.shared
    private let userManager = UserManager.shared
    private let userId: String
    
    init(userId: String? = nil) {
        self.userId = userId ?? userManager.userId
        Task {
            await loadConversations()
        }
        
        // Listen for backend URL updates from Settings
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BackendURLUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let newURL = notification.object as? String {
                print("[ChatViewModel] Backend URL updated to: \(newURL)")
                // NetworkService.shared will automatically use the new URL
                // since it reads from UserDefaults on each request
            }
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
    
    // Detect currency from user input
    private func detectCurrency(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        // Currency detection patterns
        let currencyPatterns: [String: [String]] = [
            "EUR": ["euro", "euros", "€", "eur"],
            "USD": ["dollar", "dollars", "$", "usd", "us dollar"],
            "GBP": ["pound", "pounds", "£", "gbp", "sterling"],
            "JPY": ["yen", "¥", "jpy"],
            "CAD": ["canadian dollar", "cad", "c$"],
            "AUD": ["australian dollar", "aud", "a$"],
            "CHF": ["swiss franc", "chf"],
            "CNY": ["yuan", "cny", "renminbi"],
            "INR": ["rupee", "rupees", "₹", "inr"],
            "BRL": ["real", "reais", "r$", "brl"],
            "MXN": ["peso", "pesos", "mx$", "mxn"],
            "SGD": ["singapore dollar", "sgd", "s$"],
            "HKD": ["hong kong dollar", "hkd", "hk$"],
            "NZD": ["new zealand dollar", "nzd", "nz$"],
            "ZAR": ["rand", "zar"]
        ]
        
        for (currency, patterns) in currencyPatterns {
            if patterns.contains(where: { lowercased.contains($0) }) {
                return currency
            }
        }
        
        return nil
    }
    
    // Parse transaction from user message
    private func parseTransaction(from text: String) -> (type: String, amount: Double, category: String?, description: String, currency: String?)? {
        let lowercased = text.lowercased()
        
        // Skip if this looks like a goal/target message
        let goalKeywords = ["goal", "target", "save", "saving", "want to buy", "need to buy", "planning to buy", "dream", "aspiration"]
        if goalKeywords.contains(where: { lowercased.contains($0) }) {
            return nil
        }
        
        // Check for income keywords
        let incomeKeywords = ["earned", "received", "income", "salary", "paycheck", "payment received", "got paid", "made", "profit", "deposit", "bonus"]
        let isIncome = incomeKeywords.contains { lowercased.contains($0) }
        
        // Check for expense keywords
        let expenseKeywords = ["spent", "bought", "purchased", "paid", "expense", "cost", "billing", "subscription", "rent", "bills", "payment"]
        let isExpense = expenseKeywords.contains { lowercased.contains($0) }
        
        // Determine transaction type
        let transactionType: String?
        if isIncome && !isExpense {
            transactionType = "income"
        } else if isExpense && !isIncome {
            transactionType = "expense"
        } else if isExpense {
            // Default to expense if both are present
            transactionType = "expense"
        } else {
            // Check for amount patterns - if amount is mentioned, assume expense
            if lowercased.contains("$") || lowercased.contains("usd") || lowercased.contains("dollar") {
                transactionType = "expense"
            } else {
                transactionType = nil
            }
        }
        
        guard let type = transactionType else { return nil }
        
        // Extract amount using regex - improved pattern to handle various formats
        // Pattern matches: $50, $1,200, $1,200.50, 50, 1200, 1200.50, etc.
        // First try to match numbers with thousands separators, then plain numbers
        let amountPatterns = [
            #"\$?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?)"#,  // With thousands: 1,200 or 1,200.50
            #"\$?\s*(\d+(?:[.,]\d{2})?)"#  // Plain number: 1200 or 1200.50
        ]
        
        var amountString: String?
        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let amountRange = Range(match.range(at: 1), in: text) {
                amountString = String(text[amountRange])
                break
            }
        }
        
        guard var amountString = amountString else {
            return nil
        }
        // Handle comma as thousands separator (e.g., "1,000" or "1,000.50")
        if amountString.contains(",") && amountString.contains(".") {
            // Format: "1,000.50" - remove comma
            amountString = amountString.replacingOccurrences(of: ",", with: "")
        } else if amountString.contains(",") && !amountString.contains(".") {
            // Could be "1,000" (thousands) or "1,50" (decimal with comma)
            // Check if it's likely thousands (3+ digits before comma)
            let parts = amountString.split(separator: ",")
            if parts.count == 2 && parts[0].count >= 3 {
                // Likely thousands separator
                amountString = amountString.replacingOccurrences(of: ",", with: "")
            } else {
                // Likely decimal separator
                amountString = amountString.replacingOccurrences(of: ",", with: ".")
            }
        }
        
        guard let amount = Double(amountString), amount > 0 else {
            return nil
        }
        
        // Use CategoryDefinitions for smart category detection
        let categoryDefinitions = CategoryDefinitions.shared
        let detectedCategory = categoryDefinitions.detectCategory(from: text)
        let category = categoryDefinitions.normalizeCategory(detectedCategory)
        
        // Detect currency from user input
        let detectedCurrency = detectCurrency(from: text)
        
        return (type: type, amount: amount, category: category, description: text, currency: detectedCurrency)
    }
    
    // Extract just the amount from a message (simpler version for pending transactions)
    private func extractAmount(from text: String) -> Double? {
        // Extract amount using regex - improved pattern to handle various formats
        let amountPatterns = [
            #"\$?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?)"#,  // With thousands: 1,200 or 1,200.50
            #"\$?\s*(\d+(?:[.,]\d{2})?)"#  // Plain number: 1200 or 1200.50
        ]
        
        var amountString: String?
        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let amountRange = Range(match.range(at: 1), in: text) {
                amountString = String(text[amountRange])
                break
            }
        }
        
        guard var amountString = amountString else {
            return nil
        }
        
        // Handle comma as thousands separator (e.g., "1,000" or "1,000.50")
        if amountString.contains(",") && amountString.contains(".") {
            // Format: "1,000.50" - remove comma
            amountString = amountString.replacingOccurrences(of: ",", with: "")
        } else if amountString.contains(",") && !amountString.contains(".") {
            // Could be "1,000" (thousands) or "1,50" (decimal with comma)
            // Check if it's likely thousands (3+ digits before comma)
            let parts = amountString.split(separator: ",")
            if parts.count == 2 && parts[0].count >= 3 {
                // Likely thousands separator
                amountString = amountString.replacingOccurrences(of: ",", with: "")
            } else {
                // Likely decimal separator
                amountString = amountString.replacingOccurrences(of: ",", with: ".")
            }
        }
        
        return Double(amountString)
    }
    
    // Format currency for display - uses user's currency preference from Settings
    private func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        // Get user's preferred currency from Settings
        let userCurrency = currencyCode ?? (UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD")
        
        // Get locale for proper currency formatting (EUR uses comma, USD uses period, etc.)
        let locale = getLocaleForCurrency(userCurrency)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = userCurrency
        formatter.locale = locale
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(getCurrencySymbol(userCurrency))\(String(format: "%.2f", amount))"
    }
    
    // Get locale for currency formatting
    private func getLocaleForCurrency(_ currency: String) -> Locale {
        switch currency {
        case "EUR":
            return Locale(identifier: "de_DE") // German locale uses comma for decimals
        case "GBP":
            return Locale(identifier: "en_GB")
        case "JPY":
            return Locale(identifier: "ja_JP")
        case "CAD":
            return Locale(identifier: "en_CA")
        case "AUD":
            return Locale(identifier: "en_AU")
        case "CHF":
            return Locale(identifier: "de_CH")
        case "CNY":
            return Locale(identifier: "zh_CN")
        case "INR":
            return Locale(identifier: "en_IN")
        case "BRL":
            return Locale(identifier: "pt_BR")
        case "MXN":
            return Locale(identifier: "es_MX")
        case "SGD":
            return Locale(identifier: "en_SG")
        case "HKD":
            return Locale(identifier: "zh_HK")
        case "NZD":
            return Locale(identifier: "en_NZ")
        case "ZAR":
            return Locale(identifier: "en_ZA")
        default:
            return Locale(identifier: "en_US") // USD default
        }
    }
    
    // Get currency symbol
    private func getCurrencySymbol(_ currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        case "CHF": return "CHF"
        case "CNY": return "¥"
        case "INR": return "₹"
        case "BRL": return "R$"
        case "MXN": return "MX$"
        case "SGD": return "S$"
        case "HKD": return "HK$"
        case "NZD": return "NZ$"
        case "ZAR": return "R"
        default: return "$"
        }
    }
    
    // Send a quick AI response without full chat flow
    private func sendAIResponse(_ responseText: String) async {
        // Create conversation if needed
        var conversationId = currentConversationId
        if conversationId == nil {
            do {
                conversationId = try await createConversation(title: "New Conversation")
            } catch {
                print("[ChatViewModel] Error creating conversation for AI response: \(error.localizedDescription)")
            }
        }
        
        let assistantMessage = ChatMessage(
            role: "assistant",
            content: responseText
        )
        
        await MainActor.run {
            messages.append(assistantMessage)
            isLoading = false
        }
        
        // Save assistant message if we have a conversation
        if let convId = conversationId {
            await saveMessage(assistantMessage, conversationId: convId)
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
                let lowercased = messageText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if user is initiating "Add income" or "Add expense"
                if lowercased == "add income" || lowercased == "addincome" {
                    pendingTransactionType = "income"
                    
                    // Create conversation if needed and save user message
                    var conversationId = currentConversationId
                    if conversationId == nil {
                        do {
                            conversationId = try await createConversation(title: "New Conversation")
                        } catch {
                            print("[ChatViewModel] Error creating conversation: \(error.localizedDescription)")
                        }
                    }
                    if let convId = conversationId {
                        await saveMessage(userMessage, conversationId: convId)
                    }
                    
                    // Send message to AI asking for amount
                    await sendAIResponse("I'd be happy to help you add income! Please enter the amount you'd like to add.")
                    return
                } else if lowercased == "add expense" || lowercased == "addexpense" {
                    pendingTransactionType = "expense"
                    
                    // Create conversation if needed and save user message
                    var conversationId = currentConversationId
                    if conversationId == nil {
                        do {
                            conversationId = try await createConversation(title: "New Conversation")
                        } catch {
                            print("[ChatViewModel] Error creating conversation: \(error.localizedDescription)")
                        }
                    }
                    if let convId = conversationId {
                        await saveMessage(userMessage, conversationId: convId)
                    }
                    
                    // Send message to AI asking for amount
                    await sendAIResponse("I'd be happy to help you add an expense! Please enter the amount you'd like to add.")
                    return
                }
                
                // If we're waiting for transaction amount, try to parse it
                if let pendingType = pendingTransactionType {
                    // Create conversation if needed and save user message
                    var conversationId = currentConversationId
                    if conversationId == nil {
                        do {
                            conversationId = try await createConversation(title: "New Conversation")
                        } catch {
                            print("[ChatViewModel] Error creating conversation: \(error.localizedDescription)")
                        }
                    }
                    if let convId = conversationId {
                        await saveMessage(userMessage, conversationId: convId)
                    }
                    
                    // Try to extract amount from the message
                    if let amount = extractAmount(from: messageText) {
                        // Detect currency from user input
                        let detectedCurrency = detectCurrency(from: messageText)
                        let currencyToUse = detectedCurrency ?? (UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD")
                        
                        // User provided an amount - save the transaction
                        let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
                        do {
                            let savedTransaction = try await networkService.createTransaction(
                                userId: currentUserId,
                                type: pendingType,
                                amount: amount,
                                category: nil,
                                description: messageText,
                                date: nil
                            )
                        print("[ChatViewModel] Transaction saved successfully: \(savedTransaction.id)")
                        
                        // Record transaction added for reminder tracking
                        NotificationService.shared.recordTransactionAdded()
                        
                        // Notify FinanceViewModel to refresh
                        NotificationCenter.default.post(name: NSNotification.Name("TransactionAdded"), object: nil)
                            
                            // Clear pending transaction
                            pendingTransactionType = nil
                            
                            // Send confirmation with correct currency
                            await sendAIResponse("Got it! I've noted your \(formatCurrency(amount, currencyCode: currencyToUse)) \(pendingType == "income" ? "income" : "expense").")
                            return
                        } catch {
                            print("[ChatViewModel] Error saving transaction: \(error.localizedDescription)")
                            pendingTransactionType = nil
                            await sendAIResponse("I encountered an error saving that transaction. Could you try again?")
                            return
                        }
                    } else {
                        // Amount not found - ask again
                        await sendAIResponse("I couldn't find an amount in your message. Please enter the amount (e.g., $100 or 100).")
                        return
                    }
                }
                
                // Try to parse transaction from user message (only if not in pending state)
                if let transaction = parseTransaction(from: messageText) {
                    let currencyToUse = transaction.currency ?? (UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD")
                    print("[ChatViewModel] Detected transaction: \(transaction.type) - \(formatCurrency(transaction.amount, currencyCode: currencyToUse))")
                    
                    // Create conversation if needed
                    var conversationId = currentConversationId
                    if conversationId == nil {
                        do {
                            conversationId = try await createConversation(title: "New Conversation")
                        } catch {
                            print("[ChatViewModel] Error creating conversation: \(error.localizedDescription)")
                        }
                    }
                    
                    // Save user message first
                    if let convId = conversationId {
                        await saveMessage(userMessage, conversationId: convId)
                    }
                    
                    // Save transaction to database
                    let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
                    do {
                        let savedTransaction = try await networkService.createTransaction(
                            userId: currentUserId,
                            type: transaction.type,
                            amount: transaction.amount,
                            category: transaction.category,
                            description: transaction.description,
                            date: nil
                        )
                        print("[ChatViewModel] Transaction saved successfully: \(savedTransaction.id)")
                        
                        // Record transaction added for reminder tracking
                        NotificationService.shared.recordTransactionAdded()
                        
                        // Notify FinanceViewModel to refresh
                        NotificationCenter.default.post(name: NSNotification.Name("TransactionAdded"), object: nil)
                        
                        // Send confirmation with correct currency
                        let confirmationMessage = "Got it! I've noted your \(formatCurrency(transaction.amount, currencyCode: currencyToUse)) \(transaction.type)."
                        await sendAIResponse(confirmationMessage)
                        
                        // Return early - transaction handled, don't send to AI backend
                        await MainActor.run {
                            isLoading = false
                        }
                        return
                    } catch {
                        print("[ChatViewModel] Error saving transaction: \(error.localizedDescription)")
                        // Continue with chat even if transaction save fails
                    }
                }
                
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
                    content: response.response,
                    targetId: response.targetId, // Include target ID if one was created
                    targetType: response.targetType, // Include target type (savings or budget)
                    category: response.category // Include category for budget targets
                )
                
                // If a target was created, notify FinanceViewModel to refresh
                if let targetId = response.targetId {
                    print("[ChatViewModel] Target created with ID: \(targetId), type: \(response.targetType ?? "unknown")")
                    NotificationCenter.default.post(name: NSNotification.Name("TargetCreated"), object: targetId)
                    
                    // Also notify if multiple budget targets were created
                    if let budgetTargetIds = response.budgetTargetIds, budgetTargetIds.count > 1 {
                        print("[ChatViewModel] Multiple budget targets created: \(budgetTargetIds.count)")
                        for budgetTargetId in budgetTargetIds {
                            NotificationCenter.default.post(name: NSNotification.Name("TargetCreated"), object: budgetTargetId)
                        }
                    }
                }
                
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

