//
//  ChatViewModel.swift
//  ANITA
//
//  ViewModel for chat functionality with conversation persistence
//

import Foundation
import Network
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    @Published var currentConversationId: String?
    @Published var conversations: [Conversation] = []
    /// When true, ChatView should present UpgradeView (e.g. free user requested premium-only feature; backend returned paywall).
    @Published var showPaywallForLimitReached = false
    
    /// Stable id for the local-first welcome bubble so we persist it once when the user sends their first message.
    static let welcomeGreetingMessageId = "anita-local-welcome-greeting"
    
    /// Shown as a static headline above the typewriter hook (quick-start only).
    @Published var welcomeTypewriterLead: String = ""
    /// Body typed out under the lead; full `ChatMessage.content` is lead + hook for copy and API.
    @Published var welcomeHookBody: String = ""
    
    private static let welcomeHookLastIndexKey = "anita_chat_welcome_hook_last_index"
    private static let welcomeHookCount = 10
    
    /// Fallback when assistant response is empty or fails validation (difficult context / malformed).
    private static let invalidResponseFallbackMessages: [String] = [
        "I got a bit confused there. Try again with something like \"add expense 50 for groceries\" or \"how's my budget?\" — I'll get it next time! 💡",
        "My reply got lost in translation. Ask me to add a transaction, set a goal, or show your budget and we're good! ✨",
        "Oops — that response didn't come out right. Try \"add income\" or \"set a limit\" and I'll respond properly! 🦉",
    ]
    
    /// Finance-themed, funny + friendly fallbacks when connection is bad or missing.
    private static let connectionFallbackMessages: [String] = [
        "No connection again—maybe time to check if that internet bill is actually doing its job? 📶💸 Try again when you’re back online!",
        "I can’t reach you right now. Your Wi‑Fi might be on a coffee break (or we should look at that bill together later). Try again! ☕📡",
        "Connection’s being shy. When it’s back, we can even chat about saving on your next internet bill—try again in a sec! 💡",
        "Signal’s gone AWOL. Come back when you’re connected and we’ll pick up right where we left off (and maybe trim that internet budget). 📴✨",
        "Your message didn’t make it through—connection’s napping. Better signal, then resend; I’ll be here counting the savings with you! 😴💰"
    ]
    
    /// True when the error is due to network/connection (no internet, timeout, unreachable). Check this before treating as auth.
    private static func isConnectionError(_ errorDesc: String) -> Bool {
        let lower = errorDesc.lowercased()
        return lower.contains("timed out") || lower.contains("timeout")
            || lower.contains("cannot find host") || lower.contains("cannot connect")
            || lower.contains("no internet connection") || lower.contains("offline")
            || lower.contains("the internet connection appears to be offline")
            || lower.contains("could not connect") || lower.contains("network error")
    }
    
    /// Prefix the AI must use when responding with a premium paywall (so we can show upgrade sheet). Strip before displaying.
    private static let premiumResponsePrefix = "[PREMIUM]"
    
    /// Free tier: substring match — spending / balance / history questions need bank-linked data (Premium).
    private static func messageRequestsBankLinkedInsights(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["spend", "balance", "history"].contains { lower.contains($0) }
    }
    
    /// Thread-safe "run once" for path monitor callback (Swift 6 concurrency).
    private final class OnceResume {
        private let lock = NSLock()
        private var didResume = false
        func runIfFirst(_ block: () -> Void) {
            lock.lock()
            defer { lock.unlock() }
            guard !didResume else { return }
            didResume = true
            block()
        }
    }
    
    /// Returns true if the device has a network path (Wi‑Fi or cellular). Use before health check so we show connection fallback when offline instead of auth.
    private static func hasDeviceNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = OnceResume()
            monitor.pathUpdateHandler = { path in
                once.runIfFirst {
                    monitor.cancel()
                    continuation.resume(returning: path.status == .satisfied)
                }
            }
            monitor.start(queue: DispatchQueue.global(qos: .userInitiated))
        }
    }
    
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
    
    /// Local assistant greeting when the chat is empty (no API call; not gated on AI consent).
    func ensureWelcomeGreetingIfNeeded() {
        guard userManager.isAuthenticated else { return }
        guard messages.isEmpty else { return }
        let lead = Self.makeWelcomeLead(userManager: userManager)
        let hookIndex = Self.pickWelcomeHookIndexDiverse()
        let hook = AppL10n.t("chat.welcome_hook_\(hookIndex)")
        welcomeTypewriterLead = lead
        welcomeHookBody = hook
        let full = lead + hook
        let greeting = ChatMessage(id: Self.welcomeGreetingMessageId, role: "assistant", content: full)
        messages = [greeting]
    }
    
    private static func makeWelcomeLead(userManager: UserManager) -> String {
        let profileName = userManager.getProfileName()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let onboardingName = OnboardingSurveyResponse.loadFromUserDefaults(userId: userManager.userId)?.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (profileName?.isEmpty == false ? profileName : nil) ?? (onboardingName?.isEmpty == false ? onboardingName : nil)
        if let name {
            return String(format: AppL10n.t("chat.greeting_opening_named"), name)
        }
        return AppL10n.t("chat.greeting_opening")
    }
    
    /// New random hook each time the empty-state welcome is shown (new chat, empty thread, etc.), avoiding immediate repeat.
    private static func pickWelcomeHookIndexDiverse() -> Int {
        let hasLast = UserDefaults.standard.object(forKey: welcomeHookLastIndexKey) != nil
        let last = hasLast ? UserDefaults.standard.integer(forKey: welcomeHookLastIndexKey) : -1
        var picked = Int.random(in: 0..<welcomeHookCount)
        var guardCount = 0
        while picked == last && welcomeHookCount > 1 && guardCount < 32 {
            picked = Int.random(in: 0..<welcomeHookCount)
            guardCount += 1
        }
        UserDefaults.standard.set(picked, forKey: welcomeHookLastIndexKey)
        return picked
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
                welcomeTypewriterLead = ""
                welcomeHookBody = ""
                messages = loadedMessages
                currentConversationId = conversationId
                print("[ChatViewModel] Updated messages array with \(messages.count) messages")
                if loadedMessages.isEmpty {
                    ensureWelcomeGreetingIfNeeded()
                }
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
            // 5 XP for sending at least one chat message today (once per day)
            if message.role == "user" {
                do {
                    let xpResponse = try await networkService.awardXP(userId: currentUserId, ruleId: "daily_chat_message")
                    if xpResponse.success && xpResponse.xpAwarded > 0 {
                        print("[ChatViewModel] XP awarded: +\(xpResponse.xpAwarded) XP")
                    } else if !xpResponse.success {
                        print("[ChatViewModel] XP not awarded (e.g. already awarded today): \(xpResponse.message ?? "")")
                    }
                    // Update shared XP store so Finance tab and Sidebar show new total immediately
                    if xpResponse.success {
                        await XPStore.shared.refresh()
                    }
                } catch {
                    print("[ChatViewModel] XP award failed: \(error.localizedDescription)")
                }
            }
        } catch {
            print("[ChatViewModel] Error saving message: \(error.localizedDescription)")
            // Don't throw - message is already displayed, saving is secondary
        }
    }
    
    // MARK: - Assistant response verification (difficult context)
    
    /// Validates and sanitizes the assistant response before showing to the user.
    /// Ensures we never display empty content or internal markers (e.g. [END], [P1]).
    /// Returns the content to display, or a friendly fallback if invalid.
    private func validateAndSanitizeAssistantResponse(_ content: String?) -> String {
        guard var text = content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return Self.invalidResponseFallbackMessages.randomElement() ?? Self.invalidResponseFallbackMessages[0]
        }
        // Strip trailing internal markers that might slip through
        let markerPatterns = ["[END]", "[P1]", "[P2]", "[P3]", "[P4]", "[P5]", "[P6]"]
        for marker in markerPatterns {
            if text.hasSuffix(marker) {
                text = text.dropLast(marker.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard !text.isEmpty else {
            return Self.invalidResponseFallbackMessages.randomElement() ?? Self.invalidResponseFallbackMessages[0]
        }
        return text
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
        
        // Prefer amount the user actually paid (e.g. "payed 55,08" or "55,08 for it") over other numbers (e.g. "3" from "every 3 month")
        var amountString: String?
        let paidPatterns = [
            #"(?:payed|paid|cost|spent)\s+(\d+(?:[.,]\d{2})?)"#,
            #"(\d+(?:[.,]\d{2})?)\s*(?:€|eur|euros?|\$|usd|dollars?|£|gbp)?\s*(?:for\s+it|for\s+that)"#,
            #"(?:amount|total)\s+(?:of\s+)?(\d+(?:[.,]\d{2})?)"#
        ]
        for pattern in paidPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let amountRange = Range(match.range(at: 1), in: text) {
                amountString = String(text[amountRange])
                break
            }
        }
        // Fallback: numbers with decimal (55,08 or 55.50) — take the largest as the main amount
        if amountString == nil {
            let decimalPattern = #"\b(\d{1,6}[.,]\d{2})\b"#
            if let regex = try? NSRegularExpression(pattern: decimalPattern, options: []) {
                let range = NSRange(location: 0, length: text.utf16.count)
                let matches = regex.matches(in: text, options: [], range: range)
                var candidates: [Double] = []
                for match in matches {
                    guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) else { continue }
                    let s = String(text[r]).replacingOccurrences(of: ",", with: ".")
                    if let n = Double(s), n > 0 { candidates.append(n) }
                }
                if let maxAmount = candidates.max(), maxAmount > 0 { amountString = String(format: "%.2f", maxAmount) }
            }
        }
        // Last resort: first number (with or without thousands/decimal)
        if amountString == nil {
            let amountPatterns = [
                #"\$?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?)"#,
                #"\$?\s*(\d+(?:[.,]\d{2})?)"#
            ]
            for pattern in amountPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
                   match.numberOfRanges > 1,
                   let amountRange = Range(match.range(at: 1), in: text) {
                    amountString = String(text[amountRange])
                    break
                }
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
    
    /// True when the message is a quick-add / natural-language manual transaction the user should not send while bank sync is active.
    private func userIntendsManualTransactionEntry(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        if trimmed.caseInsensitiveCompare(AppL10n.t("chat.add_income")) == .orderedSame { return true }
        if trimmed.caseInsensitiveCompare(AppL10n.t("chat.add_expense")) == .orderedSame { return true }
        if trimmed.caseInsensitiveCompare(AppL10n.t("finance.add_transaction")) == .orderedSame { return true }
        let manualPrefixes = [
            "add income", "add expense", "add an expense", "add a expense",
            "log expense", "log income", "record expense", "record income",
            "einkommen hinzufügen", "ausgabe hinzufügen", "transaktion hinzufügen"
        ]
        for p in manualPrefixes where lower == p || lower.hasPrefix(p + " ") || lower.hasPrefix(p + ",") {
            return true
        }
        return parseTransaction(from: trimmed) != nil
    }
    
    // Extract just the amount from a message (simpler version for pending transactions). Prefers amount user paid (e.g. "payed 55,08") over other numbers (e.g. "3" from "every 3 month").
    private func extractAmount(from text: String) -> Double? {
        // Prefer: "payed 55,08", "55,08 for it", then largest decimal amount, then first number
        let paidPatterns = [
            #"(?:payed|paid|cost|spent)\s+(\d+(?:[.,]\d{2})?)"#,
            #"(\d+(?:[.,]\d{2})?)\s*(?:€|eur|euros?|\$|usd|dollars?|£|gbp)?\s*(?:for\s+it|for\s+that)"#,
            #"(?:amount|total)\s+(?:of\s+)?(\d+(?:[.,]\d{2})?)"#
        ]
        for pattern in paidPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let amountRange = Range(match.range(at: 1), in: text) {
                let s = String(text[amountRange]).replacingOccurrences(of: ",", with: ".")
                if let n = Double(s), n > 0 { return n }
            }
        }
        let decimalPattern = #"\b(\d{1,6}[.,]\d{2})\b"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern, options: []) {
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = regex.matches(in: text, options: [], range: range)
            var candidates: [Double] = []
            for match in matches {
                guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) else { continue }
                let s = String(text[r]).replacingOccurrences(of: ",", with: ".")
                if let n = Double(s), n > 0 { candidates.append(n) }
            }
            if let maxAmount = candidates.max(), maxAmount > 0 { return maxAmount }
        }
        let amountPatterns = [#"\$?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?)"#, #"\$?\s*(\d+(?:[.,]\d{2})?)"#]
        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let amountRange = Range(match.range(at: 1), in: text) {
                var amountString = String(text[amountRange])
                if amountString.contains(",") && !amountString.contains(".") {
                    let parts = amountString.split(separator: ",")
                    if parts.count == 2 && parts[0].count >= 3 { amountString = amountString.replacingOccurrences(of: ",", with: "") }
                    else { amountString = amountString.replacingOccurrences(of: ",", with: ".") }
                } else if amountString.contains(",") { amountString = amountString.replacingOccurrences(of: ",", with: "") }
                if let n = Double(amountString), n > 0 { return n }
            }
        }
        return nil
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
        
        let displayContent = validateAndSanitizeAssistantResponse(responseText)
        let assistantMessage = ChatMessage(
            role: "assistant",
            content: displayContent
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
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if userManager.blocksManualTransactions, userIntendsManualTransactionEntry(messageText) {
            let userMessage = ChatMessage(role: "user", content: messageText)
            messages.append(userMessage)
            inputText = ""
            isLoading = true
            errorMessage = nil
            Task {
                var conversationId = currentConversationId
                let didCreateConversation = conversationId == nil
                if conversationId == nil {
                    do {
                        let title = messageText.count > 50 ? String(messageText.prefix(50)) + "..." : messageText
                        conversationId = try await createConversation(title: title)
                    } catch {
                        print("[ChatViewModel] Bank-block reply: conversation create failed: \(error.localizedDescription)")
                        await MainActor.run {
                            let assistantMessage = ChatMessage(
                                role: "assistant",
                                content: validateAndSanitizeAssistantResponse(AppL10n.t("chat.bank_blocks_manual_transaction"))
                            )
                            messages.append(assistantMessage)
                            isLoading = false
                        }
                        return
                    }
                }
                guard let convId = conversationId else {
                    await MainActor.run {
                        let assistantMessage = ChatMessage(
                            role: "assistant",
                            content: validateAndSanitizeAssistantResponse(AppL10n.t("chat.bank_blocks_manual_transaction"))
                        )
                        messages.append(assistantMessage)
                        isLoading = false
                    }
                    return
                }
                if didCreateConversation,
                   let welcome = messages.first(where: { $0.id == Self.welcomeGreetingMessageId }) {
                    await saveMessage(welcome, conversationId: convId)
                }
                await saveMessage(userMessage, conversationId: convId)
                await sendAIResponse(AppL10n.t("chat.bank_blocks_manual_transaction"))
                if let cid = currentConversationId {
                    NotificationCenter.default.post(name: NSNotification.Name("ConversationUpdated"), object: cid)
                }
            }
            return
        }
        
        let userMessage = ChatMessage(role: "user", content: messageText)
        messages.append(userMessage)
        
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Free tier: no message limit — freemium has unlimited chat; premium features (analytics, limits, goals) gated by backend.
                
                // No trigger words: every message is sent to the AI. The AI analyzes the full message and conversation context, interprets intent, and responds (no client-side shortcuts).
                
                // Device has no network (e.g. airplane mode, WiFi off) → show connection fallback so we never show sign-in by mistake
                if !(await Self.hasDeviceNetwork()) {
                    print("[ChatViewModel] No device network path")
                    await MainActor.run {
                        let fallbackText = Self.connectionFallbackMessages.randomElement() ?? Self.connectionFallbackMessages[0]
                        let fallbackMessage = ChatMessage(role: "assistant", content: fallbackText)
                        messages.append(fallbackMessage)
                        isLoading = false
                        errorMessage = nil
                    }
                    return
                }
                
                // First, check backend connection
                print("[ChatViewModel] Checking backend connection...")
                do {
                    _ = try await networkService.checkHealth()
                    print("[ChatViewModel] Backend connection OK")
                } catch {
                    print("[ChatViewModel] Backend connection failed: \(error.localizedDescription)")
                    await MainActor.run {
                        let fallbackText = Self.connectionFallbackMessages.randomElement() ?? Self.connectionFallbackMessages[0]
                        let fallbackMessage = ChatMessage(role: "assistant", content: fallbackText)
                        messages.append(fallbackMessage)
                        isLoading = false
                        errorMessage = nil
                    }
                    return
                }
                
                // Create conversation if needed
                var conversationId = currentConversationId
                let didCreateConversation = conversationId == nil
                if conversationId == nil {
                    print("[ChatViewModel] Creating new conversation...")
                    let title = messageText.count > 50 ? String(messageText.prefix(50)) + "..." : messageText
                    do {
                        conversationId = try await createConversation(title: title)
                        print("[ChatViewModel] Conversation created: \(conversationId ?? "nil")")
                    } catch {
                        print("[ChatViewModel] Failed to create conversation: \(error.localizedDescription)")
                        let errorDesc = error.localizedDescription
                        // Connection errors first: no internet / timeout must show connection fallback, not sign-in
                        if Self.isConnectionError(errorDesc) {
                            await MainActor.run {
                                let fallbackText = Self.connectionFallbackMessages.randomElement() ?? Self.connectionFallbackMessages[0]
                                let fallbackMessage = ChatMessage(role: "assistant", content: fallbackText)
                                messages.append(fallbackMessage)
                                isLoading = false
                                errorMessage = nil
                            }
                            return
                        }
                        // Then auth errors
                        var userFriendlyError = errorDesc
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
                
                // Save user message (and local welcome bubble first so thread order matches the UI)
                if let convId = conversationId {
                    if didCreateConversation,
                       let welcome = messages.first(where: { $0.id == Self.welcomeGreetingMessageId }) {
                        print("[ChatViewModel] Saving welcome greeting to conversation: \(convId)")
                        await saveMessage(welcome, conversationId: convId)
                    }
                    print("[ChatViewModel] Saving user message to conversation: \(convId)")
                    await saveMessage(userMessage, conversationId: convId)
                }
                
                if !SubscriptionManager.shared.isPremium,
                   Self.messageRequestsBankLinkedInsights(messageText) {
                    let reply = AppL10n.t("chat.premium_bank_data_reply")
                    let assistantMessage = ChatMessage(role: "assistant", content: reply)
                    await MainActor.run {
                        messages.append(assistantMessage)
                        isLoading = false
                        showPaywallForLimitReached = true
                    }
                    if let convId = conversationId {
                        await saveMessage(assistantMessage, conversationId: convId)
                        NotificationCenter.default.post(name: NSNotification.Name("ConversationUpdated"), object: convId)
                    }
                    return
                }
                
                // Convert messages to API format
                var apiMessages = messages.map { msg in
                    ChatMessageRequest(role: msg.role, content: msg.content)
                }
                
                // Inject a system message to enforce onboarding language + personalization (not shown in UI)
                if let systemPrompt = buildSystemPrompt() {
                    apiMessages.insert(ChatMessageRequest(role: "system", content: systemPrompt), at: 0)
                }
                
                print("[ChatViewModel] Sending chat message to backend...")
                // Always use authenticated user ID if available
                let currentUserId = userManager.isAuthenticated ? (userManager.currentUser?.id ?? userId) : userId
                // User display name: source of truth is profile (DB / UserManager), then onboarding
                let profileName = userManager.getProfileName()?.trimmingCharacters(in: .whitespacesAndNewlines)
                let onboardingName = OnboardingSurveyResponse.loadFromUserDefaults(userId: userId)?.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = (profileName?.isEmpty == false ? profileName : nil) ?? (onboardingName?.isEmpty == false ? onboardingName : nil)
                // User's chosen currency (same as Settings/Finance) so the chat uses USD, EUR, CHF, etc.
                let preferredCurrency = UserDefaults.standard.string(forKey: "anita_user_currency")
                let response = try await networkService.sendChatMessage(
                    messages: apiMessages,
                    userId: currentUserId,
                    conversationId: conversationId,
                    userDisplayName: displayName,
                    userCurrency: preferredCurrency,
                    isPremium: SubscriptionManager.shared.isPremium
                )
                print("[ChatViewModel] Received response from backend")
                
                // Strip [PREMIUM] prefix if AI used it (free-tier intent gating); then sanitize
                var responseText = response.response
                var shouldShowPaywall = response.requiresUpgrade == true
                if responseText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix(Self.premiumResponsePrefix.uppercased()) {
                    responseText = String(responseText.dropFirst(Self.premiumResponsePrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    shouldShowPaywall = true
                }
                let displayContent = validateAndSanitizeAssistantResponse(responseText.isEmpty ? nil : responseText)
                
                let assistantMessage = ChatMessage(
                    role: "assistant",
                    content: displayContent,
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
                    if shouldShowPaywall {
                        showPaywallForLimitReached = true
                    }
                }
                
                // When backend persisted a transaction (income/expense via chat), Finance tab should refresh so the new transaction appears
                if response.transactionAdded == true {
                    NotificationCenter.default.post(name: NSNotification.Name("TransactionAdded"), object: nil)
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
                if Self.isConnectionError(errorDesc) {
                    // In-chat fallback: keep user message and reply with a funny connection message
                    await MainActor.run {
                        let fallbackText = Self.connectionFallbackMessages.randomElement() ?? Self.connectionFallbackMessages[0]
                        let fallbackMessage = ChatMessage(role: "assistant", content: fallbackText)
                        messages.append(fallbackMessage)
                        isLoading = false
                        errorMessage = nil
                    }
                } else {
                    // Non-connection errors: show error and restore input
                    var userFriendlyError = errorDesc
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
                        if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                            messages.remove(at: index)
                        }
                        inputText = messageText
                    }
                }
            }
        }
    }

    private func buildSystemPrompt() -> String? {
        let survey = OnboardingSurveyResponse.loadFromUserDefaults(userId: userId)
        // Use app-chosen language (Settings) so AI and paywall messages match what the user sees in the UI.
        let languageCode = AppL10n.currentLanguageCode()
        
        let languageName: String
        switch languageCode {
        case "de": languageName = "German"
        case "es": languageName = "Spanish"
        case "it": languageName = "Italian"
        case "ru": languageName = "Russian"
        case "uk": languageName = "Ukrainian"
        default: languageName = "English"
        }
        
        var lines: [String] = []
        lines.append("You are ANITA, a personal finance assistant.")
        lines.append("Always reply in \(languageName), unless the user explicitly asks for another language. This includes any [PREMIUM] paywall message — it must be in \(languageName) too.")
        
        let profileName = userManager.getProfileName()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let onboardingName = survey?.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let userName = (profileName?.isEmpty == false ? profileName : nil) ?? (onboardingName?.isEmpty == false ? onboardingName : nil)
        if let name = userName {
            lines.append("The user's name is \(name). You may address them by name when appropriate.")
        }
        
        if let answers = survey?.answers, !answers.isEmpty {
            // Lightweight personalization context (IDs, not sensitive personal data)
            let formatted = answers
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            lines.append("Onboarding preferences: \(formatted). Use them to personalize your advice.")
        }
        
        // Free tier: AI must understand the main idea of the user's message and gate premium intents with a funny paywall
        if !SubscriptionManager.shared.isPremium {
            lines.append("")
            lines.append("FREE TIER RULES — The user is on the free plan. You must understand the context and main idea of what they say.")
            lines.append("ALLOWED (respond normally): (1) Adding or logging an expense, in any wording (e.g. \"I bought coffee\", \"spent 20\", \"50 for lunch\"). (2) Adding or logging income, in any wording (e.g. \"got paid\", \"salary\", \"received 500\"). (3) Questions about who you are, what ANITA is, how the app works, or saying hi/help.")
            lines.append("PREMIUM (do not fulfill): Anything else — e.g. analytics, spending breakdown, \"where did my money go\", goals, limits, budgets, reports, charts, comparisons, summaries, insights about their finances. For PREMIUM intents only: respond with a single short, funny message in \(languageName) that this is a premium feature and they can upgrade to use it. Keep it light and on-brand. Your entire response for PREMIUM must start with exactly the tag [PREMIUM] (including the brackets), then a space, then your funny one- or two-sentence message in \(languageName). Do not perform any analysis or action for PREMIUM requests.")
        }
        
        if userManager.blocksManualTransactions {
            lines.append("")
            lines.append("BANK-LINKED MODE — Manual transaction logging is disabled. Do not add, log, or record income or expenses from the user's messages. If they ask to add or log a transaction, briefly explain that transactions come from their bank connection and are not entered manually in the app.")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // Start a new conversation
    func startNewConversation() {
        messages = []
        currentConversationId = nil
        welcomeTypewriterLead = ""
        welcomeHookBody = ""
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

