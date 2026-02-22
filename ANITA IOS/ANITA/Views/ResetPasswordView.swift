//
//  ResetPasswordView.swift
//  ANITA
//
//  Shown when user opens app from password reset link; they set a new password here.
//

import SwiftUI

struct ResetPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case password, confirm
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text(AppL10n.t("login.reset.new_title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(AppL10n.t("login.reset.new_help"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField(AppL10n.t("login.password"), text: $password)
                                    .textContentType(.newPassword)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .password)
                            } else {
                                SecureField(AppL10n.t("login.password"), text: $password)
                                    .textContentType(.newPassword)
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
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(.white.opacity(0.1)),
                            alignment: .bottom
                        )
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField(AppL10n.t("login.password"), text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .confirm)
                            } else {
                                SecureField(AppL10n.t("login.password"), text: $confirmPassword)
                                    .textContentType(.newPassword)
                                    .foregroundColor(.white)
                                    .font(.system(size: 17))
                                    .focused($focusedField, equals: .confirm)
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
                    .padding(.bottom, 24)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        focusedField = nil
                        guard password == confirmPassword else {
                            viewModel.errorMessage = AppL10n.t("login.reset.password_mismatch")
                            return
                        }
                        Task {
                            await viewModel.updatePassword(password)
                            if viewModel.errorMessage == nil {
                                // Recovery mode cleared; ContentView will show main app
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text(AppL10n.t("login.reset.update_button"))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.2).opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading || password.isEmpty || confirmPassword.isEmpty)
                    .opacity((viewModel.isLoading || password.isEmpty || confirmPassword.isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

#Preview {
    ResetPasswordView()
}
