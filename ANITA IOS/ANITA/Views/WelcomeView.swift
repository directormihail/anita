//
//  WelcomeView.swift
//  ANITA
//
//  Welcome/Onboarding screen with premium glass liquid design
//

import SwiftUI

struct WelcomeView: View {
    var onShowLogin: () -> Void
    var onShowSignUp: () -> Void
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOffset: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and Title with animation
                VStack(spacing: 24) {
                    // Glass liquid logo
                    ZStack {
                        // Outer glow
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.3).opacity(0.4),
                                        Color(white: 0.2).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 110, height: 110)
                            .blur(radius: 25)
                            .offset(y: 12)
                        
                        // Glass liquid effect
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.25).opacity(0.6),
                                        Color(white: 0.15).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay {
                                // Glass reflection
                                RoundedRectangle(cornerRadius: 22)
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
                                
                                // Border
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                            .shadow(color: Color.white.opacity(0.1), radius: 5, x: 0, y: -2)
                        
                        // Letter A
                        Text("A")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Color.white.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    VStack(spacing: 10) {
                        Text("Welcome to ANITA")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Personal Finance Assistant")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .offset(y: contentOffset)
                    .opacity(logoOpacity)
                }
                .padding(.bottom, 52)
                
                // Features as bullet points with descriptions
                VStack(alignment: .leading, spacing: 20) {
                    FeatureBullet(
                        icon: "message.fill",
                        title: "AI-Powered Chat",
                        description: "Get instant financial advice and answers to your money questions through intelligent conversations",
                        delay: 0.1
                    )
                    
                    FeatureBullet(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Financial Insights",
                        description: "Track your spending patterns, income trends, and receive personalized recommendations",
                        delay: 0.2
                    )
                    
                    FeatureBullet(
                        icon: "target",
                        title: "Goal Tracking",
                        description: "Set and monitor your financial goals with real-time progress updates and milestones",
                        delay: 0.3
                    )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .offset(y: contentOffset)
                .opacity(logoOpacity)
                
                // Action Buttons
                VStack(spacing: 14) {
                    // Get Started Button (Primary)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onShowSignUp()
                    }) {
                        HStack {
                            Spacer()
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 58)
                        .background {
                            ZStack {
                                // Glass liquid effect
                                RoundedRectangle(cornerRadius: 16)
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
                                RoundedRectangle(cornerRadius: 16)
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
                                RoundedRectangle(cornerRadius: 16)
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
                    
                    // Sign In Button (Secondary)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onShowLogin()
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign In")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 58)
                        .background {
                            ZStack {
                                // Glass liquid effect
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(white: 0.15).opacity(0.3),
                                                Color(white: 0.1).opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                // Border
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.horizontal, 28)
                .offset(y: contentOffset)
                .opacity(logoOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
                contentOffset = 0
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Bullet point icon
            VStack {
                ZStack {
                    // Glass circle background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.2).opacity(0.3),
                                    Color(white: 0.15).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Spacer()
            }
            .padding(.top, 2)
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                opacity = 1.0
                offset = 0
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
