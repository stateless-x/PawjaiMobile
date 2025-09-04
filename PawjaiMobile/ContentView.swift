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
                webViewURL = url
                supabaseManager.isAuthenticated = true
            }
        }
    }
}

#Preview {
    ContentView()
}
