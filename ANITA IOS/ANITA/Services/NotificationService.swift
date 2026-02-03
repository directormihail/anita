//
//  NotificationService.swift
//  ANITA
//
//  Service for managing local push notifications
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    @Published var pushNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(pushNotificationsEnabled, forKey: "anita_push_notifications_enabled")
            if pushNotificationsEnabled {
                requestAuthorization()
                scheduleDailyTransactionReminder()
            }
        }
    }
    
    override init() {
        self.pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "anita_push_notifications_enabled")
        super.init()
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Check current authorization status
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        print("[NotificationService] Requesting notification authorization...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    print("[NotificationService] ❌ Authorization error: \(error.localizedDescription)")
                } else {
                    print("[NotificationService] ✅ Authorization result: \(granted ? "GRANTED" : "DENIED")")
                    if granted {
                        self?.scheduleDailyTransactionReminder()
                        print("[NotificationService] Daily transaction reminder scheduled")
                    } else {
                        print("[NotificationService] ⚠️ User denied notification permissions")
                    }
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
                print("[NotificationService] Authorization status checked: \(settings.authorizationStatus.rawValue) -> authorized: \(self?.isAuthorized ?? false)")
                
                if settings.authorizationStatus == .denied {
                    print("[NotificationService] ⚠️ Notifications are denied. User needs to enable in Settings app.")
                } else if settings.authorizationStatus == .notDetermined {
                    print("[NotificationService] ⚠️ Notification permission not determined yet.")
                }
            }
        }
    }
    
    // MARK: - Daily Transaction Reminder
    
    private static let dailyReminderIdentifier = "daily_transaction_reminder"
    private static let dailyReminderTitleCount = 5
    private static let dailyReminderBodyCount = 28
    
    /// UserDefaults keys for storing the single daily reminder time (one notification per day, same time every day).
    private static let dailyReminderHourKey = "anita_daily_reminder_hour"
    private static let dailyReminderMinuteKey = "anita_daily_reminder_minute"
    
    private static func randomDailyReminderTitle() -> String {
        let index = Int.random(in: 1...Self.dailyReminderTitleCount)
        return AppL10n.t("notif.daily.title.\(index)")
    }
    
    private static func randomDailyReminderBody() -> String {
        let index = Int.random(in: 1...Self.dailyReminderBodyCount)
        return AppL10n.t("notif.daily.body.\(index)")
    }
    
    /// Picks and persists a random time between 6 PM and 8 PM (local). Used so we schedule only one time per day, once.
    private static func getOrCreateDailyReminderTime() -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: dailyReminderHourKey) != nil,
           defaults.object(forKey: dailyReminderMinuteKey) != nil {
            let h = defaults.integer(forKey: dailyReminderHourKey)
            let m = defaults.integer(forKey: dailyReminderMinuteKey)
            if (18...20).contains(h), (0...59).contains(m) {
                return (h, m)
            }
        }
        let hour: Int
        let minute: Int
        switch Int.random(in: 0...2) {
        case 0:
            hour = 18
            minute = Int.random(in: 0...59)
        case 1:
            hour = 19
            minute = Int.random(in: 0...59)
        default:
            hour = 20
            minute = 0
        }
        defaults.set(hour, forKey: dailyReminderHourKey)
        defaults.set(minute, forKey: dailyReminderMinuteKey)
        return (hour, minute)
    }
    
    /// Schedules a single daily transaction reminder: one notification per day at a random time between 6 PM and 8 PM (local), using one repeating trigger.
    func scheduleDailyTransactionReminder() {
        guard pushNotificationsEnabled && isAuthorized else { return }
        
        let timeZone = TimeZone.current
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
        
        let (hour, minute) = Self.getOrCreateDailyReminderTime()
        var dateComponents = DateComponents(timeZone: timeZone, hour: hour, minute: minute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = Self.randomDailyReminderTitle()
        content.body = Self.randomDailyReminderBody()
        content.sound = .default
        content.categoryIdentifier = "DAILY_TRANSACTION_REMINDER"
        content.userInfo = ["type": "daily_transaction_reminder"]
        
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Error scheduling daily reminder: \(error.localizedDescription)")
            }
        }
        print("[NotificationService] Daily transaction reminder scheduled once per day at \(hour):\(String(format: "%02d", minute)) local, timezone: \(timeZone.identifier)")
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() {
        print("[NotificationService] Sending test notification...")
        print("[NotificationService] Status - Enabled: \(pushNotificationsEnabled), Authorized: \(isAuthorized)")
        
        guard pushNotificationsEnabled else {
            print("[NotificationService] ❌ Push notifications are disabled in settings")
            return
        }
        
        guard isAuthorized else {
            print("[NotificationService] ❌ Notifications not authorized. Requesting authorization...")
            requestAuthorization()
            // Try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendTestNotification()
            }
            return
        }
        
        // Use the same translated titles and messages as the real daily transaction reminder
        let content = UNMutableNotificationContent()
        content.title = Self.randomDailyReminderTitle()
        content.body = Self.randomDailyReminderBody()
        content.sound = .default
        content.categoryIdentifier = "DAILY_TRANSACTION_REMINDER"
        content.userInfo = ["type": "daily_transaction_reminder"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] ❌ Error sending test notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] ✅ Test notification sent successfully!")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "daily_transaction_reminder" {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToFinanceTab"), object: nil)
        }
        
        completionHandler()
    }
}
