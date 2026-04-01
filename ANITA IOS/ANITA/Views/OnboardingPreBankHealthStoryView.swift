//
//  OnboardingPreBankHealthStoryView.swift
//  ANITA
//
//  Playful “before / after” health moment + friend-style chat before bank / manual step.
//

import SwiftUI

// MARK: - Main

struct OnboardingPreBankHealthStoryView: View {
    let languageCode: String
    let currencyCode: String
    let userName: String
    let onContinue: () -> Void
    let onBack: () -> Void
    
    @State private var sequenceGeneration: Int = 0
    @State private var cardVisible: Bool = false
    @State private var displayedScore: Double = 30
    @State private var ringProgress: Double = 0.3
    @State private var balanceAmount: Double = -1247.83
    @State private var healingStarted: Bool = false
    @State private var showContinueCTA: Bool = false
    @State private var healTimer: Timer?
    
    @State private var showAnitaTyping1: Bool = false
    @State private var showAnitaOpening: Bool = false
    @State private var showReplyChips: Bool = false
    @State private var selectedReply: String?
    @State private var showUserBubble: Bool = false
    @State private var showAnitaTyping2: Bool = false
    @State private var showAnitaClosing: Bool = false
    @State private var pendingHealGeneration: Int?
    
    @State private var ringWiggle: CGFloat = 0
    @State private var scoreCelebrationScale: CGFloat = 1.0
    
    private var trimmedName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var anitaOpeningText: String {
        if trimmedName.isEmpty {
            return AppL10n.t("onboarding.pre_bank.anita_opening", languageCode: languageCode)
        }
        // Avoid String(format:) — names with "%" or format tokens corrupt the copy.
        return AppL10n.t("onboarding.pre_bank.anita_opening_named", languageCode: languageCode)
            .replacingOccurrences(of: "%@", with: trimmedName)
    }
    
    private var scoreColor: Color {
        let s = Int(displayedScore.rounded())
        if s >= 70 { return .green }
        if s >= 40 { return .orange }
        return .red
    }
    
    private var greenAccent: Color { Color(red: 0.18, green: 0.78, blue: 0.38) }
    private var redAccent: Color { Color(red: 1.0, green: 0.22, blue: 0.28) }
    
    private var progressNormalized: Double {
        min(max(ringProgress, 0), 1)
    }
    
    private func formatMoney(_ amount: Double) -> String {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "USD" : currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = AnitaCurrencyDisplay.locale(forCurrencyCode: code)
        formatter.usesGroupingSeparator = true
        let raw = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return AnitaCurrencyDisplay.tightenFormattedCurrency(raw, currencyCode: code)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        healthCard
                            .scaleEffect(cardVisible ? 1 : 0.96)
                            .opacity(cardVisible ? 1 : 0)
                            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: cardVisible)
                        
