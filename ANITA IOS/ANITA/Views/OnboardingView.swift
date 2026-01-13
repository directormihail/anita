//
//  OnboardingView.swift
//  ANITA
//
//  Onboarding flow for new users after sign-up
//

import SwiftUI
import Foundation

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var pageOffset: CGFloat = 0
    let onComplete: () -> Void
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            title: "Welcome to ANITA",
            description: "Your personal finance assistant that makes managing money simple. ANITA spots where money slips away and guides you to smarter decisions. Everything you need in one place.",
            gradientColors: [Color(red: 0.4, green: 0.49, blue: 0.92), Color(red: 0.6, green: 0.4, blue: 0.8)]
        ),
        OnboardingPage(
            icon: "message.fill",
            title: "AI Chat",
            description: "Tell ANITA about your spending and income naturally. Everything you mention gets recorded and added to your finance page instantly. No forms, no hassle.",
            gradientColors: [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.4, green: 0.49, blue: 0.92)]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Your Finance Dashboard",
            description: "Watch your money flow and catch leaks before they drain you. See AI recommended targets, all transactions sorted by category, and visual charts that reveal your spending patterns instantly.",
            gradientColors: [Color(red: 0.1, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.7, blue: 0.9)]
        ),
        OnboardingPage(
            icon: "target",
            title: "Smart Goals & Limits",
            description: "ANITA analyzes your finances and delivers advice you can act on immediately. Watch your progress update in real time. Set any goal and ANITA breaks it into achievable steps to make your dreams come true.",
            gradientColors: [Color(red: 0.9, green: 0.4, blue: 0.5), Color(red: 0.1, green: 0.8, blue: 0.6)]
        )
    ]
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], pageIndex: index, currentPage: currentPage)
                            .tag(index)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentPage)
                .onChange(of: currentPage) { _, newValue in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        pageOffset = CGFloat(newValue)
                    }
                }
                
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage -= 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Previous")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(white: 0.15).opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        } else {
                            // Complete onboarding
                            onComplete()
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background {
                            ZStack {
                                // Glass liquid effect
                                RoundedRectangle(cornerRadius: 14)
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
                                
                                // Glass reflection
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.05),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                                
                                // Border
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .shadow(color: Color.white.opacity(0.05), radius: 3, x: 0, y: -1)
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var contentOpacity: Double = 0
    @State private var iconRotation: Double = 0
    @State private var glowIntensity: Double = 0.3
    @State private var gradientRotation: Double = 0
    
    // Computed properties for gradient points
    private var gradientStartPoint: UnitPoint {
        let radians = gradientRotation * .pi / 180
        return UnitPoint(
            x: 0.5 + 0.5 * CGFloat(cos(radians)),
            y: 0.5 + 0.5 * CGFloat(sin(radians))
        )
    }
    
    private var gradientEndPoint: UnitPoint {
        let radians = gradientRotation * .pi / 180
        return UnitPoint(
            x: 0.5 - 0.5 * CGFloat(cos(radians)),
            y: 0.5 - 0.5 * CGFloat(sin(radians))
        )
    }
    
    private var gradientStartPointSlow: UnitPoint {
        let radians = (gradientRotation * 0.5) * .pi / 180
        return UnitPoint(
            x: 0.5 + 0.3 * CGFloat(cos(radians)),
            y: 0.5 + 0.3 * CGFloat(sin(radians))
        )
    }
    
    private var gradientEndPointSlow: UnitPoint {
        let radians = (gradientRotation * 0.5) * .pi / 180
        return UnitPoint(
            x: 0.5 - 0.3 * CGFloat(cos(radians)),
            y: 0.5 - 0.3 * CGFloat(sin(radians))
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                // Animated outer glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors.map { $0.opacity(glowIntensity) },
                            startPoint: gradientStartPoint,
                            endPoint: gradientEndPoint
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .opacity(iconOpacity)
                
                // Glass liquid circle with rotation
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.25).opacity(0.6),
                                Color(white: 0.15).opacity(0.4)
                            ],
                            startPoint: gradientStartPointSlow,
                            endPoint: gradientEndPointSlow
                        )
                    )
                    .frame(width: 160, height: 160)
                    .overlay {
                        // Glass reflection
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                        
                        // Animated border
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: gradientStartPoint,
                                    endPoint: gradientEndPoint
                                ),
                                lineWidth: 2
                            )
                    }
                    .shadow(color: page.gradientColors[0].opacity(0.4 * glowIntensity), radius: 30, x: 0, y: 15)
                    .shadow(color: Color.white.opacity(0.1), radius: 8, x: 0, y: -4)
                
                // Icon with rotation
                Image(systemName: page.icon)
                    .font(.system(size: 70, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: gradientStartPoint,
                            endPoint: gradientEndPoint
                        )
                    )
                    .rotationEffect(.degrees(iconRotation))
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .padding(.bottom, 48)
            
            // Title with fade animation
            Text(page.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
                .offset(y: contentOffset)
                .opacity(contentOpacity)
                .blur(radius: currentPage == pageIndex ? 0 : 2)
            
            // Description with fade animation
            Text(page.description)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .offset(y: contentOffset)
                .opacity(contentOpacity)
                .blur(radius: currentPage == pageIndex ? 0 : 2)
            
            Spacer()
        }
        .onAppear {
            // Reset animations when page appears
            iconScale = 0.8
            iconOpacity = 0
            contentOffset = 30
            contentOpacity = 0
            iconRotation = -10
            glowIntensity = 0.3
            
            // Icon entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                iconScale = 1.0
                iconOpacity = 1.0
                iconRotation = 0
            }
            
            // Content entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15)) {
                contentOffset = 0
                contentOpacity = 1.0
            }
            
            // Continuous glow pulse animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.5
            }
            
            // Continuous gradient rotation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if newValue == pageIndex {
                // Animate in when becoming active
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                    contentOffset = 0
                    contentOpacity = 1.0
                }
            } else {
                // Subtle scale down when not active
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    iconScale = 0.95
                    iconOpacity = 0.7
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
