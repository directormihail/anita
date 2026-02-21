//
//  WelcomeView.swift
//  ANITA
//
//  Welcome screen — moving orbs, FOMO palette, playful design
//

import SwiftUI
import Foundation

struct WelcomeView: View {
    var onShowLogin: () -> Void
    var onShowSignUp: () -> Void
    
    // Extended palette: FOMO blue/green + accent
    private static let orbBlue = Color(red: 0.3, green: 0.5, blue: 0.9)
    private static let orbGreen = Color(red: 0.5, green: 0.8, blue: 0.5)
    private static let orbPurple = Color(red: 0.55, green: 0.4, blue: 0.85)
    private static let orbCoral = Color(red: 0.9, green: 0.45, blue: 0.5)
    
    @State private var heroScale: CGFloat = 0.82
    @State private var heroOpacity: Double = 0
    @State private var contentOffset: CGFloat = 44
    @State private var heroTilt: Double = -4
    @State private var orbBreath: CGFloat = 1
    // Moving orbs — phase 0...1 for each
    @State private var orbPhase1: CGFloat = 0  // blue
    @State private var orbPhase2: CGFloat = 0  // green
    @State private var orbPhase3: CGFloat = 0  // purple
    @State private var orbPhase4: CGFloat = 0  // coral (small accent)
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Subtle shifting gradient overlay (very soft)
            MovingGradientOverlay(phase: orbPhase1)
                .ignoresSafeArea()
            
            // Orb 1 — blue, drifts top-right → down-right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.orbBlue.opacity(0.2),
                            Self.orbBlue.opacity(0.07),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 52)
                .scaleEffect(orbBreath)
                .offset(x: 70 + orbPhase1 * 60, y: -160 + orbPhase1 * 80)
            
            // Orb 2 — green, drifts bottom-left → up
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.orbGreen.opacity(0.16),
                            Self.orbGreen.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 340, height: 340)
                .blur(radius: 54)
                .scaleEffect(orbBreath * 0.98)
                .offset(x: -120 + (1 - orbPhase2) * 50, y: 200 - orbPhase2 * 70)
            
            // Orb 3 — purple, center-ish, slow drift
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.orbPurple.opacity(0.12),
                            Self.orbPurple.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .scaleEffect(0.9 + orbBreath * 0.1)
                .offset(x: -30 + orbPhase3 * 80, y: 20 + (1 - orbPhase3) * 60)
            
            // Orb 4 — coral accent, small, drifts opposite
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Self.orbCoral.opacity(0.1),
                            Self.orbCoral.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: 100 - orbPhase4 * 90, y: -40 - orbPhase4 * 50)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero: ANITA + subtitle — slightly larger, subtle tilt
                VStack(spacing: 10) {
                    Text("ANITA")
                        .font(.system(size: 78, weight: .bold, design: .rounded))
                        .tracking(8)
                        .foregroundColor(.white)
                    
                    Text(AppL10n.t("welcome.subtitle"))
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
                .rotationEffect(.degrees(heroTilt))
                .scaleEffect(heroScale)
                .opacity(heroOpacity)
                .padding(.bottom, 36)
                .offset(y: contentOffset)
                
                // Typing phrase in a soft card (FOMO card style)
                WelcomeTypingPhraseView(
                    phrases: [
                        AppL10n.t("onboarding.fomo.phrase1"),
                        AppL10n.t("onboarding.fomo.phrase2"),
                        AppL10n.t("onboarding.fomo.phrase3"),
                        AppL10n.t("onboarding.fomo.phrase4"),
                        AppL10n.t("onboarding.fomo.phrase5")
                    ],
                    fontSize: 28,
                    textColor: .white
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
                .offset(y: contentOffset)
                .opacity(heroOpacity)
                
                // Buttons — translucent liquid glass so background orbs show through (like phrase card)
                VStack(spacing: 16) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onShowSignUp()
                    }) {
                        HStack {
                            Text(AppL10n.t("welcome.get_started"))
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                        .shadow(color: Color.white.opacity(0.06), radius: 4, x: 0, y: -1)
                    }
                    .buttonStyle(PremiumButtonStyle())
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onShowLogin()
                    }) {
                        HStack {
                            Text(AppL10n.t("welcome.sign_in"))
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                        .shadow(color: Color.white.opacity(0.06), radius: 4, x: 0, y: -1)
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.horizontal, 16)
                .offset(y: contentOffset)
                .opacity(heroOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            heroScale = 0.82
            heroOpacity = 0
            contentOffset = 44
            heroTilt = -4
            orbBreath = 1
            orbPhase1 = 0
            orbPhase2 = 0
            orbPhase3 = 0
            orbPhase4 = 0
            
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                heroScale = 1.0
                heroOpacity = 1.0
                heroTilt = 0
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.12)) {
                contentOffset = 0
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                orbBreath = 1.08
            }
            // Moving orbs — different durations for organic feel
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                orbPhase1 = 1
            }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true).delay(0.5)) {
                orbPhase2 = 1
            }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true).delay(1)) {
                orbPhase3 = 1
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(0.3)) {
                orbPhase4 = 1
            }
        }
    }
}

