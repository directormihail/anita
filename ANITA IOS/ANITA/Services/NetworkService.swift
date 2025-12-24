//
//  NetworkService.swift
//  ANITA
//
//  Network service to connect to ANITA backend API
//

import Foundation

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // Base URL - Update this to your backend URL
    private var baseURL: String
    
    private init() {
        // Default to localhost for development, update for production
        if let url = UserDefaults.standard.string(forKey: "backendURL"), !url.isEmpty {
            self.baseURL = url
        } else {
            // Default backend URL - update this to your production URL
            self.baseURL = "http://localhost:3001"
        }
    }
    
    func updateBaseURL(_ url: String) {
        baseURL = url
        UserDefaults.standard.set(url, forKey: "backendURL")
    }
    
    // MARK: - Chat Completion
    
    func sendChatMessage(messages: [ChatMessageRequest], maxTokens: Int = 800, temperature: Double = 0.7) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/api/v1/chat-completion")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            messages: messages,
            maxTokens: maxTokens,
            temperature: temperature
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
        let url = URL(string: "\(baseURL)/health")!
        let request = URLRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(HealthResponse.self, from: data)
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

