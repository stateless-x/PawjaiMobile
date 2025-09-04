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
        
        // Add message handler for sign-out
        webView.configuration.userContentController.add(context.coordinator, name: "signOut")
        
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "signOut" {
                print("📱 Received sign-out message from WebView")
                DispatchQueue.main.async {
                    SupabaseManager.shared.signOut()
                }
            }
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
                    print("📱 WebView finished loading: \(url.absoluteString)")
                    print("📱 WebView path: \(path)")
                    
                    // Only redirect to AuthView if we're actually on a signin/signup page
                    // and not on a redirect or callback page
                    if (path.contains("/auth/signin") || path.contains("/auth/signup")) && 
                       !path.contains("/auth/callback") && 
                       !path.contains("/auth/native-handoff") {
                        print("🚫 WebView loaded signin/signup page, redirecting to native AuthView")
                        SupabaseManager.shared.isAuthenticated = false
                    } else {
                        print("📱 WebView loaded valid page, staying in WebView")
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
            
            // Handle custom URL schemes
            if url.scheme == "pawjai" {
                if url.host == "signout" {
                    print("📱 Received pawjai://signout URL, triggering native sign-out")
                    DispatchQueue.main.async {
                        SupabaseManager.shared.signOut()
                    }
                }
                decisionHandler(.cancel)
                return
            }
            
            // Check if the web app is trying to redirect to signin/signup pages
            let path = url.path
            print("📱 WebView navigation decision for: \(url.absoluteString)")
            print("📱 WebView navigation path: \(path)")
            
            // Only redirect to AuthView if we're actually navigating to a signin/signup page
            // and not to a redirect or callback page
            if (path.contains("/auth/signin") || path.contains("/auth/signup")) && 
               !path.contains("/auth/callback") && 
               !path.contains("/auth/native-handoff") {
                print("🚫 WebView trying to navigate to signin/signup, redirecting to native AuthView")
                
                // Redirect to native AuthView by setting authentication to false
                DispatchQueue.main.async {
                    SupabaseManager.shared.isAuthenticated = false
                }
                
                decisionHandler(.cancel)
                return
            } else {
                print("📱 WebView navigation allowed for: \(path)")
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
