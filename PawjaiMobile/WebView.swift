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

        // 🔥 CRITICAL FIX: Share process pool for cookie persistence across app restarts
        // Without this, each WebView instance has isolated cookies
        configuration.processPool = WKProcessPool.shared

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

        // ✅ PERSISTENT: Use default data store for cookies AND localStorage
        // This ensures webapp cache (localStorage/IndexedDB) persists across sessions
        // Auth cookies are managed separately via WKHTTPCookieStore (secure)
        configuration.websiteDataStore = .default()

        // 🍎 IMPORTANT: .default() provides:
        // - Persistent cookies (survives app restart)
        // - Persistent localStorage (webapp cache works)
        // - Persistent IndexedDB (offline data works)
        // - Shared with Safari (if user signs in via Safari, works in app too)
        
        // Add message handlers on configuration before creating the webView
        configuration.userContentController.add(context.coordinator, name: "signOut")
        configuration.userContentController.add(context.coordinator, name: "notificationSettingsChanged")

        // 🍎 SECURE: Add session establishment handler for WKHTTPCookieStore bridge
        configuration.userContentController.add(context.coordinator, name: "sessionEstablished")

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
        private weak var webView: WKWebView?

        init(_ parent: WebView) {
            self.parent = parent
            super.init()

            // Listen for token sync notifications from native app
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSyncTokens(_:)),
                name: .syncWebViewTokens,
                object: nil
            )

            // 🔥 NEW: Listen for session verification requests
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleVerifySession(_:)),
                name: .verifyWebViewSession,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // 🔥 P0 FIX: Use WKHTTPCookieStore as primary sync mechanism (with retry)
        @objc private func handleSyncTokens(_ notification: Notification) {
            guard let webView = self.webView,
                  let userInfo = notification.userInfo,
                  let accessToken = userInfo["access_token"] as? String,
                  let refreshToken = userInfo["refresh_token"] as? String else {
                return
            }

            // Sync with retry logic (3 attempts: 0s, 1s, 3s)
            syncTokensWithRetry(webView: webView, accessToken: accessToken, refreshToken: refreshToken, attempt: 0)
        }

        private func syncTokensWithRetry(webView: WKWebView, accessToken: String, refreshToken: String, attempt: Int) {
            let expiresAt = Int(Date().timeIntervalSince1970) + 3600 // 1 hour from now

            // Create Supabase session format
            let sessionData: [String: Any] = [
                "state": [
                    "session": [
                        "access_token": accessToken,
                        "refresh_token": refreshToken,
                        "expires_at": expiresAt,
                        "expires_in": 3600,
                        "token_type": "bearer"
                    ]
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sessionData),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("❌ [Cookie Sync] Failed to serialize session data")
                return
            }

            // ✅ PRIMARY METHOD: WKHTTPCookieStore (Apple recommended)
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .name: "pawjai-auth-session-pawjai-auth-storage",
                .value: jsonString,
                .domain: ".pawjai.co",
                .path: "/",
                .secure: true,
                .expires: Date().addingTimeInterval(31536000), // 1 year
            ]

            guard let cookie = HTTPCookie(properties: cookieProperties) else {
                print("❌ [Cookie Sync] Failed to create HTTPCookie")
                // Fallback to JavaScript injection
                self.syncTokensViaJavaScript(webView: webView, accessToken: accessToken, refreshToken: refreshToken)
                return
            }

            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.setCookie(cookie) { [weak self] in
                print("✅ [Cookie Sync] WKHTTPCookieStore sync successful (attempt \(attempt + 1))")

                // Verify cookie was set
                cookieStore.getAllCookies { cookies in
                    let authCookie = cookies.first { $0.name == "pawjai-auth-session-pawjai-auth-storage" }
                    if authCookie != nil {
                        print("✅ [Cookie Sync] Cookie verified present")
                    } else {
                        print("⚠️ [Cookie Sync] Cookie verification failed on attempt \(attempt + 1)")

                        // Retry with exponential backoff (max 3 attempts)
                        if attempt < 2 {
                            let delay = pow(2.0, Double(attempt))
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self?.syncTokensWithRetry(webView: webView, accessToken: accessToken, refreshToken: refreshToken, attempt: attempt + 1)
                            }
                        } else {
                            // Final fallback: JavaScript injection
                            print("⚠️ [Cookie Sync] All WKHTTPCookieStore attempts failed, falling back to JavaScript")
                            self?.syncTokensViaJavaScript(webView: webView, accessToken: accessToken, refreshToken: refreshToken)
                        }
                    }
                }
            }
        }

        // 🔥 FALLBACK: JavaScript injection (only used if WKHTTPCookieStore fails)
        private func syncTokensViaJavaScript(webView: WKWebView, accessToken: String, refreshToken: String) {
            let expiresAt = Int(Date().timeIntervalSince1970) + 3600
            let syncScript = """
            (function() {
                try {
                    const session = {
                        access_token: '\(accessToken)',
                        refresh_token: '\(refreshToken)',
                        expires_at: \(expiresAt),
                        expires_in: 3600,
                        token_type: 'bearer'
                    };

                    const authStorage = {
                        state: {
                            session: session,
                            user: null
                        }
                    };

                    const cookieValue = JSON.stringify(authStorage);
                    const cookieName = 'pawjai-auth-session-pawjai-auth-storage';
                    const maxAge = 31536000; // 1 year

                    document.cookie = cookieName + '=' + encodeURIComponent(cookieValue) +
                        '; max-age=' + maxAge +
                        '; path=/' +
                        (window.location.protocol === 'https:' ? '; secure' : '') +
                        '; samesite=lax';

                    console.log('[Native→WebView] Tokens synced via JavaScript fallback');
                } catch (error) {
                    console.error('[Native→WebView] JavaScript sync error:', error);
                }
            })();
            """

            webView.evaluateJavaScript(syncScript) { _, error in
                if let error = error {
                    print("❌ [Cookie Sync] JavaScript fallback failed:", error.localizedDescription)
                } else {
                    print("✅ [Cookie Sync] JavaScript fallback successful")
                }
            }
        }

        // 🔥 NEW: Verify WebView session and recover if missing
        @objc private func handleVerifySession(_ notification: Notification) {
            guard let webView = self.webView,
                  let userInfo = notification.userInfo,
                  let accessToken = userInfo["access_token"] as? String,
                  let refreshToken = userInfo["refresh_token"] as? String else {
                return
            }

            // Check if cookie exists
            let verifyScript = """
            (function() {
                const cookieName = 'pawjai-auth-session-pawjai-auth-storage';
                const cookies = document.cookie.split(';');
                for (let cookie of cookies) {
                    if (cookie.trim().startsWith(cookieName + '=')) {
                        return 'present';
                    }
                }
                return 'missing';
            })();
            """

            webView.evaluateJavaScript(verifyScript) { result, error in
                if let error = error {
                    print("❌ [Session Verify] Error checking cookie:", error.localizedDescription)
                    return
                }

                if let status = result as? String {
                    if status == "present" {
                        print("✅ [Session Verify] Cookie verified present")
                    } else if status == "missing" {
                        print("⚠️ [Session Verify] Cookie MISSING - attempting recovery")
                        // Re-sync tokens if cookie missing
                        NotificationCenter.default.post(
                            name: .syncWebViewTokens,
                            object: nil,
                            userInfo: [
                                "access_token": accessToken,
                                "refresh_token": refreshToken
                            ]
                        )
                    }
                }
            }
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
            } else if message.name == "sessionEstablished" {
                // 🍎 SECURE BRIDGE: Receive tokens from web app and set via WKHTTPCookieStore
                self.handleSecureSessionBridge(message: message)
            }
        }

        // 🍎 SECURE: WKHTTPCookieStore bridge for HttpOnly cookies
        // This is the Apple-recommended way to securely manage auth cookies
        private func handleSecureSessionBridge(message: WKScriptMessage) {
            guard let webView = self.webView,
                  let body = message.body as? [String: Any],
                  let accessToken = body["accessToken"] as? String,
                  let refreshToken = body["refreshToken"] as? String,
                  let expiresAt = body["expiresAt"] as? Int else {
                print("❌ [Secure Bridge] Invalid message format")
                return
            }

            print("🍎 [Secure Bridge] Setting HttpOnly cookies via WKHTTPCookieStore")

            // Create Supabase session format (same as cookieStorage expects)
            let sessionData: [String: Any] = [
                "state": [
                    "session": [
                        "access_token": accessToken,
                        "refresh_token": refreshToken,
                        "expires_at": expiresAt,
                        "expires_in": 3600,
                        "token_type": "bearer"
                    ]
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: sessionData),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("❌ [Secure Bridge] Failed to serialize session data")
                return
            }

            // Calculate byte size (iOS has stricter limits than desktop)
            let byteSize = jsonData.count
            if byteSize > 3800 {
                print("⚠️ [Secure Bridge] Cookie too large: \(byteSize) bytes (limit ~4000)")
                // Still try to set, but warn
            }

            // Create HTTPOnly cookie using WKHTTPCookieStore
            let cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .name: "pawjai-auth-session-pawjai-auth-storage",
                .value: jsonString,
                .domain: ".pawjai.co", // Subdomain sharing
                .path: "/",
                .secure: true, // Always require HTTPS
                .expires: Date().addingTimeInterval(31536000), // 1 year
                // .httpOnly: true is default and SECURE ✅
            ]

            guard let cookie = HTTPCookie(properties: cookieProperties) else {
                print("❌ [Secure Bridge] Failed to create HTTPCookie")
                return
            }

            // Set cookie via WKHTTPCookieStore (secure, native API)
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.setCookie(cookie) { [weak self] in
                print("✅ [Secure Bridge] HttpOnly cookie set successfully")

                // Verify cookie was set
                cookieStore.getAllCookies { cookies in
                    let authCookie = cookies.first { $0.name == "pawjai-auth-session-pawjai-auth-storage" }
                    if authCookie != nil {
                        print("✅ [Secure Bridge] Cookie verified present (\(byteSize) bytes)")
                    } else {
                        print("⚠️ [Secure Bridge] Cookie verification failed")
                    }
                }

                // Also save to native Keychain for cross-session persistence
                SupabaseManager.shared.saveTokensFromBridge(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            self.webView = webView
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.errorMessage = nil
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

            // SKIP sync on auth callback - the callback page handles its own auth flow
            // and JavaScript injection might interfere with token extraction/redirect
            if path.contains("/auth/callback") {
                return false
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
        
        // 🔥 IMPROVED: Token sync with retry logic and readyState check
        // Ensures page is fully loaded before injecting tokens to prevent race conditions
        private func syncAuthStorage(webView: WKWebView, retryCount: Int = 0) {
            let maxRetries = 3
            let retryDelay: TimeInterval = 0.1 // 100ms

            // First, check if page is ready
            webView.evaluateJavaScript("document.readyState") { result, error in
                if let error = error {
                    print("❌ [Token Sync] Error checking readyState:", error.localizedDescription)
                    if retryCount < maxRetries {
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                            self.syncAuthStorage(webView: webView, retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                guard let readyState = result as? String else {
                    if retryCount < maxRetries {
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                            self.syncAuthStorage(webView: webView, retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                // Only proceed if page is complete
                if readyState != "complete" {
                    if retryCount < maxRetries {
                        print("⏳ [Token Sync] Page not ready (state: \(readyState)), retrying... (\(retryCount + 1)/\(maxRetries))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                            self.syncAuthStorage(webView: webView, retryCount: retryCount + 1)
                        }
                    } else {
                        print("⚠️ [Token Sync] Page never reached ready state, proceeding anyway")
                    }
                    return
                }

                // Page is ready, inject token sync script
                let syncScript = """
                (function() {
                    try {
                        const COOKIE_NAME = 'pawjai-auth-session-pawjai-auth-storage';
                        const COOKIE_MAX_AGE = 31536000; // 365 days (1 year)

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

                        // Cookie-only storage - check if cookie exists and refresh max-age
                        const authData = getCookieValue(COOKIE_NAME);
                        if (authData) {
                            // Refresh cookie max-age to prevent expiration
                            setCookie(COOKIE_NAME, authData);
                            return 'refreshed';
                        }
                        return 'not_found';
                    } catch (error) {
                        return 'error: ' + error.message;
                    }
                })();
                """

                webView.evaluateJavaScript(syncScript) { result, error in
                    if let error = error {
                        print("❌ [Token Sync] Script execution failed:", error.localizedDescription)
                    } else if let result = result as? String {
                        if result == "refreshed" {
                            print("✅ [Token Sync] Cookie refreshed successfully")
                            // NOTE: This only refreshes the cookie max-age, not the actual tokens
                            // Don't retry push registration here - wait for actual Supabase token refresh
                        } else if result == "not_found" {
                            print("⚠️ [Token Sync] No auth cookie found")
                        } else {
                            print("ℹ️ [Token Sync] Result:", result)
                        }
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

            // Custom URL scheme (pawjai://)
            if url.scheme == "pawjai" {
                handleCustomScheme(url: url)
                decisionHandler(.cancel)
                return
            }

            // Detect external e-commerce links and open in Safari
            // This prevents ads from opening in the in-app WebView
            // Dynamically fetched from backend API
            if ExternalDomainsManager.shared.shouldOpenInSafari(host: url.host) {
                // Open external link in Safari
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

// MARK: - WKProcessPool Manager

/// 🍎 SECURE: App-scoped process pool (not global singleton)
/// This prevents memory leaks while ensuring cookie persistence
class WebViewProcessPoolManager {
    static let shared = WebViewProcessPoolManager()
    let processPool = WKProcessPool()

    private init() {
        print("🍎 [ProcessPool] Initialized app-scoped process pool")
    }

    deinit {
        print("🍎 [ProcessPool] Process pool deallocated")
    }
}

extension WKProcessPool {
    /// App-scoped shared process pool for cookie persistence
    static var shared: WKProcessPool {
        return WebViewProcessPoolManager.shared.processPool
    }
}
