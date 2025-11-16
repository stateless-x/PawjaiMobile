//
//  NotificationManager.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import UserNotifications
import Foundation
import UIKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private var lastRefreshDate: Date?
    private let minimumRefreshInterval: TimeInterval = 43200 // 12 hours

    private init() {
        setupAppLifecycleObservers()
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleAppWillEnterForeground() {
        refreshNotificationSettings(force: false)
    }

    private func refreshNotificationSettings(force: Bool = false) {
        guard isAuthorized else { return }

        if !force, let lastRefresh = lastRefreshDate {
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
            if timeSinceLastRefresh < minimumRefreshInterval {
                return
            }
        }

        lastRefreshDate = Date()
        scheduleDailyNotification()
    }

    // Bypass debouncing for user-initiated changes
    func forceRefreshNotifications() {
        refreshNotificationSettings(force: true)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.scheduleDailyNotification()
                }
            }
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleDailyNotification() {
        removeAllNotifications()

        fetchNotificationSettings { [weak self] settings, enabled in
            guard let self = self else { return }
            guard enabled else { return }

            // Stagger notifications by 1 minute to avoid iOS grouping
            for (index, setting) in settings.enumerated() {
                let adjustedMinute = (setting.minute + index) % 60
                let adjustedHour = setting.hour + ((setting.minute + index) / 60)

                self.scheduleNotification(
                    identifier: setting.identifier,
                    title: setting.title,
                    body: setting.body,
                    hour: adjustedHour,
                    minute: adjustedMinute,
                    badgeCount: index + 1
                )
            }
        }
    }

    private func fetchNotificationSettings(completion: @escaping ([NotificationSetting], Bool) -> Void) {
        let preferredLanguage = Locale.current.language.languageCode?.identifier ?? "th"
        let language = (preferredLanguage == "en") ? "en" : "th"

        let baseURL = Configuration.backendApiURL
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/notifications/settings") else {
            completion([], false)
            return
        }

        urlComponents.queryItems = [URLQueryItem(name: "language", value: language)]

        guard let url = urlComponents.url else {
            completion([], false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken = SupabaseManager.shared.currentUser?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion([], false)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion([], false)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion([], false)
                }
                return
            }

            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion([], false)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let dataDict = json["data"] as? [String: Any],
                   let enabled = dataDict["enabled"] as? Bool,
                   let settingsArray = dataDict["settings"] as? [[String: Any]] {

                    let settings = settingsArray.compactMap { dict -> NotificationSetting? in
                        guard let identifier = dict["identifier"] as? String,
                              let title = dict["title"] as? String,
                              let body = dict["body"] as? String,
                              let hour = dict["hour"] as? Int,
                              let minute = dict["minute"] as? Int else {
                            return nil
                        }
                        return NotificationSetting(
                            identifier: identifier,
                            title: title,
                            body: body,
                            hour: hour,
                            minute: minute
                        )
                    }

                    DispatchQueue.main.async {
                        completion(settings, enabled)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion([], false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], false)
                }
            }
        }.resume()
    }
    
    private struct NotificationSetting {
        let identifier: String
        let title: String
        let body: String
        let hour: Int
        let minute: Int
    }

    private func scheduleNotification(identifier: String, title: String, body: String, hour: Int, minute: Int, badgeCount: Int = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }

    func setupNotifications() {
        checkAuthorizationStatus()

        if isAuthorized {
            scheduleDailyNotification()
        } else {
            requestNotificationPermission()
        }
    }
}
