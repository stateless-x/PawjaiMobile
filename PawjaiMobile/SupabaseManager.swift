//
//  SupabaseManager.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import Foundation
import AuthenticationServices
import Security
import BackgroundTasks
import WebKit

class SupabaseManager: NSObject, ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var requiresEmailConfirmation = false
    @Published var pendingEmailConfirmation: String?
    @Published var isInitializing = true
    
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    private let redirectURL: String

    // Token refresh lock to prevent simultaneous refresh attempts
    private var isRefreshing = false
    private let refreshQueue = DispatchQueue(label: "com.pawjai.tokenRefresh")

    private override init() {
        self.supabaseURL = URL(string: Configuration.supabaseURL)!
        self.supabaseAnonKey = Configuration.supabaseAnonKey
        self.redirectURL = Configuration.redirectURL
        super.init()


        // Check for existing authentication state
        checkAuthenticationState()

        // CRITICAL: Observe app foreground to refresh tokens
        // iOS suspends timers when app is backgrounded, so we need to refresh on foreground
        setupAppLifecycleObservers()

    }
    
    private func checkAuthenticationState() {
        // ✅ P0 FIX: INSTANT LAUNCH - Show UI immediately, validate in background

        // Check for stored authentication tokens
        if let storedUser = loadStoredUser() {
            // ✅ CRITICAL: Set authenticated state IMMEDIATELY (instant UI)
            // Don't wait for validation - trust keychain
            DispatchQueue.main.async {
                self.currentUser = storedUser
                self.isAuthenticated = true
                self.isInitializing = false
                self.objectWillChange.send()
            }

            // ✅ BACKGROUND: Validate and sync tokens silently (non-blocking)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.validateAndSyncInBackground(user: storedUser)
            }
        } else {
            // No tokens - show auth view
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isInitializing = false
            }
        }
    }

    // 🔥 P0 FIX: Background validation with 7-day offline grace period
    private func validateAndSyncInBackground(user: User) {
        // Check if token needs refresh
        if !isTokenValid(user: user) {
            // Token expired - try to refresh
            refreshAccessToken { [weak self] success in
                guard let self = self else { return }
                if success, let refreshedUser = self.loadStoredUser() {
                    // Refresh succeeded - validate account
                    self.validateAccountStatus(user: refreshedUser) { [weak self] isValid in
                        if isValid {
                            // ✅ Silently sync fresh tokens to WebView (no navigation!)
                            self?.syncTokensToWebViewCookie(
                                accessToken: refreshedUser.accessToken,
                                refreshToken: refreshedUser.refreshToken
                            )
                            // ✅ Retry push token registration with fresh tokens
                            PushManager.shared.retryRegistration()
                        } else {
                            // Account invalid - sign out
                            DispatchQueue.main.async {
                                self?.signOut()
                            }
                        }
                    }
                } else {
                    // Refresh failed - keep user logged in, let them use the app
                    // Supabase refresh tokens never expire, so this is likely a network issue
                    // The WebView will auto-refresh when it can, and user can still browse cached content
                    self.syncTokensToWebViewCookie(accessToken: user.accessToken, refreshToken: user.refreshToken)
                }
            }
        } else {
            // Token is fresh - just validate account and sync
            validateAccountStatus(user: user) { [weak self] isValid in
                if isValid {
                    // ✅ Silently sync tokens to WebView (no navigation!)
                    self?.syncTokensToWebViewCookie(
                        accessToken: user.accessToken,
                        refreshToken: user.refreshToken
                    )
                } else {
                    // Account invalid - sign out
                    DispatchQueue.main.async {
                        self?.signOut()
                    }
                }
            }
        }
    }

    // MARK: - App Lifecycle Observers

    private func setupAppLifecycleObservers() {
        // Observe when app enters foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        // 🔥 P1 FIX: Register background refresh task
        registerBackgroundRefreshTask()
    }

    // MARK: - Background App Refresh

    // 🔥 P1 FIX: Register background task for proactive token refresh
    private func registerBackgroundRefreshTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "co.pawjai.tokenRefresh",
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTokenRefresh(task: task as! BGAppRefreshTask)
        }

        // Schedule first background refresh
        scheduleBackgroundRefresh()
    }

    private func handleBackgroundTokenRefresh(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundRefresh()

        // Create task expiration handler
        task.expirationHandler = {
            print("⚠️ [Background] Task expiring, canceling token refresh")
        }

        // Only refresh if authenticated
        guard isAuthenticated, currentUser != nil else {
            task.setTaskCompleted(success: true)
            return
        }

        // Check if token needs refresh
        guard let timestampString = loadFromKeychain(forKey: "token_timestamp"),
              let timestamp = Double(timestampString) else {
            task.setTaskCompleted(success: true)
            return
        }

        let tokenAge = Date().timeIntervalSince1970 - timestamp
        // Refresh if token is older than 50 minutes
        if tokenAge > 3000 {
            refreshAccessToken { [weak self] success in
                // Sync to WebView on success
                if success, let refreshedUser = self?.loadStoredUser() {
                    self?.syncTokensToWebViewCookie(
                        accessToken: refreshedUser.accessToken,
                        refreshToken: refreshedUser.refreshToken
                    )
                    // ✅ Retry push token registration with fresh tokens
                    PushManager.shared.retryRegistration()
                }

                task.setTaskCompleted(success: success)
            }
        } else {
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "co.pawjai.tokenRefresh")
        // Schedule to run in 50 minutes (before token expires at 60 minutes)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 50 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ [Background] Failed to schedule token refresh: \(error.localizedDescription)")
        }
    }

    @objc private func handleAppWillEnterForeground() {

        guard isAuthenticated, let user = currentUser else {
            return
        }

        // Check if token needs refresh (older than 50 minutes or expired)
        guard let timestampString = loadFromKeychain(forKey: "token_timestamp"),
              let timestamp = Double(timestampString) else {
            attemptTokenRefresh(user: user)
            return
        }

        let tokenAge = Date().timeIntervalSince1970 - timestamp
        // Refresh if token is older than 50 minutes (3000 seconds)
        // This ensures we always have a fresh token (tokens expire at 60 minutes)
        if tokenAge > 3000 {
            attemptTokenRefresh(user: user)
        } else {
            // Token is fresh, but WebView session might have expired during backgrounding
            // (iOS suspends JavaScript, so Supabase autoRefreshToken might not have run)
            // Proactively sync fresh tokens to WebView cookie WITHOUT navigation
            syncTokensToWebViewCookie(accessToken: user.accessToken, refreshToken: user.refreshToken)
        }
    }

    // 🔥 IMPROVED: Sync tokens with verification
    private func syncTokensToWebViewCookie(accessToken: String, refreshToken: String) {
        // Post notification to WebView to inject tokens directly into cookie
        // This updates the session without navigating away from current page
        NotificationCenter.default.post(
            name: .syncWebViewTokens,
            object: nil,
            userInfo: [
                "access_token": accessToken,
                "refresh_token": refreshToken
            ]
        )

        // Verify after 500ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.verifyWebViewSession(accessToken: accessToken, refreshToken: refreshToken)
        }
    }

    // 🔥 NEW: Verify WebView has the session cookie
    private func verifyWebViewSession(accessToken: String, refreshToken: String) {
        // Post verification request
        NotificationCenter.default.post(
            name: .verifyWebViewSession,
            object: nil,
            userInfo: [
                "access_token": accessToken,
                "refresh_token": refreshToken
            ]
        )
    }

    private func attemptTokenRefresh(user: User) {
        refreshAccessToken { [weak self] success in
            if success, let refreshedUser = self?.currentUser {
                self?.syncTokensToWebViewCookie(
                    accessToken: refreshedUser.accessToken,
                    refreshToken: refreshedUser.refreshToken
                )
            } else {
                // Keep user logged in even if refresh fails
                // WebView will handle refresh when network returns
                self?.syncTokensToWebViewCookie(
                    accessToken: user.accessToken,
                    refreshToken: user.refreshToken
                )
            }
        }
    }

    // MARK: - Helper Methods
    // ❌ DELETED: navigateToHandoff() - No longer needed, use syncTokensToWebViewCookie() instead

    // MARK: - Keychain Storage Methods

    private func saveTokens(accessToken: String, refreshToken: String) {
        // Save to Keychain
        saveToKeychain(accessToken, forKey: "access_token")
        saveToKeychain(refreshToken, forKey: "refresh_token")
        saveToKeychain(String(Date().timeIntervalSince1970), forKey: "token_timestamp")
    }

    // 🍎 PUBLIC: Called by secure bridge to save tokens from WKHTTPCookieStore
    func saveTokensFromBridge(accessToken: String, refreshToken: String) {
        saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        DispatchQueue.main.async {
            self.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
            self.isAuthenticated = true
            self.objectWillChange.send()
        }

        // Retry push token registration now that we have valid tokens
        PushManager.shared.retryRegistration()
    }
    
    private func loadStoredUser() -> User? {
        guard let accessToken = loadFromKeychain(forKey: "access_token"),
              let refreshToken = loadFromKeychain(forKey: "refresh_token") else {
            return nil
        }
        return User(accessToken: accessToken, refreshToken: refreshToken)
    }
    
    private func isTokenValid(user: User) -> Bool {
        guard let timestampString = loadFromKeychain(forKey: "token_timestamp"),
              let timestamp = Double(timestampString) else {
            return false
        }
        
        let tokenAge = Date().timeIntervalSince1970 - timestamp
        // Consider access token fresh for 55 minutes to proactively refresh before expiry
        // This avoids logging out immediately on app relaunch after 1h
        return tokenAge < 3300
    }
    
    private func clearStoredTokens() {
        deleteFromKeychain(forKey: "access_token")
        deleteFromKeychain(forKey: "refresh_token")
        deleteFromKeychain(forKey: "token_timestamp")
    }
    
    // MARK: - Token Refresh

    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        refreshAccessTokenWithRetry(attempt: 0, maxRetries: 3, completion: completion)
    }

    private func refreshAccessTokenWithRetry(attempt: Int, maxRetries: Int, completion: @escaping (Bool) -> Void) {
        // Check if refresh is already in progress (prevent race condition)
        refreshQueue.sync {
            if isRefreshing {
                completion(true)  // Return success - let the in-progress refresh complete
                return
            }
            isRefreshing = true
        }

        guard let refreshToken = loadFromKeychain(forKey: "refresh_token") else {
            refreshQueue.sync { isRefreshing = false }
            completion(false)
            return
        }

        // Create the token refresh request
        let tokenURL = URL(string: "\(Configuration.supabaseURL)/auth/v1/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10  // 10 second timeout

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            refreshQueue.sync { isRefreshing = false }
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            let finishRefresh: (Bool, Bool) -> Void = { success, shouldRetry in
                self.refreshQueue.sync { self.isRefreshing = false }

                if !success && shouldRetry && attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt))

                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.refreshAccessTokenWithRetry(attempt: attempt + 1, maxRetries: maxRetries, completion: completion)
                    }
                } else {
                    DispatchQueue.main.async { completion(success) }
                }
            }

            // Check for HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode

                // 401/403: Invalid refresh token (don't retry)
                if statusCode == 401 || statusCode == 403 {
                    finishRefresh(false, false)  // Don't retry
                    return
                }

                // 5xx: Server error (retry)
                if statusCode >= 500 {
                    finishRefresh(false, true)  // Retry
                    return
                }

                // 429: Rate limit (retry with longer delay)
                if statusCode == 429 {
                    finishRefresh(false, true)  // Retry
                    return
                }
            }

            // Network error (retry)
            if let error = error {
                let nsError = error as NSError
                // Check if it's a network error (no internet, timeout, etc.)
                let isNetworkError = nsError.domain == NSURLErrorDomain &&
                                    (nsError.code == NSURLErrorNotConnectedToInternet ||
                                     nsError.code == NSURLErrorTimedOut ||
                                     nsError.code == NSURLErrorCannotFindHost ||
                                     nsError.code == NSURLErrorCannotConnectToHost)

                if isNetworkError {
                    finishRefresh(false, true)  // Retry
                } else {
                    finishRefresh(false, false)  // Don't retry
                }
                return
            }

            guard let data = data else {
                finishRefresh(false, true)  // Retry
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let accessToken = json["access_token"] as? String,
                       let refreshToken = json["refresh_token"] as? String {
                        self.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                        self.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                        finishRefresh(true, false)
                    } else if let errorMsg = json["error"] as? String {
                        // Check if it's an auth error (don't retry) or other error (retry)
                        let shouldRetry = !errorMsg.contains("invalid") && !errorMsg.contains("expired")
                        finishRefresh(false, shouldRetry)
                    } else {
                        finishRefresh(false, true)  // Retry
                    }
                } else {
                    finishRefresh(false, true)  // Retry
                }
            } catch {
                finishRefresh(false, true)  // Retry
            }
        }.resume()
    }
    
    // MARK: - Account Validation Methods
    
    private func validateAccountStatus(user: User, completion: @escaping (Bool) -> Void) {

        // ✅ FIXED: Use backendApiURL instead of webAppURL for API calls
        // Create the validation request to check if account is still active
        let validationURL = URL(string: "\(Configuration.backendApiURL)/api/auth/guard")!
        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(true)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(true)
                return
            }
            
            
            if httpResponse.statusCode == 200 {
                // Account is active
                completion(true)
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Account is deactivated or unauthorized
                completion(false)
            } else {
                // Other statuses (e.g., 3xx/5xx) - be lenient to avoid logging out on poor connectivity
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Keychain Helper Methods
    
    private func saveToKeychain(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
        }
    }
    
    private func loadFromKeychain(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    private func deleteFromKeychain(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Authentication Methods
    
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        // Create the OAuth URL for Google
        let oauthURL = createOAuthURL(provider: "google")
        
        // Start the authentication session
        let session = ASWebAuthenticationSession(
            url: oauthURL,
            callbackURLScheme: "pawjai"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self?.errorMessage = "No callback URL received"
                    return
                }
                
                self?.handleOAuthCallback(url: callbackURL)
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        // Create the OAuth URL for Apple
        let oauthURL = createOAuthURL(provider: "apple")
        
        // Start the authentication session
        let session = ASWebAuthenticationSession(
            url: oauthURL,
            callbackURLScheme: "pawjai"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self?.errorMessage = "No callback URL received"
                    return
                }

                self?.handleOAuthCallback(url: callbackURL)
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    private func createOAuthURL(provider: String) -> URL {
        // Create the Supabase OAuth URL directly
        var components = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/authorize")!
        
        let queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: Configuration.redirectURL),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        components.queryItems = queryItems
        
        let oauthURL = components.url!
        
        return oauthURL
    }
    
    private func handleOAuthCallback(url: URL) {
        
        // Check if we have tokens directly in the fragment (Supabase direct response)
        if let fragment = url.fragment, !fragment.isEmpty {
            parseTokensFromFragment(fragment)
            return
        }
        
        // Parse URL components for query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid callback URL"
            }
            return
        }
        
        // Check for error in query parameters
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            DispatchQueue.main.async {
                self.errorMessage = "OAuth error: \(error)"
            }
            return
        }
        
        // Extract authorization code from query parameters
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            exchangeCodeForTokens(code: code)
            return
        }
        
        // If we get here, something went wrong
        DispatchQueue.main.async {
            self.errorMessage = "No authorization code or tokens found in callback"
        }
    }
    
    private func parseTokensFromFragment(_ fragment: String) {
        // Parse the fragment as URL query parameters
        var fragmentComponents = URLComponents()
        fragmentComponents.query = fragment
        
        guard let queryItems = fragmentComponents.queryItems else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to parse token fragment"
            }
            return
        }
        
        // Extract tokens from fragment
        var accessToken: String?
        var refreshToken: String?
        
        for item in queryItems {
            switch item.name {
            case "access_token":
                accessToken = item.value
            case "refresh_token":
                refreshToken = item.value
            case "error":
                DispatchQueue.main.async {
                    self.errorMessage = "OAuth error: \(item.value ?? "Unknown error")"
                }
                return
            default:
                break
            }
        }
        
        guard let accessToken = accessToken, let refreshToken = refreshToken else {
            DispatchQueue.main.async {
                self.errorMessage = "Missing access_token or refresh_token in response"
            }
            return
        }
        
        
        // Save tokens to Keychain for persistence
        saveTokens(accessToken: accessToken, refreshToken: refreshToken)

        // Store tokens and mark as authenticated on main thread
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)

            // Force UI update
            self.objectWillChange.send()

            // ✅ P0 FIX: Sync tokens to WebView silently (no navigation!)
            self.syncTokensToWebViewCookie(accessToken: accessToken, refreshToken: refreshToken)
        }
    }
    
    private func exchangeCodeForTokens(code: String) {
        // Create the token exchange request
        let tokenURL = URL(string: "\(Configuration.supabaseURL)/auth/v1/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Configuration.redirectURL
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            errorMessage = "Failed to create request body"
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            // Save tokens to Keychain for persistence
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)

                            // Store tokens and mark as authenticated on main thread
                            DispatchQueue.main.async {
                                self?.isAuthenticated = true
                                self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)

                                // Force UI update
                                self?.objectWillChange.send()

                                // ✅ P0 FIX: Sync tokens to WebView silently (no navigation!)
                                self?.syncTokensToWebViewCookie(accessToken: accessToken, refreshToken: refreshToken)
                            }
                        } else if let error = json["error"] as? String {
                            DispatchQueue.main.async {
                                self?.errorMessage = "Token exchange error: \(error)"
                            }
                        } else {
                            DispatchQueue.main.async {
                                self?.errorMessage = "Invalid token response"
                            }
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to parse token response"
                    } 
                }
            }
        }.resume()
    }
    
    
    // MARK: - Email/Password Authentication Methods
    
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        
        // Create the sign in request using the correct Supabase Auth API format
        var urlComponents = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/token")!
        urlComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "apikey", value: Configuration.supabaseAnonKey)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to create request body"
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        if let data = data, let _ = String(data: data, encoding: .utf8) {
                            // Error logged but not used
                        }
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Check for different possible response structures
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            
                            // Save tokens to Keychain for persistence
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Store tokens and mark as authenticated
                            self?.isAuthenticated = true
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)

                            // Force UI update
                            self?.objectWillChange.send()

                            // ✅ P0 FIX: Sync tokens to WebView silently (no navigation!)
                            self?.syncTokensToWebViewCookie(accessToken: accessToken, refreshToken: refreshToken)
                            
                        } else if let error = json["error"] as? String {
                            // Check if error is due to unconfirmed email
                            if error.contains("Email not confirmed") || error.contains("email_confirmed_at") {
                                self?.requiresEmailConfirmation = true
                                self?.pendingEmailConfirmation = email
                            } else {
                                self?.errorMessage = error
                            }
                        } else if let msg = json["msg"] as? String {
                            // Handle Supabase error format with 'msg' field
                            self?.errorMessage = msg
                        } else if json["error_code"] != nil {
                            // Handle Supabase error format with 'error_code' field
                            let errorMessage = json["msg"] as? String ?? "Authentication failed"
                            self?.errorMessage = errorMessage
                        } else {
                            self?.errorMessage = "Invalid response from server"
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to parse server response"
                }
            }
        }.resume()
    }
    
    func signUpWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        
        // Create the sign up request using the correct Supabase Auth API format
        var urlComponents = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/signup")!
        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: Configuration.supabaseAnonKey)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to create request body"
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        if let data = data, let _ = String(data: data, encoding: .utf8) {
                            // Error logged but not used
                        }
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                        // Check if user exists in response
                        if json["user"] != nil {
                            // User data exists in response
                        }

                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            
                            // Save tokens to Keychain for persistence
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Store tokens and mark as authenticated
                            self?.isAuthenticated = true
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)

                            // Force UI update
                            self?.objectWillChange.send()

                            // ✅ P0 FIX: Sync tokens to WebView silently (no navigation!)
                            self?.syncTokensToWebViewCookie(accessToken: accessToken, refreshToken: refreshToken)
                            
                        } else if let userEmail = json["email"] as? String,
                                  json["confirmation_sent_at"] != nil {
                            
                            // Email confirmation required - response has confirmation_sent_at
                            self?.requiresEmailConfirmation = true
                            self?.pendingEmailConfirmation = userEmail
                            
                        } else if let user = json["user"] as? [String: Any],
                                  let userEmail = user["email"] as? String,
                                  user["email_confirmed_at"] == nil {
                            
                            // Email confirmation required - nested user object
                            self?.requiresEmailConfirmation = true
                            self?.pendingEmailConfirmation = userEmail
                            
                        } else if let user = json["user"] as? [String: Any],
                                  let userEmail = user["email"] as? String {
                            
                            // Check if this is a signup response without tokens (email confirmation required)
                            if json["access_token"] == nil && json["refresh_token"] == nil {
                                self?.requiresEmailConfirmation = true
                                self?.pendingEmailConfirmation = userEmail
                            } else {
                                self?.errorMessage = "Unexpected response from server"
                            }
                            
                        } else if let error = json["error"] as? String {
                            self?.errorMessage = error
                        } else if let msg = json["msg"] as? String {
                            // Handle Supabase error format with 'msg' field
                            self?.errorMessage = msg
                        } else if json["error_code"] != nil {
                            // Handle Supabase error format with 'error_code' field
                            let errorMessage = json["msg"] as? String ?? "Sign up failed"
                            self?.errorMessage = errorMessage
                        } else {
                            self?.errorMessage = "Invalid response from server"
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to parse server response"
                }
            }
        }.resume()
    }
    
    func resetPassword(email: String, completion: @escaping (Bool, String?) -> Void) {
        
        // Create the password reset request
        var urlComponents = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/recover")!
        urlComponents.queryItems = [
            URLQueryItem(name: "apikey", value: Configuration.supabaseAnonKey)
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "email": email,
            "options": [
                "emailRedirectTo": "\(Configuration.webAppURL)/auth/reset-password"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                completion(false, "Failed to create request body")
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, nil)
                        return
                    } else if httpResponse.statusCode != 200 {
                        if let data = data, let _ = String(data: data, encoding: .utf8) {
                            // Error logged but not used
                        }
                    }
                }
                
                // If we get here, it was successful
                completion(true, nil)
            }
        }.resume()
    }
    
    func signOut() {
        // Unregister push notifications
        PushManager.shared.unregister()

        clearStoredTokens()

        // Clear all WebView cookies (especially auth session cookie)
        clearWebViewCookies()

        // Clear WebView data store (localStorage, IndexedDB, cache)
        clearWebViewDataStore()

        // Clear all scheduled notifications
        NotificationManager.shared.removeAllNotifications()

        // Cancel background refresh tasks
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "co.pawjai.tokenRefresh")

        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
            self.errorMessage = nil

            // Post notification to reload WebView (clears memory cache)
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }
    }

    private func clearWebViewCookies() {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                // Remove all pawjai.co cookies
                if cookie.domain.contains("pawjai.co") {
                    cookieStore.delete(cookie)
                }
            }
        }
    }

    private func clearWebViewDataStore() {
        let dataTypes = Set([
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeOfflineWebApplicationCache
        ])

        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: date,
            completionHandler: {}
        )
    }
    
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SupabaseManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - User Model

