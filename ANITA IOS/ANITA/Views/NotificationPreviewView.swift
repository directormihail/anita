//
//  NotificationPreviewView.swift
//  ANITA
//
//  View to preview all notification types
//

import SwiftUI

struct NotificationPreviewView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var notificationService = NotificationService.shared
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("Notification Previews")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Invisible button for centering
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.clear)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Status
                    if !notificationService.pushNotificationsEnabled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Push notifications are disabled")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    } else if !notificationService.isAuthorized {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Notification permissions not granted")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Notification Categories
                    VStack(spacing: 20) {
                        // Budget Limit Notifications
                        NotificationCategorySection(
                            title: "Budget Limit Alerts",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            notifications: [
                                NotificationPreview(
                                    title: "Your Budget is Screaming",
                                    body: "💸 Your Food budget called. It wants a divorce. You've spent $800.00 of $1,000.00.",
                                    type: "Budget Limit (120%+)",
                                    time: "Just now"
                                ),
                                NotificationPreview(
                                    title: "Budget Limit Reached",
                                    body: "🎯 Congratulations! You've hit your Shopping budget limit! $500.00 of $500.00. Now what?",
                                    type: "Budget Limit (100%)",
                                    time: "Just now"
                                ),
                                NotificationPreview(
                                    title: "Budget Check-in",
                                    body: "👀 Hey there, big spender! You're at 80% of your Entertainment budget. $400.00 of $500.00. Still time to reconsider?",
                                    type: "Budget Limit (80%)",
                                    time: "Just now"
                                )
                            ]
                        )
                        
                        // Goal Milestone Notifications
                        NotificationCategorySection(
                            title: "Goal Milestones",
                            icon: "target",
                            color: .green,
                            notifications: [
                                NotificationPreview(
                                    title: "Goal Achieved! 🎉",
                                    body: "🏆 LEGEND! You've saved $10,000.00 for Emergency Fund! Your future self is doing a happy dance!",
                                    type: "Goal Milestone (100%)",
                                    time: "Just now"
                                ),
                                NotificationPreview(
                                    title: "Goal Progress: Vacation Fund",
                                    body: "🎯 50% there! You've saved $2,500.00 of $5,000.00 for Vacation Fund. Keep going, champ!",
                                    type: "Goal Milestone (50%)",
                                    time: "Just now"
                                ),
                                NotificationPreview(
                                    title: "Goal Progress: New Car",
                                    body: "📈 Progress update: 25% of New Car complete! $5,000.00 of $20,000.00. You got this!",
                                    type: "Goal Milestone (25%)",
                                    time: "Just now"
                                )
                            ]
                        )
                        
                        // Unusual Spending Notifications
                        NotificationCategorySection(
                            title: "Unusual Spending Alerts",
                            icon: "chart.bar.fill",
                            color: .purple,
                            notifications: [
                                NotificationPreview(
                                    title: "Spending Pattern Alert",
                                    body: "🤔 Interesting... You've spent $1,200.00 on Shopping this month. That's... a lot. Just an observation.",
                                    type: "Unusual Spending",
                                    time: "Just now"
                                )
                            ]
                        )
                        
                        // Monthly Summary Notifications
                        NotificationCategorySection(
                            title: "Monthly Summaries",
                            icon: "calendar",
                            color: .blue,
                            notifications: [
                                NotificationPreview(
                                    title: "Monthly Summary Ready",
                                    body: "📊 Your monthly financial report is ready! Spoiler: your wallet has opinions.",
                                    type: "Monthly Summary",
                                    time: "1st of month, 9:00 AM"
                                )
                            ]
                        )
                        
                        // Bill Reminders
                        NotificationCategorySection(
                            title: "Bill Reminders",
                            icon: "creditcard.fill",
                            color: .red,
                            notifications: [
                                NotificationPreview(
                                    title: "Bill Reminder: Electricity",
                                    body: "💳 Friendly reminder: Electricity bill ($120.00) is due in 3 days. Your future self will thank you.",
                                    type: "Bill Reminder",
                                    time: "3 days before due date"
                                )
                            ]
                        )
                        
                        // Transaction Reminders
                        NotificationCategorySection(
                            title: "Transaction Reminders",
                            icon: "plus.circle.fill",
                            color: .yellow,
                            notifications: [
                                NotificationPreview(
                                    title: "Let's Get Started!",
                                    body: "👋 Hey! It's been a day since you started. Want to add your first transaction? Your budget is waiting...",
                                    type: "Transaction Reminder (First)",
                                    time: "1 day with no transactions"
                                ),
                                NotificationPreview(
                                    title: "Transaction Reminder",
                                    body: "👀 It's been 3 days since your last transaction. Everything okay? Your budget misses you.",
                                    type: "Transaction Reminder (Gentle)",
                                    time: "3-6 days without transactions"
                                ),
                                NotificationPreview(
                                    title: "Transaction Alert!",
                                    body: "🚨 ALERT: It's been 7 days since your last transaction! Your budget is having an existential crisis.",
                                    type: "Transaction Reminder (Urgent)",
                                    time: "7+ days without transactions"
                                )
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct NotificationCategorySection: View {
    let title: String
    let icon: String
    let color: Color
    let notifications: [NotificationPreview]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ForEach(notifications) { notification in
                    NotificationPreviewCard(notification: notification)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct NotificationPreview: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let type: String
    let time: String
}

struct NotificationPreviewCard: View {
    let notification: NotificationPreview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(notification.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(notification.time)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(notification.body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text(notification.type)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.4, green: 0.49, blue: 0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.4, green: 0.49, blue: 0.92).opacity(0.2))
                    )
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NotificationPreviewView()
}
