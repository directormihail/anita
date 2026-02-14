//
//  OnboardingSurvey.swift
//  ANITA
//
//  Registration onboarding survey models + persistence
//

import Foundation

struct OnboardingSurveyResponse: Codable {
    let languageCode: String // e.g. "en", "de", "fr", "es", "it", "pl", "tr", "ru", "uk"
    let userName: String // Display name from onboarding
    let currencyCode: String // e.g. "USD", "EUR", "GBP"
    let answers: [String: String] // questionId -> optionId
    let completedAt: Date
    
    init(languageCode: String, userName: String, currencyCode: String, answers: [String: String], completedAt: Date) {
        self.languageCode = languageCode
        self.userName = userName
        self.currencyCode = currencyCode
        self.answers = answers
        self.completedAt = completedAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case languageCode
        case userName
        case currencyCode
        case answers
        case completedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        answers = try container.decode([String: String].self, forKey: .answers)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }
}

extension OnboardingSurveyResponse {
    static let userDefaultsKey = "anita_onboarding_survey_response"
    static let preferredLanguageKey = "anita_preferred_language_code"
    
    /// UserDefaults key for a specific account (use this so name/onboarding don't leak between accounts).
    static func key(forUserId userId: String) -> String {
        "\(userDefaultsKey)_\(userId)"
    }
    
    static func preferredLanguageKey(forUserId userId: String) -> String {
        "\(preferredLanguageKey)_\(userId)"
    }
    
    func saveToUserDefaults(userId: String) {
        do {
            let data = try JSONEncoder().encode(self)
            let k = Self.key(forUserId: userId)
            UserDefaults.standard.set(data, forKey: k)
            UserDefaults.standard.set(languageCode, forKey: Self.preferredLanguageKey(forUserId: userId))
        } catch {
            print("[OnboardingSurveyResponse] Failed to encode/save: \(error)")
        }
    }
    
    /// Load survey for the given account. Use this so each account has its own name/onboarding.
    static func loadFromUserDefaults(userId: String) -> OnboardingSurveyResponse? {
        let k = key(forUserId: userId)
        guard let data = UserDefaults.standard.data(forKey: k) else { return nil }
        do {
            return try JSONDecoder().decode(OnboardingSurveyResponse.self, from: data)
        } catch {
            print("[OnboardingSurveyResponse] Failed to decode: \(error)")
            return nil
        }
    }
    
    /// Legacy: save using global key (avoid; use saveToUserDefaults(userId:) for per-account storage).
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
            UserDefaults.standard.set(languageCode, forKey: Self.preferredLanguageKey)
        } catch {
            print("[OnboardingSurveyResponse] Failed to encode/save: \(error)")
        }
    }
    
    /// Legacy: load using global key. Prefer loadFromUserDefaults(userId:) for per-account storage.
    static func loadFromUserDefaults() -> OnboardingSurveyResponse? {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else { return nil }
        do {
            return try JSONDecoder().decode(OnboardingSurveyResponse.self, from: data)
        } catch {
            print("[OnboardingSurveyResponse] Failed to decode: \(error)")
            return nil
        }
    }
    
    static func preferredLanguageCode() -> String? {
        UserDefaults.standard.string(forKey: Self.preferredLanguageKey)
    }
    
    static func preferredLanguageCode(userId: String) -> String? {
        UserDefaults.standard.string(forKey: preferredLanguageKey(forUserId: userId))
    }
}

