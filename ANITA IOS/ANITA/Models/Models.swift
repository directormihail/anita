//
//  Models.swift
//  ANITA
//
//  Data models for API requests and responses
//

import Foundation
import SwiftUI

// MARK: - Chat Models

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    var feedbackType: String? // "like" or "dislike"
    
    init(id: String = UUID().uuidString, role: String, content: String, timestamp: Date = Date(), feedbackType: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.feedbackType = feedbackType
    }
}

struct ChatCompletionRequest: Codable {
    let messages: [ChatMessageRequest]
    let maxTokens: Int?
    let temperature: Double?
    let userId: String?
    let conversationId: String?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case maxTokens = "maxTokens"
        case temperature
        case userId
        case conversationId
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

// MARK: - Financial Data Models

struct TransactionItem: Identifiable, Codable {
    let id: String
    let type: String // "income" or "expense"
    let amount: Double
    let category: String
    let description: String
    let date: String // ISO date string
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case amount
        case category
        case description
        case date
    }
}

struct GetTransactionsResponse: Codable {
    let success: Bool
    let transactions: [TransactionItem]
    let requestId: String?
}

// MARK: - Conversation Models

struct Conversation: Codable {
    let id: String
    let user_id: String
    let title: String?
    let created_at: String
    let updated_at: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case created_at
        case updated_at
    }
}

struct GetConversationsResponse: Codable {
    let success: Bool
    let conversations: [Conversation]
    let requestId: String?
}

// MARK: - Financial Metrics Models

struct FinancialMetrics: Codable {
    let totalBalance: Double
    let totalIncome: Double
    let totalExpenses: Double
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let monthlyBalance: Double
    
    enum CodingKeys: String, CodingKey {
        case totalBalance
        case totalIncome
        case totalExpenses
        case monthlyIncome
        case monthlyExpenses
        case monthlyBalance
    }
}

struct GetFinancialMetricsResponse: Codable {
    let success: Bool
    let metrics: FinancialMetrics
    let requestId: String?
}

// MARK: - XP Stats Models

struct XPStats: Codable {
    let total_xp: Int
    let current_level: Int
    let xp_to_next_level: Int
    let level_progress_percentage: Int
    let level_title: String
    let level_description: String
    let level_emoji: String
    
    enum CodingKeys: String, CodingKey {
        case total_xp
        case current_level
        case xp_to_next_level
        case level_progress_percentage
        case level_title
        case level_description
        case level_emoji
    }
}

struct GetXPStatsResponse: Codable {
    let success: Bool
    let xpStats: XPStats
    let requestId: String?
}

// MARK: - Category Analytics Models

struct CategoryAnalytics: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color
}

struct CategoryAnalyticsData {
    let categories: [CategoryAnalytics]
    let totalAmount: Double
    let categoryCount: Int
}

// MARK: - Target Models

struct Target: Identifiable, Codable {
    let id: String
    let accountId: String
    let title: String
    let description: String?
    let targetAmount: Double
    let currentAmount: Double
    let currency: String
    let targetDate: String?
    let status: String
    let targetType: String
    let category: String?
    let priority: String
    let autoUpdate: Bool
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId
        case title
        case description
        case targetAmount
        case currentAmount
        case currency
        case targetDate
        case status
        case targetType
        case category
        case priority
        case autoUpdate
        case createdAt
        case updatedAt
    }
    
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentAmount / targetAmount) * 100, 100)
    }
}

struct GetTargetsResponse: Codable {
    let success: Bool
    let targets: [Target]
    let requestId: String?
}

// MARK: - Asset Models

struct Asset: Identifiable, Codable {
    let id: String
    let accountId: String
    let name: String
    let type: String
    let currentValue: Double
    let description: String?
    let currency: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId
        case name
        case type
        case currentValue
        case description
        case currency
        case createdAt
        case updatedAt
    }
}

struct GetAssetsResponse: Codable {
    let success: Bool
    let assets: [Asset]
    let requestId: String?
}

// MARK: - Conversation Management Models

struct CreateConversationRequest: Codable {
    let userId: String
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case userId
        case title
    }
}

struct CreateConversationResponse: Codable {
    let success: Bool
    let conversation: Conversation
    let requestId: String?
}

// MARK: - Message Management Models

struct GetMessagesResponse: Codable {
    let success: Bool
    let messages: [SupabaseMessageData]
    let requestId: String?
}

struct SupabaseMessageData: Codable {
    let id: String
    let accountId: String
    let conversationId: String?
    let messageText: String?
    let sender: String?
    let messageId: String?
    let dataType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case conversationId = "conversation_id"
        case messageText = "message_text"
        case sender
        case messageId = "message_id"
        case dataType = "data_type"
        case createdAt = "created_at"
    }
}

struct SaveMessageRequest: Codable {
    let userId: String
    let conversationId: String
    let messageId: String
    let messageText: String
    let sender: String
    
    enum CodingKeys: String, CodingKey {
        case userId
        case conversationId
        case messageId
        case messageText
        case sender
    }
}

struct SaveMessageResponse: Codable {
    let success: Bool
    let message: SupabaseMessageData
    let requestId: String?
}

// MARK: - Message Feedback Models

struct SaveMessageFeedbackRequest: Codable {
    let userId: String
    let messageId: String
    let conversationId: String?
    let feedbackType: String // "like" or "dislike"
}

struct SaveMessageFeedbackResponse: Codable {
    let success: Bool
    let feedback: MessageFeedback?
    let requestId: String?
}

struct MessageFeedback: Codable {
    let id: String?
    let userId: String
    let messageId: String
    let conversationId: String?
    let feedbackType: String
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case feedbackType = "feedback_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