// MARK: - Subtle moving gradient overlay
private struct MovingGradientOverlay: View {
    let phase: CGFloat
    private static let blue = Color(red: 0.3, green: 0.5, blue: 0.9)
    private static let green = Color(red: 0.5, green: 0.8, blue: 0.5)
    
    var body: some View {
        let angle = Double(phase) * .pi * 2
        let c = CGFloat(cos(angle))
        let s = CGFloat(sin(angle))
        return LinearGradient(
            colors: [
                Self.blue.opacity(0.04),
                Color.clear,
                Self.green.opacity(0.03),
                Color.clear
            ],
            startPoint: UnitPoint(x: 0.5 + 0.5 * c, y: 0.5 + 0.5 * s),
            endPoint: UnitPoint(x: 0.5 - 0.5 * c, y: 0.5 - 0.5 * s)
        )
    }
}

// MARK: - Typing + delete animation (appearing/disappearing phrases)
private struct WelcomeTypingPhraseView: View {
    let phrases: [String]
    var fontSize: CGFloat = 18
    var textColor: Color = Color.white.opacity(0.75)
    var fontWeight: Font.Weight = .semibold
    
    @State private var phraseIndex = 0
    @State private var visibleCount = 0
    @State private var isDeleting = false
    @State private var pauseTicksRemaining = 0
    @State private var cursorVisible = true
    @State private var tickCount = 0
    
    private let tickInterval: TimeInterval = 0.06
    private let pauseAfterTypingTicks: Int = 35
    
    private var currentPhrase: String {
        guard !phrases.isEmpty else { return "" }
        return phrases[phraseIndex]
    }
    
    private var displayedText: String {
        let phrase = currentPhrase
        let end = phrase.index(phrase.startIndex, offsetBy: min(visibleCount, phrase.count))
        return String(phrase[phrase.startIndex..<end])
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(textColor)
            Text("|")
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundColor(textColor.opacity(0.9))
                .opacity(cursorVisible ? 1 : 0.3)
        }
        .frame(minHeight: fontSize + 8)
        .onAppear {
            guard !phrases.isEmpty else { return }
            visibleCount = 0
            phraseIndex = 0
            isDeleting = false
            pauseTicksRemaining = 0
        }
        .onReceive(Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()) { _ in
            guard !phrases.isEmpty else { return }
            tickCount += 1
            if tickCount % 8 == 0 { cursorVisible.toggle() }
            let phrase = currentPhrase
            if pauseTicksRemaining > 0 {
                pauseTicksRemaining -= 1
                return
            }
            if isDeleting {
                if visibleCount > 0 {
                    visibleCount -= 1
                } else {
                    isDeleting = false
                    phraseIndex = (phraseIndex + 1) % phrases.count
                }
            } else {
                if visibleCount < phrase.count {
                    visibleCount += 1
                } else {
                    pauseTicksRemaining = pauseAfterTypingTicks
                    isDeleting = true
                }
            }
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Premium icon with animation
            ZStack {
                // Glass circle background with glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.2).opacity(0.4),
                                Color(white: 0.15).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.white.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(iconScale)
            
            // Text content - simplified
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(delay)) {
                opacity = 1.0
                offset = 0
                iconScale = 1.0
            }
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(
        onShowLogin: {},
        onShowSignUp: {}
    )
}
