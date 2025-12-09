//
//  ContentView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject var language: LanguageManager
    @State private var webViewURL: URL?
    @State private var webViewKey = UUID()
    
    var body: some View {
        Group {
            // ✅ P0 FIX: Show dashboard immediately if authenticated (no loading spinner)
            // Background validation happens silently without blocking UI
            if supabaseManager.isAuthenticated {
                WebViewContainer(url: webViewURL ?? URL(string: "\(Configuration.webAppURL)/dashboard?mobile_app=true")!)
                    .id(webViewKey)
            } else if supabaseManager.requiresEmailConfirmation {
                EmailConfirmationView()
            } else if supabaseManager.isInitializing {
                // Only show loading if we're checking for the first time AND not authenticated
                ZStack {
                    Color(red: 1.0, green: 0.957, blue: 0.914).ignoresSafeArea()
                    ProgressView().scaleEffect(1.2)
                }
            } else {
                AuthView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                webViewURL = url
                // Ensure authentication state is set
                if !supabaseManager.isAuthenticated {
                    supabaseManager.isAuthenticated = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            // Force WebView to reload from scratch (clears memory cache)
            webViewKey = UUID()
            webViewURL = nil
        }
        .onAppear {
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard?mobile_app=true")!
            }
        }
        .onChange(of: supabaseManager.isAuthenticated) {
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard?mobile_app=true")!
            }

            // Setup notifications when user is authenticated
            if supabaseManager.isAuthenticated {
                if notificationManager.isAuthorized {
                    notificationManager.scheduleDailyNotification()
                } else {
                    notificationManager.requestNotificationPermission()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
