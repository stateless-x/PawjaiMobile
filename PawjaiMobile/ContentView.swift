//
//  ContentView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var webViewURL: URL?
    
    var body: some View {
        Group {
            if supabaseManager.isAuthenticated {
                WebViewContainer(url: webViewURL ?? URL(string: "\(Configuration.webAppURL)/dashboard")!)
            } else {
                AuthView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                print("📱 ContentView received navigateToURL notification: \(url)")
                webViewURL = url
                // Ensure authentication state is set
                if !supabaseManager.isAuthenticated {
                    supabaseManager.isAuthenticated = true
                }
            }
        }
        .onAppear {
            print("📱 ContentView appeared - isAuthenticated: \(supabaseManager.isAuthenticated)")
            if supabaseManager.isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                print("📱 Set WebView URL to dashboard: \(webViewURL?.absoluteString ?? "nil")")
            }
        }
        .onChange(of: supabaseManager.isAuthenticated) { isAuthenticated in
            print("📱 Authentication state changed to: \(isAuthenticated)")
            if isAuthenticated && webViewURL == nil {
                webViewURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                print("📱 Set WebView URL to dashboard after auth change: \(webViewURL?.absoluteString ?? "nil")")
            }
        }
    }
}

#Preview {
    ContentView()
}
