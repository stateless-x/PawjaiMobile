//
//  PawjaiMobileApp.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

// Class to hold mutable state for URL handling
class URLHandler: ObservableObject {
    static let shared = URLHandler()
    private var lastHandledURL: String = ""

    func handleIncomingURL(_ url: URL) {
        // Prevent handling the same URL multiple times (debounce)
        let urlString = url.absoluteString
        if urlString == lastHandledURL {
            return
        }
        lastHandledURL = urlString

        // Handle custom URL scheme (pawjai://)
        // This is used by the bridge page to force the app to open
        if url.scheme == "pawjai" {
            // Convert pawjai:// URL to https:// URL for the WebView
            // Example: pawjai://auth/callback?token=... → https://pawjai.co/auth/callback?token=...
            let path = url.path
            let query = url.query.map { "?\($0)" } ?? ""
            let fragment = url.fragment.map { "#\($0)" } ?? ""
            let httpsUrlString = "https://pawjai.co\(path)\(query)\(fragment)"

            // Navigate the WebView to this URL
            if let httpsUrl = URL(string: httpsUrlString) {
                NotificationCenter.default.post(
                    name: .navigateToURL,
                    object: nil,
                    userInfo: ["url": httpsUrl]
                )

                // Reset after 2 seconds to allow future navigations
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.lastHandledURL = ""
                }
            }
            return
        }

        // Handle Universal Links (https://pawjai.co/...)
        // Example: https://pawjai.co/auth/callback?type=signup&...
        if url.host == "pawjai.co" {
            NotificationCenter.default.post(
                name: .navigateToURL,
                object: nil,
                userInfo: ["url": url]
            )

            // Reset after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastHandledURL = ""
            }
        }
    }
}

@main
struct PawjaiMobileApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var language = LanguageManager.shared
    @StateObject private var urlHandler = URLHandler.shared

    init() {
        FontManager.shared.registerFonts()
        setupDefaultFonts()
        NotificationManager.shared.setupNotifications()

        // Fetch latest external domains from backend
        ExternalDomainsManager.shared.fetchDomains()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(language)
                .onOpenURL { url in
                    urlHandler.handleIncomingURL(url)
                }
        }
    }

    private func setupDefaultFonts() {
        let defaultFont = UIFont.kanitRegular(size: 16)
        let darkGrayColor = UIColor(red: 0.118, green: 0.161, blue: 0.235, alpha: 1.0)

        UILabel.appearance().font = defaultFont
        UITextField.appearance().font = defaultFont
        UITextField.appearance().textColor = darkGrayColor
        UITextField.appearance().tintColor = darkGrayColor
        UITextView.appearance().font = defaultFont
        UITextView.appearance().textColor = darkGrayColor
        UITextView.appearance().tintColor = darkGrayColor
        UIButton.appearance().titleLabel?.font = defaultFont

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.titleTextAttributes = [
            .font: UIFont.kanitMedium(size: 18),
            .foregroundColor: UIColor.black
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .font: UIFont.kanitBold(size: 28),
            .foregroundColor: UIColor.black
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
}
