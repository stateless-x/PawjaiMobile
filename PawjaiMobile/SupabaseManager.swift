//
//  SupabaseManager.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import Foundation
import AuthenticationServices
import Security

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
        
        // Check for stored authentication tokens
        if let storedUser = loadStoredUser() {
            // If access token is fresh, validate account and proceed
            if isTokenValid(user: storedUser) {
                validateAccountStatus(user: storedUser) { [weak self] isValid in
                    DispatchQueue.main.async {
                        if isValid {
                            self?.currentUser = storedUser
                            self?.isAuthenticated = true
                            self?.objectWillChange.send()
                            self?.navigateToHandoff(accessToken: storedUser.accessToken, refreshToken: storedUser.refreshToken)
                        } else {
                            // Account invalid
                            self?.clearStoredTokens()
                            self?.isAuthenticated = false
                            self?.currentUser = nil
                        }
                        self?.isInitializing = false
                    }
                }
            } else {
                // Access token likely expired; try to refresh before deciding
                refreshAccessToken { [weak self] success in
                    guard let self = self else { return }
                    if success, let refreshedUser = self.loadStoredUser() {
                        self.validateAccountStatus(user: refreshedUser) { [weak self] isValid in
                            DispatchQueue.main.async {
                                if isValid {
                                    self?.currentUser = refreshedUser
                                    self?.isAuthenticated = true
                                    self?.objectWillChange.send()
                                    self?.navigateToHandoff(accessToken: refreshedUser.accessToken, refreshToken: refreshedUser.refreshToken)
                                } else {
                                    self?.clearStoredTokens()
                                    self?.isAuthenticated = false
                                    self?.currentUser = nil
                                }
                                self?.isInitializing = false
                            }
                        }
                    } else {
                        // Refresh failed; clear tokens and show auth view
                        // Do NOT attempt validation with expired token
                        DispatchQueue.main.async {
                            self.clearStoredTokens()
                            self.isAuthenticated = false
                            self.currentUser = nil
                            self.isInitializing = false
                        }
                    }
                }
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
            self.isInitializing = false
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
        }
    }

    private func attemptTokenRefresh(user: User) {
        refreshAccessToken { [weak self] success in
            if success {
                if let refreshedUser = self?.currentUser {
                    self?.navigateToHandoff(accessToken: refreshedUser.accessToken, refreshToken: refreshedUser.refreshToken)
                }
            } else {
                // Validate account status before signing out
                self?.validateAccountStatus(user: user) { [weak self] isValid in
                    if !isValid {
                        DispatchQueue.main.async {
                            self?.signOut()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func navigateToHandoff(accessToken: String, refreshToken: String) {
        var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
        handoffComponents.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        if let handoffURL = handoffComponents.url {
            NotificationCenter.default.post(
                name: .navigateToURL,
                object: nil,
                userInfo: ["url": handoffURL]
            )
        }
    }

    // MARK: - Keychain Storage Methods

    private func saveTokens(accessToken: String, refreshToken: String) {
        // Save to Keychain
        saveToKeychain(accessToken, forKey: "access_token")
        saveToKeychain(refreshToken, forKey: "refresh_token")
        saveToKeychain(String(Date().timeIntervalSince1970), forKey: "token_timestamp")
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
    
    // MARK: - Token Refresh Methods
    
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
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
            // Helper to reset flag and call completion
            let finishRefresh: (Bool) -> Void = { success in
                self?.refreshQueue.sync { self?.isRefreshing = false }
                DispatchQueue.main.async { completion(success) }
            }

            // Do not dispatch to main immediately; parse off main thread, switch at end
            if error != nil {
                finishRefresh(false)
                return
            }
            guard let data = data else {
                finishRefresh(false)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let accessToken = json["access_token"] as? String,
                       let refreshToken = json["refresh_token"] as? String {
                        self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                        self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                        finishRefresh(true)
                    } else if json["error"] != nil {
                        finishRefresh(false)
                    } else {
                        finishRefresh(false)
                    }
                } else {
                    finishRefresh(false)
                }
            } catch {
                finishRefresh(false)
            }
        }.resume()
    }
    
    // MARK: - Account Validation Methods
    
    private func validateAccountStatus(user: User, completion: @escaping (Bool) -> Void) {
        
        // Create the validation request to check if account is still active
        let validationURL = URL(string: "\(Configuration.webAppURL)/api/auth/guard")!
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

            // Navigate to native-handoff to set up web app session
            self.navigateToHandoff(accessToken: accessToken, refreshToken: refreshToken)
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

                                // Navigate to native-handoff to set up web app session
                                self?.navigateToHandoff(accessToken: accessToken, refreshToken: refreshToken)
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

                            // Navigate to native-handoff to set up web app session
                            self?.navigateToHandoff(accessToken: accessToken, refreshToken: refreshToken)
                            
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

                            // Navigate to native-handoff to set up web app session
                            self?.navigateToHandoff(accessToken: accessToken, refreshToken: refreshToken)
                            
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
        clearStoredTokens()
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
            self.errorMessage = nil
        }
    }
    
    // MARK: - Token Refresh

    // Proactive token refresh - called before making API requests or on navigation
    func ensureValidToken(completion: @escaping (Bool) -> Void) {
        guard currentUser != nil, isAuthenticated else {
            completion(false)
            return
        }
        
        // Check if token is close to expiring (within 5 minutes)
        guard let timestampString = loadFromKeychain(forKey: "token_timestamp"),
              let timestamp = Double(timestampString) else {
            completion(false)
            return
        }
        
        let tokenAge = Date().timeIntervalSince1970 - timestamp
        let timeUntilExpiry = 3600 - tokenAge // Assuming 1 hour token lifetime
        
        if timeUntilExpiry < 300 { // Less than 5 minutes remaining
            refreshAccessToken { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.objectWillChange.send()
                    }
                    completion(success)
                }
            }
        } else {
            completion(true)
        }
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

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToURL = Notification.Name("navigateToURL")
}
