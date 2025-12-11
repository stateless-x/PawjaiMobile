//
//  NotificationManager.swift
//  PawjaiMobile
//
//  DEPRECATED: Local notification scheduling is now handled by backend push notifications
//  This file is kept for backward compatibility but most functions do nothing
//

import UserNotifications
import Foundation
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {}

    func requestNotificationPermission() {
        // Note: Push notification permissions are now handled by PushManager
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleDailyNotification() {
        // DEPRECATED: Local notification scheduling is now handled by backend push notifications
    }

    func forceRefreshNotifications() {
        // DEPRECATED: No longer needed with backend push notifications
    }

    func removeAllNotifications() {
        // Clear any pending local notifications and delivered notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func setupNotifications() {
        // Kept for backward compatibility - now handled by PushManager
        checkAuthorizationStatus()
    }
}
