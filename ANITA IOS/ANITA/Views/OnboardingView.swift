//
//  OnboardingView.swift
//  ANITA
//
//  Registration onboarding flow (language + 5 finance questions)
//

import SwiftUI

struct OnboardingView: View {
    struct LanguageOption: Identifiable, Hashable {
        let id: String // language code
        let title: String
        let subtitle: String
    }
    
    struct Question: Identifiable {
        struct Option: Identifiable {
            let id: String
        }
        
        let id: String
        let options: [Option]
    }
    
    @State private var pageIndex: Int = 0
    @State private var selectedLanguage: LanguageOption? = nil
    @State private var answers: [String: String] = [:]
    @State private var selectedCurrency: String = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    
    let onComplete: (OnboardingSurveyResponse) -> Void
    
    private let languages: [LanguageOption] = [
        // Keep high-ROI markets near the top for faster selection.
        .init(id: "en", title: "English", subtitle: ""),
        .init(id: "de", title: "Deutsch", subtitle: ""),
        .init(id: "fr", title: "Français", subtitle: ""),
        .init(id: "es", title: "Español", subtitle: ""),
        .init(id: "it", title: "Italiano", subtitle: ""),
        .init(id: "pl", title: "Polski", subtitle: ""),
        .init(id: "tr", title: "Türkçe", subtitle: ""),
        .init(id: "ru", title: "Русский", subtitle: ""),
        .init(id: "uk", title: "Українська", subtitle: "")
    ]
    
    private let questions: [Question] = [
        .init(
            id: "goal",
            options: [
                .init(id: "save_more"),
                .init(id: "pay_debt"),
                .init(id: "emergency_fund"),
                .init(id: "start_investing"),
                .init(id: "stop_overspending"),
                .init(id: "big_purchase")
            ]
        ),
        .init(
            id: "help_first",
            options: [
                .init(id: "budgeting"),
                .init(id: "expense_tracking"),
                .init(id: "debt_strategy"),
                .init(id: "income_growth"),
                .init(id: "investing_basics"),
                .init(id: "goal_planning")
            ]
        ),
        .init(
            id: "tracking_today",
            options: [
                .init(id: "not_tracking"),
                .init(id: "mental_notes"),
                .init(id: "spreadsheet"),
                .init(id: "bank_app"),
                .init(id: "budget_app"),
                .init(id: "other")
            ]
        ),
        .init(
            id: "situation",
            options: [
                .init(id: "paycheck_to_paycheck"),
                .init(id: "some_savings"),
                .init(id: "stable"),
                .init(id: "debt_heavy"),
                .init(id: "building_wealth"),
                .init(id: "prefer_not_say")
            ]
        ),
        .init(
            id: "challenge",
            options: [
                .init(id: "impulse_spending"),
                .init(id: "no_budget"),
                .init(id: "debt_stress"),
                .init(id: "irregular_income"),
                .init(id: "saving_consistency"),
                .init(id: "investing_confusion")
            ]
        )
    ]
    
    private struct CurrencyOption: Identifiable, Hashable {
        let id: String // currency code
        let symbol: String
        let name: String
    }
    
    private let currencyOptions: [CurrencyOption] = [
        .init(id: "USD", symbol: "$", name: "US Dollar"),
        .init(id: "EUR", symbol: "€", name: "Euro"),
        .init(id: "GBP", symbol: "£", name: "British Pound"),
        .init(id: "CHF", symbol: "CHF", name: "Swiss Franc"),
        .init(id: "PLN", symbol: "zł", name: "Polish Złoty"),
        .init(id: "TRY", symbol: "₺", name: "Turkish Lira"),
        .init(id: "CAD", symbol: "C$", name: "Canadian Dollar")
    ]
    
    // Pages: language + currency + questions
    private var totalPages: Int { 2 + questions.count }
    
    private var isLastPage: Bool { pageIndex == totalPages - 1 }
    private var isFirstPage: Bool { pageIndex == 0 }
    
    private var hasAnsweredAllQuestions: Bool {
        guard selectedLanguage != nil else { return false }
        guard !selectedCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return questions.allSatisfy { answers[$0.id] != nil }
    }
    
