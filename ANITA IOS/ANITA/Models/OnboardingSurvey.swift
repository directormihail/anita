//
//  OnboardingSurvey.swift
//  ANITA
//
//  Registration onboarding survey models + persistence
//

import Foundation

struct OnboardingSurveyResponse: Codable {
    let languageCode: String // e.g. "en", "de", "fr", "es", "it", "pl", "tr", "ru", "uk"
    let currencyCode: String // e.g. "USD", "EUR", "GBP"
    let answers: [String: String] // questionId -> optionId
    let completedAt: Date
    
    // Backward-compatible decode: older builds may have saved surveys without currencyCode.
    init(languageCode: String, currencyCode: String, answers: [String: String], completedAt: Date) {
        self.languageCode = languageCode
        self.currencyCode = currencyCode
        self.answers = answers
        self.completedAt = completedAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case languageCode
        case currencyCode
        case answers
        case completedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        answers = try container.decode([String: String].self, forKey: .answers)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }
}

extension OnboardingSurveyResponse {
    static let userDefaultsKey = "anita_onboarding_survey_response"
    static let preferredLanguageKey = "anita_preferred_language_code"
    
    func saveToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
            UserDefaults.standard.set(languageCode, forKey: Self.preferredLanguageKey)
        } catch {
            print("[OnboardingSurveyResponse] Failed to encode/save: \(error)")
        }
    }
    
    static func loadFromUserDefaults() -> OnboardingSurveyResponse? {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else {
            return nil
        }
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
}

