//
//  NetworkService.swift
//  ANITA
//
//  Network service to connect to ANITA backend API
//

import Foundation

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    /// Request timeout. Longer so production (e.g. Railway) cold starts don’t cause timeouts.
    private static var requestTimeout: TimeInterval {
        #if DEBUG
        return 25.0
        #else
        return 30.0
        #endif
    }
    
    /// Always use Railway production server. Custom URL in Settings is ignored so the app connects to Railway.
    private var rawBaseURL: String {
        Config.backendURL
    }
    
    /// Normalized base URL: trimmed, no trailing slash, never empty.
    private var baseURL: String {
        let raw = rawBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return Config.backendURL
        }
        return raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    }
    
    private init() {
        let initialURL = baseURL
        print("[NetworkService] Using Railway server: \(initialURL)")
    }
    
    func updateBaseURL(_ url: String) {
        // No-op: app always uses Railway (Config.backendURL). Kept for API compatibility with Settings.
        UserDefaults.standard.set(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "backendURL")
        print("[NetworkService] Backend URL is fixed to Railway: \(Config.backendURL)")
    }
    
    // Helper to get current URL (for debugging/display)
    func getCurrentBaseURL() -> String {
        return baseURL
    }
    
    // MARK: - Chat Completion
    
    func sendChatMessage(messages: [ChatMessageRequest], maxTokens: Int = 800, temperature: Double = 0.7, userId: String? = nil, conversationId: String? = nil, userDisplayName: String? = nil, userCurrency: String? = nil, isPremium: Bool? = nil) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/api/v1/chat-completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature,
            userId: userId,
            conversationId: conversationId,
            userDisplayName: userDisplayName,
            userCurrency: userCurrency,
            isPremium: isPremium
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(ChatCompletionResponse.self, from: data)
        } else {
            // Try to decode error response
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Transcription
    
    func transcribeAudio(audioFileUrl: String, conversationId: String, userId: String) async throws -> TranscribeResponse {
        let url = URL(string: "\(baseURL)/api/v1/transcribe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = TranscribeRequest(
            audioFileUrl: audioFileUrl,
            conversationId: conversationId,
            userId: userId
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(TranscribeResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(TranscribeResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse.error ?? errorResponse.message ?? "Transcription failed")
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - File Analysis
    
    func analyzeFile(textContent: String, fileName: String, fileType: String, userId: String, options: [String: String]? = nil) async throws -> AnalyzeFileResponse {
        let url = URL(string: "\(baseURL)/api/v1/analyze-file")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AnalyzeFileRequest(
            textContent: textContent,
            fileName: fileName,
            fileType: fileType,
            userId: userId,
            options: options
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(AnalyzeFileResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(AnalyzeFileResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse.error ?? "File analysis failed")
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Checkout Session
    
    func createCheckoutSession(plan: String, userId: String, userEmail: String?) async throws -> CreateCheckoutResponse {
        let url = URL(string: "\(baseURL)/api/v1/create-checkout-session")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = CreateCheckoutRequest(
            plan: plan,
            userId: userId,
            userEmail: userEmail
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(CreateCheckoutResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(CreateCheckoutResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse.error ?? "Checkout session creation failed")
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Health Check
    
    func checkHealth() async throws -> HealthResponse {
        let urlString = "\(baseURL)/health"
        guard let url = URL(string: urlString) else {
            print("[NetworkService] ❌ Invalid health check URL: \(urlString)")
            print("[NetworkService] Current baseURL: \(baseURL)")
            throw NetworkError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("[NetworkService] 🔍 Health check request to: \(url.absoluteString)")
        print("[NetworkService] Base URL configured: \(baseURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[NetworkService] ❌ Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            print("[NetworkService] Health check response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                do {
                    let healthResponse = try decoder.decode(HealthResponse.self, from: data)
                    print("[NetworkService] ✅ Health check successful: \(healthResponse.status)")
                    return healthResponse
                } catch {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    print("[NetworkService] ❌ Decode error: \(error)")
                    print("[NetworkService] Response body: \(responseString)")
                    throw NetworkError.decodingError
                }
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("[NetworkService] ❌ Health check failed with status \(httpResponse.statusCode): \(errorString)")
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            print("[NetworkService] ❌ NetworkError: \(error.localizedDescription ?? "Unknown")")
            throw error
        } catch {
            print("[NetworkService] ❌ Network error: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("[NetworkService] URLError code: \(urlError.code.rawValue)")
                switch urlError.code {
                case .notConnectedToInternet:
                    throw NetworkError.apiError("No internet connection. Please check your network settings.")
                case .timedOut:
                    throw NetworkError.apiError("Request timed out. Please check:\n1. Backend is running (cd 'ANITA backend' && npm run dev)\n2. Backend URL is correct in Settings\n3. Device and backend are on same network")
                case .cannotFindHost:
                    throw NetworkError.apiError("Cannot find host. Please check:\n1. Backend URL in Settings is correct\n2. For simulator: http://localhost:3001\n3. For physical device: Use your Mac's IP address (e.g., http://192.168.1.100:3001)")
                case .cannotConnectToHost:
                    throw NetworkError.apiError("Cannot connect to host. Please check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings is correct\n3. Both devices are on the same Wi-Fi network")
                default:
                    throw NetworkError.apiError("Network error: \(urlError.localizedDescription)")
                }
            }
            throw NetworkError.apiError("Could not connect to server: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Privacy Policy
    
    func getPrivacyPolicy() async throws -> PrivacyResponse {
        let url = URL(string: "\(baseURL)/privacy")!
        let request = URLRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(PrivacyResponse.self, from: data)
    }
    
    // MARK: - Terms of Use
    
    func getTermsOfUse() async throws -> TermsResponse {
        let url = URL(string: "\(baseURL)/terms")!
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        let decoder = JSONDecoder()
        return try decoder.decode(TermsResponse.self, from: data)
    }
    
    // MARK: - Transactions
    
    func getTransactions(userId: String, month: Int? = nil, year: Int? = nil) async throws -> GetTransactionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/transactions")!
        var queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: String(month)))
        }
        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GetTransactionsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func createTransaction(userId: String, type: String, amount: Double, category: String?, description: String, date: String?) async throws -> TransactionItem {
        let url = URL(string: "\(baseURL)/api/v1/save-transaction")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct CreateTransactionRequest: Codable {
            let userId: String
            let transactionId: String?
            let type: String
            let amount: Double
            let category: String?
            let description: String
            let date: String?
        }
        
        struct CreateTransactionResponse: Codable {
            let success: Bool
            let transaction: TransactionItem?
            let duplicate: Bool?
            let requestId: String?
            let error: String?
        }
        
        let transactionId = "txn_\(Date().timeIntervalSince1970)_\(UUID().uuidString.prefix(8))"
        let requestBody = CreateTransactionRequest(
            userId: userId,
            transactionId: transactionId,
            type: type,
            amount: amount,
            category: category,
            description: description,
            date: date
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            let createResponse = try decoder.decode(CreateTransactionResponse.self, from: data)
            if createResponse.success, let transaction = createResponse.transaction {
                return transaction
            } else if createResponse.duplicate == true {
                // Duplicate transaction - return the existing one if available, or throw
                throw NetworkError.apiError("Duplicate transaction - already exists")
            } else {
                throw NetworkError.apiError(createResponse.error ?? "Failed to create transaction")
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func updateTransaction(userId: String, transactionId: String, type: String? = nil, amount: Double? = nil, category: String? = nil, description: String? = nil, date: String? = nil) async throws -> UpdateTransactionResponse {
        let url = URL(string: "\(baseURL)/api/v1/update-transaction")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = UpdateTransactionRequest(
            transactionId: transactionId,
            userId: userId,
            type: type,
            amount: amount,
            category: category,
            description: description,
            date: date
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(UpdateTransactionResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func deleteTransaction(userId: String, transactionId: String) async throws -> DeleteTransactionResponse {
        let url = URL(string: "\(baseURL)/api/v1/delete-transaction")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeleteTransactionRequest(
            transactionId: transactionId,
            userId: userId
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(DeleteTransactionResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func clearUserData(userId: String) async throws -> ClearUserDataResponse {
        let url = URL(string: "\(baseURL)/api/v1/clear-user-data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(ClearUserDataResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Conversations
    
    func getConversations(userId: String) async throws -> GetConversationsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/conversations")!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("[NetworkService] Getting conversations from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(GetConversationsResponse.self, from: data)
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            print("[NetworkService] Network error getting conversations: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    throw NetworkError.apiError("No internet connection. Please check your network settings.")
                case .timedOut:
                    throw NetworkError.apiError("Request timed out. Please check:\n1. Backend is running (cd 'ANITA backend' && npm run dev)\n2. Backend URL is correct in Settings\n3. Device and backend are on same network")
                case .cannotFindHost:
                    throw NetworkError.apiError("Could not connect to the server.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings is: http://localhost:3001\n3. For physical device: Use your Mac's IP address (e.g., http://192.168.1.100:3001)")
                case .cannotConnectToHost:
                    throw NetworkError.apiError("Could not connect to the server.\n\nPlease check:\n1. Backend is running: cd 'ANITA backend' && npm run dev\n2. Backend URL in Settings is: http://localhost:3001\n3. For physical device: Use your Mac's IP address (e.g., http://192.168.1.100:3001)")
                default:
                    throw NetworkError.apiError("Network error: \(urlError.localizedDescription)")
                }
            }
            throw NetworkError.apiError("Could not connect to the server. \(error.localizedDescription)")
        }
    }
    
    // MARK: - Financial Metrics
    
    func getFinancialMetrics(userId: String, month: Int? = nil, year: Int? = nil) async throws -> GetFinancialMetricsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/financial-metrics")!
        var queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: String(month)))
        }
        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(GetFinancialMetricsResponse.self, from: data)
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    throw NetworkError.apiError("No internet connection. Please check your network settings.")
                case .timedOut:
                    throw NetworkError.apiError("Request timed out. Please check if backend is running.")
                case .cannotFindHost, .cannotConnectToHost:
                    throw NetworkError.apiError("Could not connect to the server. Please check backend URL in Settings.")
                default:
                    throw NetworkError.apiError("Network error: \(urlError.localizedDescription)")
                }
            }
            throw NetworkError.apiError("Could not connect to the server. \(error.localizedDescription)")
        }
    }
    
    // MARK: - XP Stats
    
    func getXPStats(userId: String) async throws -> GetXPStatsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/xp-stats")!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(GetXPStatsResponse.self, from: data)
            } else {
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    throw NetworkError.apiError("No internet connection. Please check your network settings.")
                case .timedOut:
                    throw NetworkError.apiError("Request timed out. Please check if backend is running.")
                case .cannotFindHost, .cannotConnectToHost:
                    throw NetworkError.apiError("Could not connect to the server. Please check backend URL in Settings.")
                default:
                    throw NetworkError.apiError("Network error: \(urlError.localizedDescription)")
                }
            }
            throw NetworkError.apiError("Could not connect to the server. \(error.localizedDescription)")
        }
    }
    
    func awardXP(userId: String, ruleId: String, metadata: [String: String]? = nil) async throws -> AwardXPResponse {
        let url = URL(string: "\(baseURL)/api/v1/xp-award")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.requestTimeout
        let body: [String: Any] = [
            "userId": userId,
            "ruleId": ruleId,
            "metadata": metadata ?? [:]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(AwardXPResponse.self, from: data)
        }
        if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
            throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
        }
        throw NetworkError.httpError(httpResponse.statusCode)
    }
    
    func appOpen(userId: String) async throws -> AppOpenResponse {
        let url = URL(string: "\(baseURL)/api/v1/app-open")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.requestTimeout
        request.httpBody = try JSONEncoder().encode(AppOpenRequest(userId: userId))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(AppOpenResponse.self, from: data)
        }
        if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
            throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
        }
        throw NetworkError.httpError(httpResponse.statusCode)
    }
    
    // MARK: - Targets
    
    func getTargets(userId: String) async throws -> GetTargetsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/targets")!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GetTargetsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func createTarget(userId: String, title: String, description: String?, targetAmount: Double, currentAmount: Double? = nil, currency: String? = nil, targetDate: String? = nil, targetType: String? = nil, category: String? = nil, priority: String? = nil) async throws -> Target {
        let url = URL(string: "\(baseURL)/api/v1/create-target")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = CreateTargetRequest(
            userId: userId,
            title: title,
            description: description,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            currency: currency,
            targetDate: targetDate,
            targetType: targetType,
            category: category,
            priority: priority
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            let createResponse = try decoder.decode(CreateTargetResponse.self, from: data)
            if createResponse.success {
                return createResponse.target
            } else {
                throw NetworkError.apiError("Failed to create target")
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func updateTarget(userId: String, targetId: String, targetAmount: Double? = nil, currentAmount: Double? = nil, title: String? = nil, description: String? = nil, targetDate: String? = nil, status: String? = nil, priority: String? = nil) async throws -> UpdateTargetResponse {
        let url = URL(string: "\(baseURL)/api/v1/update-target")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = UpdateTargetRequest(
            targetId: targetId,
            userId: userId,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            title: title,
            description: description,
            targetDate: targetDate,
            status: status,
            priority: priority
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(UpdateTargetResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func deleteTarget(userId: String, targetId: String) async throws -> DeleteTargetResponse {
        let url = URL(string: "\(baseURL)/api/v1/delete-target")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeleteTargetRequest(
            targetId: targetId,
            userId: userId
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(DeleteTargetResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Conversations
    
    func createConversation(userId: String, title: String) async throws -> CreateConversationResponse {
        let url = URL(string: "\(baseURL)/api/v1/create-conversation")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = CreateConversationRequest(userId: userId, title: title)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(CreateConversationResponse.self, from: data)
        } else {
            // Try to decode error response
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[NetworkService] Create conversation error: \(errorString)")
            
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                // error is non-optional String, message is optional String?
                let errorMessage = errorResponse.message ?? errorResponse.error
                // Check for foreign key constraint errors
                if errorMessage.contains("foreign key") || errorMessage.contains("User not found") || errorMessage.contains("does not exist") {
                    throw NetworkError.apiError("User not found. Please sign in or sign up first. Go to Settings to authenticate.")
                }
                throw NetworkError.apiError(errorMessage)
            }
            
            // If we can't decode the error, check the raw string
            if errorString.contains("foreign key") || errorString.contains("conversations_user_id_fkey") {
                throw NetworkError.apiError("User not found. Please sign in or sign up first. Go to Settings to authenticate.")
            }
            
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Messages
    
    func getMessages(conversationId: String, userId: String) async throws -> GetMessagesResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/messages")!
        urlComponents.queryItems = [
            URLQueryItem(name: "conversationId", value: conversationId),
            URLQueryItem(name: "userId", value: userId)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GetMessagesResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func saveMessage(userId: String, conversationId: String, messageId: String, messageText: String, sender: String) async throws -> SaveMessageResponse {
        let url = URL(string: "\(baseURL)/api/v1/save-message")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SaveMessageRequest(
            userId: userId,
            conversationId: conversationId,
            messageId: messageId,
            messageText: messageText,
            sender: sender
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SaveMessageResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Support
    
    func submitSupport(userId: String, subject: String?, message: String) async throws -> SubmitSupportResponse {
        let url = URL(string: "\(baseURL)/api/v1/support")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "userId": userId,
            "subject": subject ?? NSNull(),
            "message": message
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(err.message ?? err.error)
            }
            throw NetworkError.apiError("Could not reach server. Check backend URL in Settings and that the server is running.")
        }
        return try JSONDecoder().decode(SubmitSupportResponse.self, from: data)
    }
    
    // MARK: - Feedback
    
    func submitFeedback(userId: String, message: String?, rating: Int?) async throws -> SubmitFeedbackResponse {
        let url = URL(string: "\(baseURL)/api/v1/feedback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["userId": userId]
        if let m = message, !m.isEmpty { body["message"] = m }
        if let r = rating { body["rating"] = r }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let err = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(err.message ?? err.error)
            }
            throw NetworkError.apiError("Could not reach server. Check backend URL in Settings and that the server is running.")
        }
        return try JSONDecoder().decode(SubmitFeedbackResponse.self, from: data)
    }
    
    // MARK: - Message Feedback
    
    func saveMessageFeedback(userId: String, messageId: String, conversationId: String?, feedbackType: String) async throws -> SaveMessageFeedbackResponse {
        let url = URL(string: "\(baseURL)/api/v1/save-message-feedback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SaveMessageFeedbackRequest(
            userId: userId,
            messageId: messageId,
            conversationId: conversationId,
            feedbackType: feedbackType
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(SaveMessageFeedbackResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Assets
    
    func getAssets(userId: String) async throws -> GetAssetsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/assets")!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GetAssetsResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func updateAsset(userId: String, assetId: String, currentValue: Double? = nil, name: String? = nil, type: String? = nil, description: String? = nil) async throws -> UpdateAssetResponse {
        let url = URL(string: "\(baseURL)/api/v1/update-asset")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = UpdateAssetRequest(
            assetId: assetId,
            userId: userId,
            currentValue: currentValue,
            name: name,
            type: type,
            description: description
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(UpdateAssetResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func deleteAsset(userId: String, assetId: String) async throws -> DeleteAssetResponse {
        let url = URL(string: "\(baseURL)/api/v1/delete-asset")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeleteAssetRequest(
            assetId: assetId,
            userId: userId
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(DeleteAssetResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    func createAsset(userId: String, name: String, type: String, currentValue: Double, description: String?) async throws -> Asset {
        let url = URL(string: "\(baseURL)/api/v1/assets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct CreateAssetRequest: Codable {
            let userId: String
            let name: String
            let type: String
            let currentValue: Double
            let description: String?
        }
        
        struct CreateAssetResponse: Codable {
            let success: Bool
            let asset: Asset
            let requestId: String?
            let error: String?
        }
        
        let requestBody = CreateAssetRequest(
            userId: userId,
            name: name,
            type: type,
            currentValue: currentValue,
            description: description
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let decoder = JSONDecoder()
            let createResponse = try decoder.decode(CreateAssetResponse.self, from: data)
            if createResponse.success {
                return createResponse.asset
            } else {
                throw NetworkError.apiError(createResponse.error ?? "Failed to create asset")
            }
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Subscription
    
    func getSubscription(userId: String) async throws -> GetSubscriptionResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/subscription")!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidResponse
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            return try decoder.decode(GetSubscriptionResponse.self, from: data)
        } else {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NetworkError.apiError(errorResponse.message ?? errorResponse.error)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