    private var onboardingProgress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(min(pageIndex + 1, totalPages)) / Double(totalPages)
    }
    
    private var isNextEnabled: Bool {
        if pageIndex == 0 {
            return selectedLanguage != nil
        }
        if pageIndex == 1 {
            return !selectedCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if pageIndex >= 2 && pageIndex <= questions.count + 1 {
            let question = questions[pageIndex - 2]
            return answers[question.id] != nil
        }
        return hasAnsweredAllQuestions
    }
    
    private var languageCode: String {
        selectedLanguage?.id ?? "en"
    }
    
    private var setupTitle: String { AppL10n.t("common.setup", languageCode: languageCode) }
    private var backTitle: String { AppL10n.t("common.back", languageCode: languageCode) }
    private var nextTitle: String { AppL10n.t("common.next", languageCode: languageCode) }
    private var getStartedTitle: String { AppL10n.t("common.get_started", languageCode: languageCode) }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(setupTitle) ⚙️")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text("\(min(pageIndex + 1, totalPages))/\(totalPages)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                SetupProgressBar(progress: onboardingProgress)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                
                TabView(selection: $pageIndex) {
                    languagePage.tag(0)
                    
                    currencyPage.tag(1)
                    
                    ForEach(0..<questions.count, id: \.self) { idx in
                        questionPage(questions[idx])
                            .tag(idx + 2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Nav buttons
                HStack(spacing: 16) {
                    if !isFirstPage {
                        backButton
                    }
                    
                    nextButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var languagePage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 14) {
                Text(AppL10n.t("onboarding.language.title", languageCode: languageCode))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(AppL10n.t("onboarding.language.subtitle", languageCode: languageCode))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(languages) { lang in
                    SelectableCard(
                        title: lang.title,
                        subtitle: lang.subtitle,
                        isSelected: selectedLanguage == lang
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        selectedLanguage = lang
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .onChange(of: selectedLanguage) { _, newValue in
            if let code = newValue?.id {
                // Apply immediately to the rest of onboarding + the app UI.
                AppL10n.setLanguageCode(code)
            }
        }
    }
    
    private func questionPage(_ question: Question) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 10) {
                Text(questionTitle(question.id))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                
                if let subtitle = questionSubtitle(question.id) {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
            .padding(.bottom, 18)
            
            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    SelectableRow(
                        title: optionTitle(questionId: question.id, optionId: option.id),
                        isSelected: answers[question.id] == option.id
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        answers[question.id] = option.id
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var currencyPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 14) {
                Text(AppL10n.t("onboarding.currency.title", languageCode: languageCode))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(AppL10n.t("onboarding.currency.subtitle", languageCode: languageCode))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            
            VStack(spacing: 10) {
                ForEach(currencyOptions) { option in
                    SelectableRow(
                        title: "\(option.symbol)  \(option.id)  •  \(option.name)",
                        isSelected: selectedCurrency == option.id
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        selectedCurrency = option.id
                        persistCurrencySelection(option.id)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .onAppear {
            // Ensure a valid default is selected.
            if currencyOptions.contains(where: { $0.id == selectedCurrency }) == false {
                selectedCurrency = "USD"
                persistCurrencySelection("USD")
            }
        }
    }
    
    private func persistCurrencySelection(_ currency: String) {
        UserDefaults.standard.set(currency, forKey: "anita_user_currency")
        let format = numberFormatForCurrency(currency)
        UserDefaults.standard.set(format, forKey: "anita_number_format")
    }
    
    private func numberFormatForCurrency(_ currency: String) -> String {
        switch currency {
        case "EUR", "PLN":
            return "1.234,56"
        default:
            return "1,234.56"
        }
    }

    // MARK: - Onboarding questions localization (with context-appropriate smiles)
    
    private func questionTitle(_ id: String) -> String {
        switch languageCode {
        case "de":
            switch id {
            case "goal": return "Was ist dein wichtigstes Geldziel gerade?\(emojiForQuestion(id))"
            case "help_first": return "Wobei soll ich dir zuerst helfen?\(emojiForQuestion(id))"
            case "tracking_today": return "Wie behältst du heute deine Finanzen im Blick?\(emojiForQuestion(id))"
            case "situation": return "Welche Situation passt am besten zu dir?\(emojiForQuestion(id))"
            case "challenge": return "Was ist für dich am schwierigsten bei Geld?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "fr":
            switch id {
            case "goal": return "Quel est ton objectif financier #1 en ce moment?\(emojiForQuestion(id))"
            case "help_first": return "Sur quoi veux-tu de l’aide en premier?\(emojiForQuestion(id))"
            case "tracking_today": return "Comment suis-tu tes finances aujourd’hui?\(emojiForQuestion(id))"
            case "situation": return "Laquelle décrit le mieux ta situation?\(emojiForQuestion(id))"
            case "challenge": return "Qu’est-ce qui est le plus difficile avec l’argent pour toi?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "es":
            switch id {
            case "goal": return "¿Cuál es tu objetivo #1 con el dinero ahora?\(emojiForQuestion(id))"
            case "help_first": return "¿Con qué quieres ayuda primero?\(emojiForQuestion(id))"
            case "tracking_today": return "¿Cómo llevas tus finanzas hoy?\(emojiForQuestion(id))"
            case "situation": return "¿Cuál describe mejor tu situación?\(emojiForQuestion(id))"
            case "challenge": return "¿Qué es lo más difícil del dinero para ti?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "it":
            switch id {
            case "goal": return "Qual è il tuo obiettivo #1 con i soldi ora?\(emojiForQuestion(id))"
            case "help_first": return "Su cosa vuoi aiuto per primo?\(emojiForQuestion(id))"
            case "tracking_today": return "Come tieni traccia dei soldi oggi?\(emojiForQuestion(id))"
            case "situation": return "Quale descrive meglio la tua situazione?\(emojiForQuestion(id))"
            case "challenge": return "Qual è la parte più difficile dei soldi per te?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "pl":
            switch id {
            case "goal": return "Jaki jest twój najważniejszy cel finansowy teraz?\(emojiForQuestion(id))"
            case "help_first": return "W czym chcesz pomocy najpierw?\(emojiForQuestion(id))"
            case "tracking_today": return "Jak dziś śledzisz swoje finanse?\(emojiForQuestion(id))"
            case "situation": return "Które najlepiej opisuje twoją sytuację?\(emojiForQuestion(id))"
            case "challenge": return "Co jest dla ciebie najtrudniejsze w kwestii pieniędzy?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "ru":
            switch id {
            case "goal": return "Какая у тебя цель №1 по деньгам сейчас?\(emojiForQuestion(id))"
            case "help_first": return "С чего начнём помощь?\(emojiForQuestion(id))"
            case "tracking_today": return "Как ты сейчас следишь за финансами?\(emojiForQuestion(id))"
            case "situation": return "Что лучше всего описывает твою ситуацию?\(emojiForQuestion(id))"
            case "challenge": return "Что самое сложное в деньгах для тебя?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "tr":
            switch id {
            case "goal": return "Şu anda #1 para hedefin ne?\(emojiForQuestion(id))"
            case "help_first": return "İlk olarak hangi konuda yardım istersin?\(emojiForQuestion(id))"
            case "tracking_today": return "Bugün paranı nasıl takip ediyorsun?\(emojiForQuestion(id))"
            case "situation": return "Hangisi durumunu en iyi anlatıyor?\(emojiForQuestion(id))"
            case "challenge": return "Para konusunda senin için en zor olan ne?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        case "uk":
            switch id {
            case "goal": return "Яка твоя ціль №1 щодо грошей зараз?\(emojiForQuestion(id))"
            case "help_first": return "З чим хочеш допомогу спочатку?\(emojiForQuestion(id))"
            case "tracking_today": return "Як ти зараз ведеш облік грошей?\(emojiForQuestion(id))"
            case "situation": return "Що найкраще описує твою ситуацію?\(emojiForQuestion(id))"
            case "challenge": return "Що найскладніше у фінансах для тебе?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        default:
            switch id {
            case "goal": return "What’s your #1 money goal right now?\(emojiForQuestion(id))"
            case "help_first": return "What do you want help with first?\(emojiForQuestion(id))"
            case "tracking_today": return "How do you track your money today?\(emojiForQuestion(id))"
            case "situation": return "Which best describes your situation?\(emojiForQuestion(id))"
            case "challenge": return "What’s the hardest part about money for you?\(emojiForQuestion(id))"
            default: return "\(id)\(emojiForQuestion(id))"
            }
        }
    }
    
    private func questionSubtitle(_ id: String) -> String? {
        switch languageCode {
        case "de":
            switch id {
            case "goal": return "Damit ANITA deinen Plan personalisieren kann ✨"
            case "challenge": return "Wähle eins — ich passe mich an 💡"
            default: return nil
            }
        case "fr":
            switch id {
            case "goal": return "Pour qu’ANITA puisse personnaliser ton plan ✨"
            case "challenge": return "Choisis-en une — on s’adapte 💡"
            default: return nil
            }
        case "es":
            switch id {
            case "goal": return "Para que ANITA personalice tu plan ✨"
            case "challenge": return "Elige una — me adapto 💡"
            default: return nil
            }
        case "it":
            switch id {
            case "goal": return "Così ANITA può personalizzare il tuo piano ✨"
            case "challenge": return "Scegline una — mi adatto 💡"
            default: return nil
            }
        case "pl":
            switch id {
            case "goal": return "Żeby ANITA mogła spersonalizować twój plan ✨"
            case "challenge": return "Wybierz jedną — dostosujemy się 💡"
            default: return nil
            }
        case "ru":
            switch id {
            case "goal": return "Чтобы ANITA могла персонализировать план ✨"
            case "challenge": return "Выбери один вариант — я подстроюсь 💡"
            default: return nil
            }
        case "tr":
            switch id {
            case "goal": return "ANITA’nın planını kişiselleştirebilmesi için ✨"
            case "challenge": return "Birini seç — uyum sağlayalım 💡"
            default: return nil
            }
        case "uk":
            switch id {
            case "goal": return "Щоб ANITA могла персоналізувати план ✨"
            case "challenge": return "Обери один варіант — я підлаштуюсь 💡"
            default: return nil
            }
        default:
            switch id {
            case "goal": return "So ANITA can personalize your plan ✨"
            case "challenge": return "Pick one — we’ll adapt 💡"
            default: return nil
            }
        }
    }

    private func emojiForQuestion(_ id: String) -> String {
        // Leading space included for clean concatenation.
        switch id {
        case "goal": return " 🎯"
        case "help_first": return " 🤝"
        case "tracking_today": return " 🧾"
        case "situation": return " 🧭"
        case "challenge": return " 💪"
        default: return ""
        }
    }
    
    private func optionTitle(questionId: String, optionId: String) -> String {
        switch languageCode {
        case "de":
            return deOptionTitle(questionId: questionId, optionId: optionId)
        case "fr":
            return frOptionTitle(questionId: questionId, optionId: optionId)
        case "es":
            return esOptionTitle(questionId: questionId, optionId: optionId)
        case "it":
            return itOptionTitle(questionId: questionId, optionId: optionId)
        case "pl":
            return plOptionTitle(questionId: questionId, optionId: optionId)
        case "ru":
            return ruOptionTitle(questionId: questionId, optionId: optionId)
        case "tr":
            return trOptionTitle(questionId: questionId, optionId: optionId)
        case "uk":
            return ukOptionTitle(questionId: questionId, optionId: optionId)
        default:
            return enOptionTitle(questionId: questionId, optionId: optionId)
        }
    }
    
    private func enOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Save more"
        case ("goal", "pay_debt"): return "Pay off debt"
        case ("goal", "emergency_fund"): return "Build an emergency fund"
        case ("goal", "start_investing"): return "Start investing"
        case ("goal", "stop_overspending"): return "Stop overspending"
        case ("goal", "big_purchase"): return "Plan for a big purchase"
            
        case ("help_first", "budgeting"): return "Budgeting"
        case ("help_first", "expense_tracking"): return "Tracking expenses"
        case ("help_first", "debt_strategy"): return "Debt payoff strategy"
        case ("help_first", "income_growth"): return "Increasing income"
        case ("help_first", "investing_basics"): return "Investing basics"
        case ("help_first", "goal_planning"): return "Saving for goals"
            
        case ("tracking_today", "not_tracking"): return "I don’t track it"
        case ("tracking_today", "mental_notes"): return "In my head / notes"
        case ("tracking_today", "spreadsheet"): return "Spreadsheet"
        case ("tracking_today", "bank_app"): return "Bank app"
        case ("tracking_today", "budget_app"): return "Budgeting app"
        case ("tracking_today", "other"): return "Other"
            
        case ("situation", "paycheck_to_paycheck"): return "Paycheck-to-paycheck"
        case ("situation", "some_savings"): return "I have some savings"
        case ("situation", "stable"): return "Mostly stable"
        case ("situation", "debt_heavy"): return "Debt feels heavy"
        case ("situation", "building_wealth"): return "Building wealth"
        case ("situation", "prefer_not_say"): return "Prefer not to say"
            
        case ("challenge", "impulse_spending"): return "Impulse spending"
        case ("challenge", "no_budget"): return "No clear budget"
        case ("challenge", "debt_stress"): return "Debt payments"
        case ("challenge", "irregular_income"): return "Irregular income"
        case ("challenge", "saving_consistency"): return "Saving consistently"
        case ("challenge", "investing_confusion"): return "Understanding investing"
        default:
            return optionId
        }
    }
    
    private func deOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Mehr sparen"
        case ("goal", "pay_debt"): return "Schulden abbauen"
        case ("goal", "emergency_fund"): return "Notgroschen aufbauen"
        case ("goal", "start_investing"): return "Mit dem Investieren anfangen"
        case ("goal", "stop_overspending"): return "Weniger impulsiv ausgeben"
        case ("goal", "big_purchase"): return "Für einen großen Kauf planen"
            
        case ("help_first", "budgeting"): return "Budget erstellen"
        case ("help_first", "expense_tracking"): return "Ausgaben tracken"
        case ("help_first", "debt_strategy"): return "Schulden-Strategie"
        case ("help_first", "income_growth"): return "Einkommen steigern"
        case ("help_first", "investing_basics"): return "Investieren (Basics)"
        case ("help_first", "goal_planning"): return "Für Ziele sparen"
            
        case ("tracking_today", "not_tracking"): return "Ich tracke nicht"
        case ("tracking_today", "mental_notes"): return "Im Kopf / Notizen"
        case ("tracking_today", "spreadsheet"): return "Spreadsheet"
        case ("tracking_today", "bank_app"): return "Bank-App"
        case ("tracking_today", "budget_app"): return "Budget-App"
        case ("tracking_today", "other"): return "Etwas anderes"
            
        case ("situation", "paycheck_to_paycheck"): return "Von Gehalt zu Gehalt"
        case ("situation", "some_savings"): return "Ich habe etwas Erspartes"
        case ("situation", "stable"): return "Meistens stabil"
        case ("situation", "debt_heavy"): return "Schulden drücken"
        case ("situation", "building_wealth"): return "Vermögen aufbauen"
        case ("situation", "prefer_not_say"): return "Lieber nicht sagen"
            
        case ("challenge", "impulse_spending"): return "Impulskäufe"
        case ("challenge", "no_budget"): return "Kein klares Budget"
        case ("challenge", "debt_stress"): return "Schuldenraten"
        case ("challenge", "irregular_income"): return "Unregelmäßiges Einkommen"
        case ("challenge", "saving_consistency"): return "Konsequent sparen"
        case ("challenge", "investing_confusion"): return "Investieren verstehen"
        default:
            return optionId
        }
    }
    
    private func frOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Épargner davantage"
        case ("goal", "pay_debt"): return "Rembourser mes dettes"
        case ("goal", "emergency_fund"): return "Constituer une épargne de secours"
        case ("goal", "start_investing"): return "Commencer à investir"
        case ("goal", "stop_overspending"): return "Arrêter de trop dépenser"
        case ("goal", "big_purchase"): return "Préparer un gros achat"
            
        case ("help_first", "budgeting"): return "Budget"
        case ("help_first", "expense_tracking"): return "Suivi des dépenses"
        case ("help_first", "debt_strategy"): return "Stratégie de remboursement"
        case ("help_first", "income_growth"): return "Augmenter mes revenus"
        case ("help_first", "investing_basics"): return "Bases de l’investissement"
        case ("help_first", "goal_planning"): return "Épargner pour des objectifs"
            
        case ("tracking_today", "not_tracking"): return "Je ne suis pas"
        case ("tracking_today", "mental_notes"): return "Dans ma tête / notes"
        case ("tracking_today", "spreadsheet"): return "Tableur"
        case ("tracking_today", "bank_app"): return "Appli bancaire"
        case ("tracking_today", "budget_app"): return "Appli de budget"
        case ("tracking_today", "other"): return "Autre"
            
        case ("situation", "paycheck_to_paycheck"): return "De paie en paie"
        case ("situation", "some_savings"): return "J’ai un peu d’épargne"
        case ("situation", "stable"): return "Plutôt stable"
        case ("situation", "debt_heavy"): return "Les dettes pèsent"
        case ("situation", "building_wealth"): return "Je construis mon patrimoine"
        case ("situation", "prefer_not_say"): return "Je préfère ne pas dire"
            
        case ("challenge", "impulse_spending"): return "Dépenses impulsives"
        case ("challenge", "no_budget"): return "Pas de budget clair"
        case ("challenge", "debt_stress"): return "Remboursements"
        case ("challenge", "irregular_income"): return "Revenus irréguliers"
        case ("challenge", "saving_consistency"): return "Épargner régulièrement"
        case ("challenge", "investing_confusion"): return "Comprendre l’investissement"
        default:
            return optionId
        }
    }
    
    private func esOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Ahorrar más"
        case ("goal", "pay_debt"): return "Pagar deudas"
        case ("goal", "emergency_fund"): return "Fondo de emergencia"
        case ("goal", "start_investing"): return "Empezar a invertir"
        case ("goal", "stop_overspending"): return "Gastar menos"
        case ("goal", "big_purchase"): return "Planear una compra grande"
            
        case ("help_first", "budgeting"): return "Presupuesto"
        case ("help_first", "expense_tracking"): return "Registrar gastos"
        case ("help_first", "debt_strategy"): return "Estrategia de deudas"
        case ("help_first", "income_growth"): return "Aumentar ingresos"
        case ("help_first", "investing_basics"): return "Invertir (básico)"
        case ("help_first", "goal_planning"): return "Ahorrar para metas"
            
        case ("tracking_today", "not_tracking"): return "No lo llevo"
        case ("tracking_today", "mental_notes"): return "En mi cabeza / notas"
        case ("tracking_today", "spreadsheet"): return "Hoja de cálculo"
        case ("tracking_today", "bank_app"): return "App del banco"
        case ("tracking_today", "budget_app"): return "App de presupuesto"
        case ("tracking_today", "other"): return "Otro"
            
        case ("situation", "paycheck_to_paycheck"): return "De sueldo en sueldo"
        case ("situation", "some_savings"): return "Tengo algunos ahorros"
        case ("situation", "stable"): return "Bastante estable"
        case ("situation", "debt_heavy"): return "Las deudas pesan"
        case ("situation", "building_wealth"): return "Construyendo patrimonio"
        case ("situation", "prefer_not_say"): return "Prefiero no decirlo"
            
        case ("challenge", "impulse_spending"): return "Gasto impulsivo"
        case ("challenge", "no_budget"): return "Sin presupuesto claro"
        case ("challenge", "debt_stress"): return "Pagos de deuda"
        case ("challenge", "irregular_income"): return "Ingresos irregulares"
        case ("challenge", "saving_consistency"): return "Ahorrar con constancia"
        case ("challenge", "investing_confusion"): return "Entender inversión"
        default:
            return optionId
        }
    }
    
    private func itOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Risparmiare di più"
        case ("goal", "pay_debt"): return "Ripagare debiti"
        case ("goal", "emergency_fund"): return "Fondo d’emergenza"
        case ("goal", "start_investing"): return "Iniziare a investire"
        case ("goal", "stop_overspending"): return "Spendere meno"
        case ("goal", "big_purchase"): return "Pianificare un grande acquisto"
            
        case ("help_first", "budgeting"): return "Budget"
        case ("help_first", "expense_tracking"): return "Tracciare spese"
        case ("help_first", "debt_strategy"): return "Strategia debiti"
        case ("help_first", "income_growth"): return "Aumentare il reddito"
        case ("help_first", "investing_basics"): return "Investire (base)"
        case ("help_first", "goal_planning"): return "Risparmiare per obiettivi"
            
        case ("tracking_today", "not_tracking"): return "Non traccio"
        case ("tracking_today", "mental_notes"): return "A mente / note"
        case ("tracking_today", "spreadsheet"): return "Foglio di calcolo"
        case ("tracking_today", "bank_app"): return "App banca"
        case ("tracking_today", "budget_app"): return "App budget"
        case ("tracking_today", "other"): return "Altro"
            
        case ("situation", "paycheck_to_paycheck"): return "Da stipendio a stipendio"
        case ("situation", "some_savings"): return "Ho qualche risparmio"
        case ("situation", "stable"): return "Abbastanza stabile"
        case ("situation", "debt_heavy"): return "Debiti pesanti"
        case ("situation", "building_wealth"): return "Costruire patrimonio"
        case ("situation", "prefer_not_say"): return "Preferisco non dirlo"
            
        case ("challenge", "impulse_spending"): return "Spese impulsive"
        case ("challenge", "no_budget"): return "Nessun budget chiaro"
        case ("challenge", "debt_stress"): return "Rate dei debiti"
        case ("challenge", "irregular_income"): return "Reddito irregolare"
        case ("challenge", "saving_consistency"): return "Risparmiare con costanza"
        case ("challenge", "investing_confusion"): return "Capire gli investimenti"
        default:
            return optionId
        }
    }
    
    private func plOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Więcej oszczędzać"
        case ("goal", "pay_debt"): return "Spłacić długi"
        case ("goal", "emergency_fund"): return "Zbudować poduszkę finansową"
        case ("goal", "start_investing"): return "Zacząć inwestować"
        case ("goal", "stop_overspending"): return "Przestać wydawać za dużo"
        case ("goal", "big_purchase"): return "Zaplanować duży zakup"
            
        case ("help_first", "budgeting"): return "Budżetowanie"
        case ("help_first", "expense_tracking"): return "Śledzenie wydatków"
        case ("help_first", "debt_strategy"): return "Strategia spłaty długów"
        case ("help_first", "income_growth"): return "Zwiększenie dochodów"
        case ("help_first", "investing_basics"): return "Podstawy inwestowania"
        case ("help_first", "goal_planning"): return "Oszczędzanie na cele"
            
        case ("tracking_today", "not_tracking"): return "Nie śledzę"
        case ("tracking_today", "mental_notes"): return "W głowie / notatkach"
        case ("tracking_today", "spreadsheet"): return "Arkusz kalkulacyjny"
        case ("tracking_today", "bank_app"): return "Aplikacja banku"
        case ("tracking_today", "budget_app"): return "Aplikacja do budżetu"
        case ("tracking_today", "other"): return "Inne"
            
        case ("situation", "paycheck_to_paycheck"): return "Od wypłaty do wypłaty"
        case ("situation", "some_savings"): return "Mam trochę oszczędności"
        case ("situation", "stable"): return "W miarę stabilnie"
        case ("situation", "debt_heavy"): return "Długi są przytłaczające"
        case ("situation", "building_wealth"): return "Buduję majątek"
        case ("situation", "prefer_not_say"): return "Wolę nie mówić"
            
        case ("challenge", "impulse_spending"): return "Impulsywne wydatki"
        case ("challenge", "no_budget"): return "Brak jasnego budżetu"
        case ("challenge", "debt_stress"): return "Spłaty długów"
        case ("challenge", "irregular_income"): return "Nieregularny dochód"
        case ("challenge", "saving_consistency"): return "Regularne oszczędzanie"
        case ("challenge", "investing_confusion"): return "Zrozumienie inwestowania"
        default:
            return optionId
        }
    }
    
    private func ruOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Больше откладывать"
        case ("goal", "pay_debt"): return "Погасить долги"
        case ("goal", "emergency_fund"): return "Создать подушку"
        case ("goal", "start_investing"): return "Начать инвестировать"
        case ("goal", "stop_overspending"): return "Меньше тратить"
        case ("goal", "big_purchase"): return "Планировать крупную покупку"
            
        case ("help_first", "budgeting"): return "Бюджет"
        case ("help_first", "expense_tracking"): return "Учёт расходов"
        case ("help_first", "debt_strategy"): return "Стратегия по долгам"
        case ("help_first", "income_growth"): return "Увеличить доход"
        case ("help_first", "investing_basics"): return "Инвестиции (основы)"
        case ("help_first", "goal_planning"): return "Копить на цели"
            
        case ("tracking_today", "not_tracking"): return "Никак не веду"
        case ("tracking_today", "mental_notes"): return "В голове / заметки"
        case ("tracking_today", "spreadsheet"): return "Таблица"
        case ("tracking_today", "bank_app"): return "Банк‑приложение"
        case ("tracking_today", "budget_app"): return "Приложение для бюджета"
        case ("tracking_today", "other"): return "Другое"
            
        case ("situation", "paycheck_to_paycheck"): return "От зарплаты до зарплаты"
        case ("situation", "some_savings"): return "Есть небольшие накопления"
        case ("situation", "stable"): return "В целом стабильно"
        case ("situation", "debt_heavy"): return "Долги давят"
        case ("situation", "building_wealth"): return "Наращиваю капитал"
        case ("situation", "prefer_not_say"): return "Предпочту не говорить"
            
        case ("challenge", "impulse_spending"): return "Импульсивные траты"
        case ("challenge", "no_budget"): return "Нет чёткого бюджета"
        case ("challenge", "debt_stress"): return "Платежи по долгам"
        case ("challenge", "irregular_income"): return "Нерегулярный доход"
        case ("challenge", "saving_consistency"): return "Регулярно откладывать"
        case ("challenge", "investing_confusion"): return "Разобраться в инвестициях"
        default:
            return optionId
        }
    }
    
    private func trOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Daha fazla biriktirmek"
        case ("goal", "pay_debt"): return "Borçları kapatmak"
        case ("goal", "emergency_fund"): return "Acil durum fonu oluşturmak"
        case ("goal", "start_investing"): return "Yatırıma başlamak"
        case ("goal", "stop_overspending"): return "Gereğinden fazla harcamayı bırakmak"
        case ("goal", "big_purchase"): return "Büyük bir alım için plan yapmak"
            
        case ("help_first", "budgeting"): return "Bütçe yapmak"
        case ("help_first", "expense_tracking"): return "Giderleri takip etmek"
        case ("help_first", "debt_strategy"): return "Borç ödeme stratejisi"
        case ("help_first", "income_growth"): return "Geliri artırmak"
        case ("help_first", "investing_basics"): return "Yatırımın temelleri"
        case ("help_first", "goal_planning"): return "Hedefler için biriktirmek"
            
        case ("tracking_today", "not_tracking"): return "Takip etmiyorum"
        case ("tracking_today", "mental_notes"): return "Aklımda / notlarda"
        case ("tracking_today", "spreadsheet"): return "Tablo (Spreadsheet)"
        case ("tracking_today", "bank_app"): return "Banka uygulaması"
        case ("tracking_today", "budget_app"): return "Bütçe uygulaması"
        case ("tracking_today", "other"): return "Diğer"
            
        case ("situation", "paycheck_to_paycheck"): return "Maaştan maaşa"
        case ("situation", "some_savings"): return "Biraz birikimim var"
        case ("situation", "stable"): return "Genelde stabil"
        case ("situation", "debt_heavy"): return "Borçlar ağır geliyor"
        case ("situation", "building_wealth"): return "Varlık biriktiriyorum"
        case ("situation", "prefer_not_say"): return "Söylemek istemiyorum"
            
        case ("challenge", "impulse_spending"): return "Dürtüsel harcama"
        case ("challenge", "no_budget"): return "Net bir bütçe yok"
        case ("challenge", "debt_stress"): return "Borç ödemeleri"
        case ("challenge", "irregular_income"): return "Düzensiz gelir"
        case ("challenge", "saving_consistency"): return "Düzenli biriktirmek"
        case ("challenge", "investing_confusion"): return "Yatırımı anlamak"
        default:
            return optionId
        }
    }
    
    private func ukOptionTitle(questionId: String, optionId: String) -> String {
        switch (questionId, optionId) {
        case ("goal", "save_more"): return "Більше заощаджувати"
        case ("goal", "pay_debt"): return "Погасити борги"
        case ("goal", "emergency_fund"): return "Створити фінансову подушку"
        case ("goal", "start_investing"): return "Почати інвестувати"
        case ("goal", "stop_overspending"): return "Менше витрачати"
        case ("goal", "big_purchase"): return "Запланувати велику покупку"
            
        case ("help_first", "budgeting"): return "Бюджет"
        case ("help_first", "expense_tracking"): return "Облік витрат"
        case ("help_first", "debt_strategy"): return "Стратегія боргів"
        case ("help_first", "income_growth"): return "Збільшити дохід"
        case ("help_first", "investing_basics"): return "Інвестиції (основи)"
        case ("help_first", "goal_planning"): return "Заощадження на цілі"
            
        case ("tracking_today", "not_tracking"): return "Ніяк не веду"
        case ("tracking_today", "mental_notes"): return "В голові / нотатки"
        case ("tracking_today", "spreadsheet"): return "Таблиця"
        case ("tracking_today", "bank_app"): return "Банківський додаток"
        case ("tracking_today", "budget_app"): return "Додаток для бюджету"
        case ("tracking_today", "other"): return "Інше"
            
        case ("situation", "paycheck_to_paycheck"): return "Від зарплати до зарплати"
        case ("situation", "some_savings"): return "Є трохи заощаджень"
        case ("situation", "stable"): return "Загалом стабільно"
        case ("situation", "debt_heavy"): return "Борги тиснуть"
        case ("situation", "building_wealth"): return "Нарощую капітал"
        case ("situation", "prefer_not_say"): return "Краще не казати"
            
        case ("challenge", "impulse_spending"): return "Імпульсивні витрати"
        case ("challenge", "no_budget"): return "Немає чіткого бюджету"
        case ("challenge", "debt_stress"): return "Платежі за боргами"
        case ("challenge", "irregular_income"): return "Нерегулярний дохід"
        case ("challenge", "saving_consistency"): return "Заощаджувати регулярно"
        case ("challenge", "investing_confusion"): return "Розібратись в інвестиціях"
        default:
            return optionId
        }
    }
    
    private var backButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                pageIndex = max(pageIndex - 1, 0)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(backTitle)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .liquidGlass(cornerRadius: 14)
        }
        .buttonStyle(PremiumButtonStyle())
    }
    
    private var nextButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            if !isLastPage {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    pageIndex = min(pageIndex + 1, totalPages - 1)
                }
            } else {
                let language = selectedLanguage?.id ?? "en"
                let survey = OnboardingSurveyResponse(
                    languageCode: language,
                    currencyCode: selectedCurrency,
                    answers: answers,
                    completedAt: Date()
                )
                onComplete(survey)
            }
        } label: {
            HStack {
                Text(isLastPage ? getStartedTitle : nextTitle)
                    .font(.system(size: 17, weight: .semibold))
                
                if !isLastPage {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .liquidGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
            .shadow(color: Color.white.opacity(0.06), radius: 4, x: 0, y: -1)
        }
        .buttonStyle(PremiumButtonStyle())
        .disabled(!isNextEnabled)
        .opacity(isNextEnabled ? 1.0 : 0.45)
    }
}

private struct SetupProgressBar: View {
    let progress: Double
    
    private var clamped: Double { min(max(progress, 0), 1) }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let filled = max(10, w * CGFloat(clamped))
            
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: filled)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.26))
                            .blur(radius: 6)
                            .offset(y: -2)
                            .mask(Capsule(style: .continuous))
                    )
                    .shadow(color: Color.white.opacity(0.18), radius: 10, x: 0, y: 6)
                    .animation(.spring(response: 0.55, dampingFraction: 0.88), value: clamped)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(Int(clamped * 100)) percent")
    }
}

private struct SelectableCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                
                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isSelected
                            ? [Color(white: 0.25).opacity(0.5), Color(white: 0.18).opacity(0.35)]
                            : [Color(white: 0.15).opacity(0.3), Color(white: 0.1).opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SelectableRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(white: 0.12).opacity(isSelected ? 0.35 : 0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(isSelected ? 0.22 : 0.10), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView { _ in }
}
