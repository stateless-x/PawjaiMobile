//
//  WebView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        
        // Load the URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update logic if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.errorMessage = nil
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                
                // Check if the loaded page is a signin/signup page
                if let url = webView.url {
                    let path = url.path
                    if path.contains("/auth/signin") || path.contains("/auth/signup") {
                        print("🚫 WebView loaded signin/signup page, redirecting to native AuthView")
                        SupabaseManager.shared.isAuthenticated = false
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Check if the web app is trying to redirect to signin/signup pages
            let path = url.path
            if path.contains("/auth/signin") || path.contains("/auth/signup") {
                print("🚫 WebView trying to navigate to signin/signup, redirecting to native AuthView")
                
                // Redirect to native AuthView by setting authentication to false
                DispatchQueue.main.async {
                    SupabaseManager.shared.isAuthenticated = false
                }
                
                decisionHandler(.cancel)
                return
            }
            
            // Allow all other navigation actions
            decisionHandler(.allow)
        }
    }
}

struct WebViewContainer: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var webView: WKWebView?
    @State private var currentURL: URL
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    init(url: URL) {
        self._currentURL = State(initialValue: url)
    }
    
    var body: some View {
        ZStack {
            WebView(url: currentURL, isLoading: $isLoading, errorMessage: $errorMessage)
                .edgesIgnoringSafeArea(.all)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.8))
            }
            
            if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        self.errorMessage = nil
                        // Reload the webview
                        if let webView = webView {
                            webView.reload()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            
            // Sign out button (top-right corner)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        supabaseManager.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                currentURL = url
            }
        }
    }
}
