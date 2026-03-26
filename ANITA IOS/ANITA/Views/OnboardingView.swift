//
//  OnboardingView.swift
//  ANITA
//
//  Registration onboarding flow (language + 4 finance questions) + FOMO screen
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
    @State private var userName: String = ""
    @State private var answers: [String: String] = [:]
    @State private var selectedCurrency: String = UserDefaults.standard.string(forKey: "anita_user_currency") ?? "USD"
    @State private var showingFomo: Bool = false
    @State private var showingPreBankHealthStory: Bool = false
    
    /// When true, adds a final "Connect your bank" step before completion; "Get started" on that step completes onboarding.
    var includeBankConnectionStep: Bool = false
    
    let onComplete: (OnboardingSurveyResponse) -> Void
    
    private let languages: [LanguageOption] = [
        .init(id: "en", title: "English", subtitle: ""),
        .init(id: "de", title: "Deutsch", subtitle: "")
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
        .init(id: "CHF", symbol: "CHF", name: "Swiss Franc")
    ]
    
    // Pages: language + name + currency + questions [+ optional bank step]
    private var totalPages: Int { 3 + questions.count + (includeBankConnectionStep ? 1 : 0) }
    
    private var isBankStepPage: Bool { includeBankConnectionStep && pageIndex == totalPages - 1 }
    /// Last survey page index before the optional bank step (language + name + currency + all questions).
    private var lastQuestionPageIndex: Int { 3 + questions.count - 1 }
    private var isLastPage: Bool { pageIndex == totalPages - 1 }
    private var isFirstPage: Bool { pageIndex == 0 }
    
    private var trimmedUserName: String { userName.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    private var hasAnsweredAllQuestions: Bool {
        guard selectedLanguage != nil else { return false }
        guard !trimmedUserName.isEmpty else { return false }
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
            return !trimmedUserName.isEmpty
        }
        if pageIndex == 2 {
            return !selectedCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if pageIndex >= 3 && pageIndex < 3 + questions.count {
            let question = questions[pageIndex - 3]
            return answers[question.id] != nil
        }
        if isBankStepPage {
            return true
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
            
            if showingFomo {
                fomoView
            } else if includeBankConnectionStep && showingPreBankHealthStory {
                OnboardingPreBankHealthStoryView(
                    languageCode: languageCode,
                    currencyCode: selectedCurrency,
                    userName: trimmedUserName,
                    onContinue: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            showingPreBankHealthStory = false
                            pageIndex = totalPages - 1
                        }
                    },
                    onBack: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            showingPreBankHealthStory = false
                        }
                    }
                )
            } else {
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
                    
                    // Single page at a time — no swipe; only Next/Back buttons change page
                    Group {
                        if isBankStepPage {
                            bankConnectionStepView
                        } else {
                            switch pageIndex {
                            case 0: languagePage
                            case 1: namePage
                            case 2: currencyPage
                            default:
                                if pageIndex >= 3 && pageIndex < 3 + questions.count {
                                    questionPage(questions[pageIndex - 3])
                                } else {
                                    languagePage
                                }
                            }
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pageIndex)
                    
                    // Nav buttons (hidden on bank step — only "Connect bank" or "Use manual input" continue)
                    if !isBankStepPage {
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
        }
    }
    
    private var fomoView: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let slow = sin(date / 5.0)
            let fast = sin(date * 1.5)
            
            ZStack {
                // Soft gradient orbs for depth with gentle breathing motion
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.20),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 210 + CGFloat(slow) * 10
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 42)
                    .offset(x: 90 + CGFloat(slow) * 6, y: -130 + CGFloat(slow) * 4)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.5, green: 0.8, blue: 0.5).opacity(0.17),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 170 + CGFloat(-slow) * 8
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 52)
                    .offset(x: -110 + CGFloat(-slow) * 5, y: 210 + CGFloat(slow) * 6)
                
                // Subtle moving highlight arc behind bullets
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.0)
                            ]),
                            center: .center,
                            angle: .degrees(Double(slow) * 40 + 90)
                        ),
                        lineWidth: 90
                    )
                    .blur(radius: 22)
                    .opacity(0.55)
                    .scaleEffect(1.1)
            }
            .overlay {
                VStack(spacing: 0) {
                    // Hero headline with soft fade + slide
                    VStack(spacing: 8) {
                        Text("ANITA")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Text("will analyze your finances")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            // small animated sparkle
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .opacity(0.7 + 0.3 * CGFloat(max(fast, 0)))
                                .scaleEffect(1.0 + 0.08 * CGFloat(max(fast, 0)))
                        }
                    }
                    .padding(.top, 56)
                    .padding(.horizontal, 26)
                    .padding(.bottom, 36)
                    .opacity(0.95)
                    .offset(y: CGFloat(-max(0, slow)) * 4)
                    
                    // Animated bullet list (simple, no boxes) – more vertical space
                    VStack(spacing: 40) {
                        AnimatedBulletRow(
                            icon: "sparkles",
                            color: Color.yellow,
                            title: "Suggest smart spending limits",
                            subtitle: "So you always know how much you can spend",
                            delay: 0.05
                        )
                        AnimatedBulletRow(
                            icon: "chart.line.downtrend.xyaxis",
                            color: Color.green,
                            title: "Show where money is leaking",
                            subtitle: "See exactly where it disappears every month",
                            delay: 0.20
                        )
                        AnimatedBulletRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            color: Color.blue,
                            title: "Answer money questions",
                            subtitle: "Ask about your finances anytime — day or night",
                            delay: 0.35
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    Spacer(minLength: 0)
                    
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        let survey = OnboardingSurveyResponse(
                            languageCode: selectedLanguage?.id ?? "en",
                            userName: trimmedUserName,
                            currencyCode: selectedCurrency,
                            answers: answers,
                            completedAt: Date()
                        )
                        onComplete(survey)
                    } label: {
                        HStack {
                            Text(getStartedTitle)
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .liquidGlass(cornerRadius: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.30), Color.white.opacity(0.14)],
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showingFomo)
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
    
    private var namePage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                Text(AppL10n.t("onboarding.name.title", languageCode: languageCode))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("👋")
                    .font(.system(size: 44))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            
            TextField(AppL10n.t("onboarding.name.placeholder", languageCode: languageCode), text: $userName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                )
                .autocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.horizontal, 24)
            
            Spacer()
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
            
            VStack(spacing: 12) {
                Text(AppL10n.t("onboarding.currency.title", languageCode: languageCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(AppL10n.t("onboarding.currency.subtitle", languageCode: languageCode))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            
            VStack(spacing: 14) {
                ForEach(currencyOptions) { option in
                    CurrencyOptionCard(
                        symbol: option.symbol,
                        code: option.id,
                        name: option.name,
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
            if !currencyOptions.contains(where: { $0.id == selectedCurrency }) {
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
        (currency == "CHF" || currency == "EUR") ? "1.234,56" : "1,234.56" // USD and others: US format
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
            // Dismiss keyboard when advancing (e.g. from name step)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            if isBankStepPage {
                let survey = OnboardingSurveyResponse(
                    languageCode: selectedLanguage?.id ?? "en",
                    userName: trimmedUserName,
                    currencyCode: selectedCurrency,
                    answers: answers,
                    completedAt: Date()
                )
                onComplete(survey)
            } else if !isLastPage {
                if includeBankConnectionStep && pageIndex == lastQuestionPageIndex {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showingPreBankHealthStory = true
                    }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        pageIndex = min(pageIndex + 1, totalPages - 1)
                    }
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showingFomo = true
                }
            }
        } label: {
            HStack {
                Text((isLastPage && !includeBankConnectionStep) || isBankStepPage ? getStartedTitle : nextTitle)
                    .font(.system(size: 17, weight: .semibold))
                
                if !isLastPage && !isBankStepPage {
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
    
    @ViewBuilder
    private var bankConnectionStepView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("Connect your bank")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Link your bank to sync transactions and balances. You can skip and do this later in Settings.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                BankConnectionOnboardingStep(onFinish: {
                    let survey = OnboardingSurveyResponse(
                        languageCode: selectedLanguage?.id ?? "en",
                        userName: trimmedUserName,
                        currencyCode: selectedCurrency,
                        answers: answers,
                        completedAt: Date()
                    )
                    onComplete(survey)
                })
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Bank connection step (used when includeBankConnectionStep is true)
private struct BankConnectionOnboardingStep: View {
    var onFinish: () -> Void
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isConnecting = false
    @State private var showUpgradeSheet = false
    @State private var shouldConnectBankAfterUpgrade = false
    @State private var isSkipAllowedInUpgradeSheet = false
    @State private var errorMessage: String?
    @State private var showDeleteManualConfirm = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button {
                if subscriptionManager.isPremium {
                    showDeleteManualConfirm = true
                } else {
                    isSkipAllowedInUpgradeSheet = false
                    shouldConnectBankAfterUpgrade = true
                    showUpgradeSheet = true
                }
            } label: {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Connect bank")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.11, green: 0.62, blue: 1.0),
                                    Color(red: 0.20, green: 0.47, blue: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                )
                .shadow(color: Color.blue.opacity(0.18), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            
            Button {
                // In the global "test bank connection" flow, we want the manual button
                // to show the exact same UI as the bank-connection path.
                // Otherwise the app would route to PostSignupPlansView ("Choose your plan").
                if UserManager.pendingTestBankConnectionFlow {
                    if subscriptionManager.isPremium {
                        showDeleteManualConfirm = true
                    } else {
                        isSkipAllowedInUpgradeSheet = true
                        shouldConnectBankAfterUpgrade = true
                        showUpgradeSheet = true
                    }
                } else {
                    UserManager.shared.setTransactionDataSource("manual")
                    onFinish()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Use manual input")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            
            if let msg = errorMessage {
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .alert(
            AppL10n.t("bank.connect_deletes_manual_title"),
            isPresented: $showDeleteManualConfirm
        ) {
            Button(AppL10n.t("common.cancel"), role: .cancel) {}
            Button(AppL10n.t("bank.connect_deletes_manual_continue")) {
                connectBankConfirmed()
            }
        } message: {
            Text(
                "\(AppL10n.t("bank.connect_deletes_manual_intro"))\n\n\(AppL10n.t("bank.connect_deletes_manual_warning"))"
            )
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView(onSkip: isSkipAllowedInUpgradeSheet ? {
                // User can proceed without paying (Free tier).
                shouldConnectBankAfterUpgrade = false
                // IMPORTANT: Stop the test-bank-flow logic from routing us to PostSignupPlansView.
                // ContentView shows PostSignupPlansView when `pendingTestBankConnectionFlow` is true.
                UserManager.setPendingTestBankConnectionFlow(false)
                UserManager.shared.shouldShowPostSignupPlans = false
                UserManager.shared.setTransactionDataSource("manual")
                onFinish()
            } : nil)
        }
        .onChange(of: showUpgradeSheet) { oldValue, newValue in
            guard oldValue == true, newValue == false else { return }
            Task { @MainActor in
                await subscriptionManager.refresh()
                if shouldConnectBankAfterUpgrade, subscriptionManager.isPremium {
                    shouldConnectBankAfterUpgrade = false
                    showDeleteManualConfirm = true
                } else {
                    shouldConnectBankAfterUpgrade = false
                }
                isSkipAllowedInUpgradeSheet = false
            }
        }
    }
    
    /// Runs after user accepts the warning that manual transactions will be deleted.
    private func connectBankConfirmed() {
        let userManager = UserManager.shared
        let userId = userManager.userId
        let userEmail = userManager.currentUser?.email
        guard !userId.isEmpty else {
            errorMessage = "Please sign in first."
            return
        }
        errorMessage = nil
        isConnecting = true
        Task { @MainActor in
            defer { isConnecting = false }
            do {
                let linked = try await BankConnectionTester.shared.startTestFlow(userId: userId, userEmail: userEmail)
                if linked {
                    UserManager.shared.setTransactionDataSource("bank")
                    do {
                        try await NetworkService.shared.deleteManualTransactionsOnBankLink(userId: userId)
                    } catch {
                        print("[Onboarding] deleteManualTransactionsOnBankLink failed: \(error.localizedDescription)")
                    }
                    do {
                        try await NetworkService.shared.refreshBankTransactions(userId: userId)
                    } catch {
                        print("[Onboarding] refreshBankTransactions failed: \(error.localizedDescription)")
                    }
                    NotificationCenter.default.post(name: .anitaBankSyncCompleted, object: nil)
                }
                onFinish()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AnimatedBulletRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let delay: Double
    
    @State private var isVisible: Bool = false
    @State private var hasAnimated: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(color)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .opacity(isVisible ? 1.0 : 0.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 0)
        .padding(.vertical, 6)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 18)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(delay)) {
                isVisible = true
            }
        }
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
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.25))
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
            .financeSolidGlassTile(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.2 : 0.7)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct CurrencyOptionCard: View {
    let symbol: String
    let code: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clear)
                        .frame(width: 56, height: 56)
                        .financeSolidGlassTile(cornerRadius: 12)
                    Text(symbol)
                        .font(.system(size: code == "CHF" ? 16 : 28, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    Text(code)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .financeSolidGlassTile(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.34 : 0.1), lineWidth: isSelected ? 1.1 : 0.65)
            )
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
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Spacer()
                
                // Selected indicator on the right side only (no grey arrows).
                ZStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                // Keep right-side layout stable even when not selected.
                .frame(width: 22, height: 22, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .financeSolidGlassTile(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.2 : 0.7)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView { _ in }
}
