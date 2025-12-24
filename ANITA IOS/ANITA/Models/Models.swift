//
//  Models.swift
//  ANITA
//
//  Data models for API requests and responses
//

import Foundation

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, role: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

struct ChatCompletionRequest: Codable {
    let messages: [ChatMessageRequest]
    let maxTokens: Int?
    let temperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case maxTokens = "maxTokens"
        case temperature
    }
}

struct ChatMessageRequest: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let response: String
    let requestId: String?
}

struct APIError: Codable {
    let error: String
    let message: String?
    let requestId: String?
}

// MARK: - Transcription Models

struct TranscribeRequest: Codable {
    let audioFileUrl: String
    let conversationId: String
    let userId: String
}

struct TranscribeResponse: Codable {
    let success: Bool
    let transcript: String?
    let aiResponse: String?
    let requestId: String?
    let error: String?
    let message: String?
}

// MARK: - File Analysis Models

struct AnalyzeFileRequest: Codable {
    let textContent: String
    let fileName: String
    let fileType: String
    let userId: String
    let options: [String: String]?
}

struct Transaction: Codable {
    let date: String?
    let description: String?
    let amount: Double?
    let type: String? // "income" or "expense"
    let category: String?
}

struct FileAnalysisData: Codable {
    let summary: String?
    let transactions: [Transaction]?
    let totalIncome: Double?
    let totalExpenses: Double?
    let confidence: Double?
}

struct AnalyzeFileResponse: Codable {
    let success: Bool
    let data: FileAnalysisData?
    let analysisId: String?
    let confidence: Double?
    let requestId: String?
    let error: String?
}

// MARK: - Checkout Models

struct CreateCheckoutRequest: Codable {
    let plan: String // "pro" or "ultimate"
    let userId: String
    let userEmail: String?
}

struct CreateCheckoutResponse: Codable {
    let sessionId: String?
    let url: String?
    let requestId: String?
    let error: String?
}

// MARK: - Health Check Models

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let service: String
    let version: String
}

struct PrivacyResponse: Codable {
    let privacyPolicy: String
    let dataCollection: String
    let dataUsage: String
    let dataSharing: String
    let contact: String
}

