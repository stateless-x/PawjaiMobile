//
//  WebView.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import SwiftUI
import WebKit
import AVFoundation
import Photos

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable camera and microphone permissions
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Allow camera and microphone access
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Configure JavaScript settings using the newer API
        if #available(iOS 14.0, *) {
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            configuration.defaultWebpagePreferences = preferences
        } else {
            // Fallback for iOS < 14
            configuration.preferences.javaScriptEnabled = true
        }
        
        // Enable file uploads and camera capture
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        
        // Ensure persistent website data store for cookie retention
        // Web app uses cookie-only storage (no localStorage for auth)
        configuration.websiteDataStore = .default()
        
        // Add message handlers on configuration before creating the webView
        configuration.userContentController.add(context.coordinator, name: "signOut")
        configuration.userContentController.add(context.coordinator, name: "notificationSettingsChanged")

        // Create webView after configuration is fully prepared
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        
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
        private var lastSyncTimestamp: Date?
        private let syncDebounceInterval: TimeInterval = 300 // 5 minutes

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "signOut" {
                DispatchQueue.main.async {
                    SupabaseManager.shared.signOut()
                }
            } else if message.name == "notificationSettingsChanged" {
                DispatchQueue.main.async {
                    NotificationManager.shared.forceRefreshNotifications()
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.errorMessage = nil

                SupabaseManager.shared.ensureValidToken { _ in }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false

                // Only sync auth storage when necessary (debounced)
                if self.shouldSyncAuthStorage(url: webView.url) {
                    self.syncAuthStorage(webView: webView)
                    self.lastSyncTimestamp = Date()
                }

                // Detect if WebView navigated to auth pages (session lost)
                if let url = webView.url {
                    let path = url.path
                    if ((path.contains("/auth/signin") || path.contains("/auth/signup")) &&
                       !path.contains("/auth/callback") &&
                       !path.contains("/auth/native-handoff")) {
                        SupabaseManager.shared.isAuthenticated = false
                    }
                }
            }
        }

        private func shouldSyncAuthStorage(url: URL?) -> Bool {
            guard let url = url else { return false }
            let path = url.path

            // Always sync after native handoff (setting session from native)
            if path.contains("/auth/native-handoff") {
                return true
            }

            // Always sync on auth callback (OAuth completion)
            if path.contains("/auth/callback") {
                return true
            }

            // Sync if last sync was > 5 minutes ago (e.g., app was backgrounded)
            if let lastSync = lastSyncTimestamp {
                return Date().timeIntervalSince(lastSync) > syncDebounceInterval
            }

            // First load - sync once
            if lastSyncTimestamp == nil {
                return true
            }

            // Skip sync for regular navigation
            return false
        }
        
        // Bidirectional auth sync: Cookie (primary) ↔ localStorage (fallback)
        // Ensures resilient auth across cookie clearing and iOS privacy features
        private func syncAuthStorage(webView: WKWebView) {
            let syncScript = """
            (function() {
                try {
                    const AUTH_STORAGE_KEY = 'pawjai-auth-storage';
                    const COOKIE_NAME = 'pawjai-auth-session-pawjai-auth-storage';
                    const COOKIE_MAX_AGE = 7776000;

                    function getCookieValue(name) {
                        const cookies = document.cookie.split(';');
                        for (let cookie of cookies) {
                            const [cookieName, cookieValue] = cookie.trim().split('=');
                            if (cookieName === name) {
                                return decodeURIComponent(cookieValue);
                            }
                        }
                        return null;
                    }

                    function setCookie(name, value) {
                        const isSecure = window.location.protocol === 'https:';
                        const cookieString = name + '=' + encodeURIComponent(value) +
                            '; max-age=' + COOKIE_MAX_AGE +
                            '; path=/' +
                            (isSecure ? '; secure' : '') +
                            '; samesite=lax';
                        document.cookie = cookieString;
                    }

                    // 1. Try cookie first (highest priority)
                    let authData = getCookieValue(COOKIE_NAME);

                    // 2. Fallback to localStorage if cookie unavailable
                    if (!authData) {
                        authData = localStorage.getItem(AUTH_STORAGE_KEY);
                        if (authData) {
                            // Restore cookie from localStorage
                            setCookie(COOKIE_NAME, authData);
                        }
                    }

                    // 3. Keep both in sync for redundancy
                    if (authData) {
                        localStorage.setItem(AUTH_STORAGE_KEY, authData);
                        setCookie(COOKIE_NAME, authData);
                    }
                } catch (error) {
                    // Silent failure - auth handled by native layer
                }
            })();
            """

            webView.evaluateJavaScript(syncScript) { _, _ in }
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

            // Custom URL scheme (pawjai://)
            if url.scheme == "pawjai" {
                handleCustomScheme(url: url)
                decisionHandler(.cancel)
                return
            }

            // Detect external e-commerce links and open in Safari
            // This prevents ads from opening in the in-app WebView
            // Dynamically fetched from backend API
            let urlHost = url.host ?? "nil"
            let shouldOpen = ExternalDomainsManager.shared.shouldOpenInSafari(host: url.host)
            let currentDomains = ExternalDomainsManager.shared.getDomains()
            print("🔍 Navigation check - URL: \(url.absoluteString)")
            print("🔍 Host: \(urlHost)")
            print("🔍 Configured domains: \(currentDomains)")
            print("🔍 Should open in Safari: \(shouldOpen)")

            if shouldOpen {
                // Open external link in Safari
                print("✅ Opening in Safari: \(url.absoluteString)")
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }

            let path = url.path

            // Account disabled - force sign out
            if path.contains("/auth/account-disabled") {
                DispatchQueue.main.async {
                    SupabaseManager.shared.signOut()
                }
                decisionHandler(.cancel)
                return
            }

            // WebView session lost - attempt recovery from native Keychain
            // Only intercept if user WAS authenticated but WebView session lost
            if shouldAttemptSessionRecovery(path: path) {
                if let user = SupabaseManager.shared.currentUser,
                   SupabaseManager.shared.isAuthenticated {
                    // User has native session but WebView lost it - recover
                    recoverSession(webView: webView, user: user)
                    decisionHandler(.cancel)
                    return
                }
                // User not authenticated - allow normal navigation (sign in/up)
                decisionHandler(.allow)
                return
            }

            decisionHandler(.allow)
        }

        private func handleCustomScheme(url: URL) {
            if url.host == "signout" {
                DispatchQueue.main.async {
                    SupabaseManager.shared.signOut()
                }
            }
        }

        private func shouldAttemptSessionRecovery(path: String) -> Bool {
            return ((path.contains("/auth/signin") || path.contains("/auth/signup") || path == "/") &&
                   !path.contains("/auth/callback") &&
                   !path.contains("/auth/native-handoff") &&
                   !path.contains("/auth/forgot-password") &&
                   !path.contains("/auth/reset-password") &&
                   !path.contains("/auth/email-confirmation"))
        }

        private func recoverSession(webView: WKWebView, user: User) {
            var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
            handoffComponents.queryItems = [
                URLQueryItem(name: "access_token", value: user.accessToken),
                URLQueryItem(name: "refresh_token", value: user.refreshToken)
            ]

            if let handoffURL = handoffComponents.url {
                webView.load(URLRequest(url: handoffURL))
            } else {
                DispatchQueue.main.async {
                    SupabaseManager.shared.signOut()
                }
            }
        }
        
        // Handle camera and microphone permission requests
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            
            // Request system permissions first
            switch type {
            case .camera:
                requestCameraPermission { granted in
                    DispatchQueue.main.async {
                        decisionHandler(granted ? .grant : .deny)
                    }
                }
            case .microphone:
                requestMicrophonePermission { granted in
                    DispatchQueue.main.async {
                        decisionHandler(granted ? .grant : .deny)
                    }
                }
            case .cameraAndMicrophone:
                requestCameraAndMicrophonePermission { granted in
                    DispatchQueue.main.async {
                        decisionHandler(granted ? .grant : .deny)
                    }
                }
            @unknown default:
                decisionHandler(.deny)
            }
        }
        
        // Request camera permission from system
        private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        }
        
        // Request microphone permission from system
        private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        }
        
        // Request both camera and microphone permissions
        private func requestCameraAndMicrophonePermission(completion: @escaping (Bool) -> Void) {
            let group = DispatchGroup()
            var cameraGranted = false
            var microphoneGranted = false
            
            group.enter()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                cameraGranted = granted
                group.leave()
            }
            
            group.enter()
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                microphoneGranted = granted
                group.leave()
            }
            
            group.notify(queue: .main) {
                let bothGranted = cameraGranted && microphoneGranted
                completion(bothGranted)
            }
        }
    }
}

struct WebViewContainer: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentURL: URL

    init(url: URL) {
        self._currentURL = State(initialValue: url)
    }
    
    var body: some View {
        ZStack {
            WebView(url: currentURL, isLoading: $isLoading, errorMessage: $errorMessage)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            
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
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }

        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                currentURL = url
            }
        }
    }
}
