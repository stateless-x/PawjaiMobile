//
//  NotificationManager.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import UserNotifications
import Foundation

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {}
    
    // MARK: - Permission Request
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                print("🔔 Notification permission granted: \(granted)")
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                } else if granted {
                    // Schedule daily notification after permission is granted
                    self?.scheduleDailyNotification()
                    print("🔔 Daily notification scheduled after permission granted")
                }
            }
        }
    }
    
    // MARK: - Check Authorization Status
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
                print("🔔 Current notification authorization status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    // MARK: - Schedule Daily Notification
    func scheduleDailyNotification() {
        // Remove existing notifications first
        removeAllNotifications()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "วันนี้อย่าลืมมาจดบันทึกให้น้องน้าาาา~"
        content.body = "น้องดูแลตัวเองไม่ดีเท่าที่เราคอยช่วยดูแลเค้านะ 🧡"
        content.sound = .default
        content.badge = 1
        
        // Create trigger for daily at 12:00 PM (mid-day)
        var dateComponents = DateComponents()
        dateComponents.hour = 12
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "daily-pet-reminder",
            content: content,
            trigger: trigger
        )
        
        // Add notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily notification: \(error.localizedDescription)")
            } else {
                print("✅ Daily notification scheduled successfully for 12:00 PM")
            }
        }
    }
    
    
    // MARK: - Remove All Notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🗑️ All notifications removed")
    }
    
    // MARK: - Remove Specific Notification
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
        print("🗑️ Notification with identifier '\(identifier)' removed")
    }
    
    // MARK: - Get Pending Notifications
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
    
    // MARK: - Setup Notifications
    func setupNotifications() {
        checkAuthorizationStatus()
        
        if isAuthorized {
            scheduleDailyNotification()
        } else {
            requestNotificationPermission()
        }
    }
}
