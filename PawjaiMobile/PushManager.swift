//
//  PushManager.swift
//  PawjaiMobile
//
//  Manages push notifications via APNs
//  - Registers device tokens with backend
//  - Handles incoming push notifications
//  - Auto-clears badge on app open
//

import Foundation
import UserNotifications
import UIKit

class PushManager: NSObject {
    static let shared = PushManager()
    private var deviceToken: String?

    private override init() {
        super.init()
    }

    func register() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ [Push] Authorization error: \(error)")
                return
            }

            guard granted else {
                print("❌ [Push] Permission denied")
                return
            }

            print("✅ [Push] Permission granted")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("✅ [Push] Device token: \(token)")
        uploadToken(token)
    }

    func handleRegistrationError(_ error: Error) {
        print("❌ [Push] Registration failed: \(error.localizedDescription)")
    }

    private func uploadToken(_ token: String) {
        guard let accessToken = SupabaseManager.shared.currentUser?.accessToken else {
            print("⚠️ [Push] No access token available")
            // Store token to retry on login
            self.deviceToken = token
            return
        }

        let url = URL(string: "\(Configuration.backendApiURL)/api/push/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = ["deviceToken": token, "platform": "ios"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [Push] Upload failed: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    print("✅ [Push] Token registered with backend")
                } else {
                    print("❌ [Push] Registration failed with status \(http.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("   Response: \(responseString)")
                    }
                }
            }
        }.resume()
    }

    // Call this when user logs in successfully to retry registration
    func retryRegistration() {
        guard let token = deviceToken else { return }
        print("🔄 [Push] Retrying token registration after login")
        uploadToken(token)
    }

    func unregister() {
        guard let token = deviceToken,
              let accessToken = SupabaseManager.shared.currentUser?.accessToken else {
            return
        }

        let url = URL(string: "\(Configuration.backendApiURL)/api/push/unregister")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body = ["deviceToken": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("✅ [Push] Unregistered")
        }.resume()
    }

    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        print("📬 [Push] Notification received")

        // Handle deep link
        if let deepLink = userInfo["deepLink"] as? String {
            print("🔗 [Push] Deep link: \(deepLink)")
            if let url = URL(string: "https://pawjai.co\(deepLink)") {
                NotificationCenter.default.post(
                    name: .navigateToURL,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }

    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            print("🔔 [Push] Badge and notifications cleared")
        }
    }
}
