//
//  LoginView.swift
//  ANITA
//
//  Login screen with native iOS form design
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showForgotPassword: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var onAuthSuccess: () -> Void
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Back Button
                    if let onBack = onBack {
                        HStack {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                onBack()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(white: 0.15).opacity(0.3))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome to ANITA")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Personal Finance Assistant")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    
                    // Auth Form - iOS Style
                    VStack(spacing: 0) {
                        // Email Field
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            TextField("Email", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .foregroundColor(.white)
                                .font(.system(size: 17))
                                .focused($focusedField, equals: .email)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.1).opacity(0.3))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.white.opacity(0.1)),
                            alignment: .bottom
                        )
                        
                        // Password Field
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .password)
                            } else {
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .password)
                            }
                            
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.1).opacity(0.3))
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.1).opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showForgotPassword = true
                        }) {
                            Text("Forgot Password?")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // Login Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        focusedField = nil
                        Task {
                            await viewModel.signIn(email: email, password: password)
                            if viewModel.isAuthenticated {
                                onAuthSuccess()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text("Login")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.2).opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((viewModel.isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                        
                        Text("OR")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    // Google Sign In Button
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        Task {
                            await viewModel.signInWithGoogle()
                            if viewModel.isAuthenticated {
                                onAuthSuccess()
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            GoogleLogoView(size: 20)
                            
                            Text("Log in with Google")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.15).opacity(0.3))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.9))
                            
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("By continuing, you agree to our")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Show terms
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            
                            Text("and")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Button("Privacy Policy") {
                                // TODO: Show privacy
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Forgot Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            Button("Send Reset Link") {
                // TODO: Implement password reset
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email address and we'll send you a password reset link.")
        }
    }
}

#Preview {
    LoginView(onAuthSuccess: {}, onBack: nil)
}