                        chatSection
                    }
                    .padding(.bottom, 28)
                }
                
                if showContinueCTA {
                    continueButton
                }
            }
        }
        .onAppear {
            runIntroSequence()
        }
        .onDisappear {
            cancelTimersAndSequence()
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                cancelTimersAndSequence()
                onBack()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text(AppL10n.t("common.back", languageCode: languageCode))
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Health card
    
    /// Matches `FinanceView.balanceCardView` layout: health block, hairline, then primary metric.
    private var healthCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    Text(AppL10n.t("onboarding.pre_bank.health_label", languageCode: languageCode).uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.3)
                    Spacer()
                    zoneBadge
                }
                
                healthScoreRing
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 4)
            
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(AppL10n.t("onboarding.pre_bank.balance_label", languageCode: languageCode).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)
                Text(formatMoney(balanceAmount))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(balanceAmount < 0 ? redAccent : greenAccent)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .financeSolidGlassSection(cornerRadius: 24)
        .padding(.horizontal, 20)
    }
    
    private var chatSection: some View {
        chatBlock
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var zoneBadge: some View {
        if !healingStarted {
            Text(AppL10n.t("onboarding.pre_bank.zone_red", languageCode: languageCode))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(redAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(white: 0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        } else {
            Text(AppL10n.t("onboarding.pre_bank.zone_safe", languageCode: languageCode))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(greenAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(white: 0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        }
    }
    
    /// Same ring stack as `FinanceView` loaded health score (192 / 172, 8pt stroke, 4-stop gradient).
    private var healthScoreRing: some View {
        let progressPercentage = progressNormalized
        
        return ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.15), lineWidth: 22)
                .frame(width: 192, height: 192)
                .blur(radius: 16)
            Circle()
                .stroke(
                    Color.white.opacity(0.05),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 172, height: 172)
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 1.0, green: 0.25, blue: 0.35), location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.55, blue: 0.28), location: 0.38),
                            .init(color: Color(red: 0.22, green: 0.78, blue: 0.42), location: 0.72),
                            .init(color: Color(red: 1.0, green: 0.25, blue: 0.35), location: 1.0)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 172, height: 172)
                .rotationEffect(.degrees(-90 + ringWiggle))
                .shadow(color: scoreColor.opacity(0.4), radius: 6, x: 0, y: 0)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: progressPercentage)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: ringWiggle)
            
            VStack(spacing: 0) {
                Text("\(Int(displayedScore.rounded()))")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(scoreColor)
                    .contentTransition(.numericText())
                    .shadow(color: scoreColor.opacity(0.5), radius: 10, x: 0, y: 0)
                Text("/100")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            .scaleEffect(scoreCelebrationScale)
        }
        .frame(height: 188)
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
        .onTapGesture {
            guard !healingStarted else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
                ringWiggle = ringWiggle == 0 ? 4 : 0
                scoreCelebrationScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    scoreCelebrationScale = 1.0
                }
            }
        }
    }
    
    // MARK: - Chat
    
    private var chatBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showAnitaTyping1 {
                friendTypingRow
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            if showAnitaOpening {
                OnboardingFriendTypewriterBubble(fullText: anitaOpeningText, onTypingComplete: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        showReplyChips = true
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                    removal: .opacity
                ))
            }
            if showReplyChips {
                replyChipsRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showUserBubble, let reply = selectedReply {
                userFriendBubble(reply)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                        removal: .opacity
                    ))
            }
            if showAnitaTyping2 {
                friendTypingRow
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            if showAnitaClosing {
                OnboardingFriendTypewriterBubble(
                    fullText: AppL10n.t("onboarding.pre_bank.anita_closing", languageCode: languageCode),
                    onTypingComplete: {
                        let g = pendingHealGeneration ?? sequenceGeneration
                        pendingHealGeneration = nil
                        startHealingAnimation(generation: g)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showAnitaTyping1)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showAnitaOpening)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showReplyChips)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showUserBubble)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showAnitaTyping2)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: showAnitaClosing)
    }
    
    private var friendTypingRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("ANITA")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.8)
            FriendTypingDots()
        }
        .padding(.vertical, 4)
    }
    
    private func userFriendBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 16)
            Text(text)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .financeSolidGlassTile(cornerRadius: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.85)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .trailing)
        }
    }
    
    private var replyChipsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppL10n.t("onboarding.pre_bank.reply_hint", languageCode: languageCode))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            
            VStack(spacing: 10) {
                FriendReplyChip(
                    text: AppL10n.t("onboarding.pre_bank.user_reply_a", languageCode: languageCode)
                ) {
                    userPickedReply(
                        AppL10n.t("onboarding.pre_bank.user_reply_a", languageCode: languageCode)
                    )
                }
                FriendReplyChip(
                    text: AppL10n.t("onboarding.pre_bank.user_reply_b", languageCode: languageCode)
                ) {
                    userPickedReply(
                        AppL10n.t("onboarding.pre_bank.user_reply_b", languageCode: languageCode)
                    )
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func userPickedReply(_ text: String) {
        let gen = sequenceGeneration
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            showReplyChips = false
            selectedReply = text
            showUserBubble = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard gen == sequenceGeneration else { return }
            showAnitaTyping2 = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + 0.95) {
            guard gen == sequenceGeneration else { return }
            pendingHealGeneration = gen
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                showAnitaTyping2 = false
                showAnitaClosing = true
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    // MARK: - Continue
    
    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onContinue()
        } label: {
            Text(AppL10n.t("onboarding.pre_bank.continue", languageCode: languageCode))
                .font(.system(size: 17, weight: .semibold))
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
                .contentShape(Rectangle())
        }
        .buttonStyle(PremiumButtonStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Sequence
    
    private func runIntroSequence() {
        cancelTimersAndSequence()
        sequenceGeneration &+= 1
        let gen = sequenceGeneration
        
        displayedScore = 30
        ringProgress = 0.3
        balanceAmount = -1247.83
        healingStarted = false
        showContinueCTA = false
        cardVisible = false
        showAnitaTyping1 = false
        showAnitaOpening = false
        showReplyChips = false
        selectedReply = nil
        showUserBubble = false
        showAnitaTyping2 = false
        showAnitaClosing = false
        pendingHealGeneration = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard gen == sequenceGeneration else { return }
            cardVisible = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard gen == sequenceGeneration else { return }
            showAnitaTyping1 = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + 1.15) {
            guard gen == sequenceGeneration else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                showAnitaTyping1 = false
                showAnitaOpening = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    private func startHealingAnimation(generation gen: Int) {
        healTimer?.invalidate()
        healingStarted = true
        
        let startScore = 30.0
        let endScore = 100.0
        let startBal = balanceAmount
        let endBal = 2840.0
        let duration: TimeInterval = 2.15
        let startTime = Date()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            scoreCelebrationScale = 1.06
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard gen == sequenceGeneration else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                scoreCelebrationScale = 1.0
            }
        }
        
        healTimer = Timer.scheduledTimer(withTimeInterval: 0.014, repeats: true) { t in
            guard gen == sequenceGeneration else {
                t.invalidate()
                return
            }
            let raw = min(Date().timeIntervalSince(startTime) / duration, 1)
            let eased = 1 - pow(1 - raw, 2.4)
            displayedScore = startScore + (endScore - startScore) * eased
            ringProgress = displayedScore / 100.0
            balanceAmount = startBal + (endBal - startBal) * eased
            
            if raw >= 1.0 {
                displayedScore = endScore
                ringProgress = 1.0
                balanceAmount = endBal
                t.invalidate()
                healTimer = nil
                
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) {
                    scoreCelebrationScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    guard gen == sequenceGeneration else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.64)) {
                        scoreCelebrationScale = 1.0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    guard gen == sequenceGeneration else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        showContinueCTA = true
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
        if let healTimer {
            RunLoop.main.add(healTimer, forMode: .common)
        }
    }
    
    private func cancelTimersAndSequence() {
        sequenceGeneration &+= 1
        healTimer?.invalidate()
        healTimer = nil
    }
}

// MARK: - Subviews

/// Character-at-a-time reveal matching `TypewriterWelcomeMessageView` in `ChatView`.
private struct OnboardingFriendTypewriterBubble: View {
    let fullText: String
    let onTypingComplete: () -> Void
    
    @State private var visibleUnitCount = 0
    @State private var typingTask: Task<Void, Never>?
    @State private var didCallComplete = false
    
    private var sequences: [String] {
        Self.splitComposedSequences(fullText)
    }
    
    private var visibleText: String {
        let seq = sequences
        guard visibleUnitCount > 0, !seq.isEmpty else { return "" }
        let n = min(visibleUnitCount, seq.count)
        return seq.prefix(n).joined()
    }
    
    private var typingComplete: Bool {
        !sequences.isEmpty && visibleUnitCount >= sequences.count
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("ANITA")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.38))
                    .tracking(1.1)
                    .padding(.bottom, 6)
                Text(visibleText)
                    .font(.body)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(6)
                    .kerning(0.2)
                    .transaction { $0.animation = nil }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .financeSolidGlassTile(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.85)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            Spacer(minLength: 8)
        }
        .onAppear(perform: startTyping)
        .onDisappear {
            typingTask?.cancel()
            typingTask = nil
        }
        .onChange(of: fullText) { _, _ in
            restartTyping()
        }
        .onChange(of: typingComplete) { _, done in
            guard done, !didCallComplete else { return }
            didCallComplete = true
            onTypingComplete()
        }
    }
    
    private func restartTyping() {
        typingTask?.cancel()
        didCallComplete = false
        visibleUnitCount = 0
        startTyping()
    }
    
    private func startTyping() {
        typingTask?.cancel()
        let seq = Self.splitComposedSequences(fullText)
        guard !seq.isEmpty else {
            visibleUnitCount = 0
            if !didCallComplete {
                didCallComplete = true
                onTypingComplete()
            }
            return
        }
        typingTask = Task {
            for i in 1...seq.count {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    visibleUnitCount = i
                }
                if i < seq.count {
                    let pause = Self.delayNanos(after: seq[i - 1])
                    try? await Task.sleep(nanoseconds: pause)
                }
            }
        }
    }
    
    private static func delayNanos(after unit: String) -> UInt64 {
        if unit == "\n" { return 95_000_000 }
        if unit == " " { return 14_000_000 }
        if let c = unit.first, ".!?".contains(c) { return 52_000_000 }
        return 28_000_000
    }
    
    private static func splitComposedSequences(_ s: String) -> [String] {
        var out: [String] = []
        s.enumerateSubstrings(in: s.startIndex..<s.endIndex, options: .byComposedCharacterSequences) { substring, _, _, _ in
            if let substring { out.append(String(substring)) }
        }
        return out
    }
}

private struct FriendTypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 8, height: 8)
                        .offset(y: sin(t * 5.5 + Double(i) * 0.9) * 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(Color(white: 0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
        }
    }
}

private struct FriendReplyChip: View {
    let text: String
    let action: () -> Void
    
    @State private var pressed = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.96))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .financeSolidGlassTile(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

#Preview {
    OnboardingPreBankHealthStoryView(
        languageCode: "en",
        currencyCode: "USD",
        userName: "Alex",
        onContinue: {},
        onBack: {}
    )
}