struct User {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Auth Error Types

// 🔥 P1 FIX: Specific error types with user-friendly messages
enum AuthError: Error {
    case networkUnavailable
    case invalidCredentials
    case accountDisabled
    case emailNotConfirmed
    case serverError
    case tokenExpired
    case invalidInput
    case unknown(String)

    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Please check your network and try again."
        case .invalidCredentials:
            return "Email or password is incorrect. Please try again or reset your password."
        case .accountDisabled:
            return "Your account has been disabled. Please contact support for assistance."
        case .emailNotConfirmed:
            return "Please check your email and click the confirmation link to activate your account."
        case .serverError:
            return "We're experiencing technical difficulties. Please try again in a few minutes."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .invalidInput:
            return "Please check your information and try again."
        case .unknown(let message):
            return message
        }
    }

    var logMessage: String {
        switch self {
        case .networkUnavailable:
            return "Network unreachable"
        case .invalidCredentials:
            return "Authentication failed - invalid credentials"
        case .accountDisabled:
            return "Account disabled"
        case .emailNotConfirmed:
            return "Email not confirmed"
        case .serverError:
            return "Server error"
        case .tokenExpired:
            return "Token expired"
        case .invalidInput:
            return "Invalid input"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToURL = Notification.Name("navigateToURL")
    static let syncWebViewTokens = Notification.Name("syncWebViewTokens")
    static let verifyWebViewSession = Notification.Name("verifyWebViewSession")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}
