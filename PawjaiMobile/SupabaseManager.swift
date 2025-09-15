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
    
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    private let redirectURL: String
    
    private override init() {
        print("🔐 SupabaseManager initializing...")
        self.supabaseURL = URL(string: Configuration.supabaseURL)!
        self.supabaseAnonKey = Configuration.supabaseAnonKey
        self.redirectURL = Configuration.redirectURL
        super.init()
        
        print("🔐 SupabaseManager configuration loaded:")
        print("🔐 Supabase URL: \(Configuration.supabaseURL)")
        print("🔐 Redirect URL: \(Configuration.redirectURL)")
        print("🔐 Web App URL: \(Configuration.webAppURL)")
        
        // Check for existing authentication state
        checkAuthenticationState()
        print("🔐 SupabaseManager initialization complete")
    }
    
    private func checkAuthenticationState() {
        print("🔐 Checking authentication state...")
        
        // Check for stored authentication tokens
        if let storedUser = loadStoredUser() {
            print("🔐 Found stored user, checking token validity...")
            // Check if tokens are still valid (not expired)
            if isTokenValid(user: storedUser) {
                // Validate account status with server before setting as authenticated
                validateAccountStatus(user: storedUser) { [weak self] isValid in
                    DispatchQueue.main.async {
                        if isValid {
                            self?.currentUser = storedUser
                            self?.isAuthenticated = true
                            print("📱 Restored authentication state from storage")
                            
                            // Start periodic validation
                            self?.startPeriodicValidation()
                            
                            // Force UI update and notify ContentView to load dashboard
                            self?.objectWillChange.send()
                            let dashboardURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                            NotificationCenter.default.post(
                                name: .navigateToURL,
                                object: nil,
                                userInfo: ["url": dashboardURL]
                            )
                            print("📱 Posted navigateToURL notification for restored auth state")
                        } else {
                            // Account is deactivated or invalid, clear storage
                            self?.clearStoredTokens()
                            self?.isAuthenticated = false
                            self?.currentUser = nil
                            print("📱 Account validation failed, clearing authentication state")
                        }
                    }
                }
            } else {
                // Tokens expired, clear storage
                clearStoredTokens()
                self.isAuthenticated = false
                self.currentUser = nil
                print("📱 Stored tokens expired, clearing authentication state")
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
            print("📱 No stored authentication found, showing AuthView")
        }
        
        print("🔐 Authentication state check complete - isAuthenticated: \(self.isAuthenticated)")
    }
    
    // MARK: - Keychain Storage Methods
    
    private func saveTokens(accessToken: String, refreshToken: String) {
        // Save to Keychain
        saveToKeychain(accessToken, forKey: "access_token")
        saveToKeychain(refreshToken, forKey: "refresh_token")
        saveToKeychain(String(Date().timeIntervalSince1970), forKey: "token_timestamp")
        print("📱 Tokens saved to Keychain")
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
        // Consider tokens valid for 1 hour (3600 seconds) to allow for refresh
        let isTimeValid = tokenAge < 3600
        
        if !isTimeValid {
            // Try to refresh the token before considering it invalid
            refreshAccessToken { [weak self] success in
                if !success {
                    DispatchQueue.main.async {
                        self?.signOut()
                    }
                }
            }
            return false
        }
        
        return true
    }
    
    private func clearStoredTokens() {
        deleteFromKeychain(forKey: "access_token")
        deleteFromKeychain(forKey: "refresh_token")
        deleteFromKeychain(forKey: "token_timestamp")
        print("📱 Tokens cleared from Keychain")
    }
    
    // MARK: - Token Refresh Methods
    
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = loadFromKeychain(forKey: "refresh_token") else {
            print("📱 No refresh token available")
            completion(false)
            return
        }
        
        print("📱 Refreshing access token...")
        
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
            print("📱 Failed to create refresh request body: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("📱 Token refresh error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("📱 No data received from token refresh")
                    completion(false)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            print("📱 Token refresh successful")
                            
                            // Save new tokens
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Update current user
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                            
                            completion(true)
                        } else if let error = json["error"] as? String {
                            print("📱 Token refresh error from server: \(error)")
                            completion(false)
                        } else {
                            print("📱 Invalid token refresh response")
                            completion(false)
                        }
                    }
                } catch {
                    print("📱 Failed to parse token refresh response: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Account Validation Methods
    
    private func validateAccountStatus(user: User, completion: @escaping (Bool) -> Void) {
        print("🔐 Validating account status with server...")
        
        // Create the validation request to check if account is still active
        let validationURL = URL(string: "\(Configuration.webAppURL)/api/auth/guard")!
        var request = URLRequest(url: validationURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(user.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("📱 Account validation error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("📱 Invalid response from account validation")
                completion(false)
                return
            }
            
            print("📱 Account validation HTTP status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Account is active
                print("📱 Account validation successful - account is active")
                completion(true)
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Account is deactivated or unauthorized
                print("📱 Account validation failed - account is deactivated or unauthorized")
                completion(false)
            } else {
                // Other error - assume account is invalid
                print("📱 Account validation failed with status: \(httpResponse.statusCode)")
                completion(false)
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
            print("📱 Failed to save to Keychain: \(status)")
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
                
                print("📱 OAuth callback received")
                // print("📱 Callback URL: \(callbackURL?.absoluteString ?? "nil")")
                print("📱 Error: \(error?.localizedDescription ?? "nil")")
                
                if let error = error {
                    print("📱 OAuth error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("📱 No callback URL received")
                    self?.errorMessage = "No callback URL received"
                    return
                }
                
                print("📱 Processing OAuth callback: \(callbackURL)")
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
                
                print("📱 Apple OAuth callback received")
                // print("📱 Callback URL: \(callbackURL?.absoluteString ?? "nil")")
                print("📱 Error: \(error?.localizedDescription ?? "nil")")
                
                if let error = error {
                    print("📱 Apple OAuth error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("📱 No callback URL received")
                    self?.errorMessage = "No callback URL received"
                    return
                }
                
                // print("📱 Processing Apple OAuth callback: \(callbackURL)")
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
        print("🔗 \(provider.capitalized) OAuth URL: \(oauthURL)")
        print("🔗 Redirect URL: \(Configuration.redirectURL)")
        print("🔗 Supabase URL: \(Configuration.supabaseURL)")
        print("🔗 Web App URL: \(Configuration.webAppURL)")
        
        return oauthURL
    }
    
    private func handleOAuthCallback(url: URL) {
        // print("📱 Received callback URL: \(url)")
        print("📱 URL scheme: \(url.scheme ?? "nil")")
        print("📱 URL host: \(url.host ?? "nil")")
        print("📱 URL path: \(url.path)")
        print("📱 URL query: \(url.query ?? "nil")")
        // print("📱 URL fragment: \(url.fragment ?? "nil")")
        
        // Check if we have tokens directly in the fragment (Supabase direct response)
        if let fragment = url.fragment, !fragment.isEmpty {
            print("📱 Found tokens in fragment, parsing directly")
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
            print("📱 Found authorization code, exchanging for tokens")
            exchangeCodeForTokens(code: code)
            return
        }
        
        // If we get here, something went wrong
        DispatchQueue.main.async {
            self.errorMessage = "No authorization code or tokens found in callback"
        }
    }
    
    private func parseTokensFromFragment(_ fragment: String) {
        // print("📱 Parsing tokens from fragment: \(fragment)")
        
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
        
        print("📱 Successfully extracted tokens from fragment")
        
        // Save tokens to Keychain for persistence
        saveTokens(accessToken: accessToken, refreshToken: refreshToken)
        
        // Store tokens and mark as authenticated on main thread
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
            print("📱 Direct token authentication successful")
            print("📱 isAuthenticated set to: \(self.isAuthenticated)")
            
            // Start periodic validation
            self.startPeriodicValidation()
            
            // Force UI update
            self.objectWillChange.send()
            
            // Navigate to native-handoff to set up web app session, then redirect to dashboard
            var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
            handoffComponents.queryItems = [
                URLQueryItem(name: "access_token", value: accessToken),
                URLQueryItem(name: "refresh_token", value: refreshToken)
            ]
            
            if let handoffURL = handoffComponents.url {
                print("📱 Posting navigateToURL notification with URL: \(handoffURL)")
                NotificationCenter.default.post(
                    name: .navigateToURL,
                    object: nil,
                    userInfo: ["url": handoffURL]
                )
            } else {
                print("📱 Failed to create handoff URL")
            }
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
                                print("📱 Token exchange successful, user authenticated")
                                print("📱 isAuthenticated set to: \(self?.isAuthenticated ?? false)")
                                
                                // Start periodic validation
                                self?.startPeriodicValidation()
                                
                                // Force UI update
                                self?.objectWillChange.send()
                                
                                // Navigate to native-handoff to set up web app session, then redirect to dashboard
                                var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
                                handoffComponents.queryItems = [
                                    URLQueryItem(name: "access_token", value: accessToken),
                                    URLQueryItem(name: "refresh_token", value: refreshToken)
                                ]
                                
                                if let handoffURL = handoffComponents.url {
                                    print("📱 Posting navigateToURL notification with URL: \(handoffURL)")
                                    NotificationCenter.default.post(
                                        name: .navigateToURL,
                                        object: nil,
                                        userInfo: ["url": handoffURL]
                                    )
                                } else {
                                    print("📱 Failed to create handoff URL")
                                }
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
        
        print("📱 Starting email sign in for: \(email)")
        
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
                    print("📱 Email sign in error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📱 HTTP Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("📱 HTTP Error: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("📱 Error response: \(errorString)")
                        }
                    }
                }
                
                guard let data = data else {
                    print("📱 No data received from email sign in")
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📱 Email sign in response: \(json)")
                        print("📱 Response keys: \(Array(json.keys))")
                        
                        // Check for different possible response structures
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            print("📱 Email sign in successful, tokens received")
                            
                            // Save tokens to Keychain for persistence
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Store tokens and mark as authenticated
                            self?.isAuthenticated = true
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                            print("📱 Email sign in authentication successful")
                            print("📱 isAuthenticated set to: \(self?.isAuthenticated ?? false)")
                            
                            // Start periodic validation
                            self?.startPeriodicValidation()
                            
                            // Force UI update
                            self?.objectWillChange.send()
                            
                            // Navigate to native-handoff to set up web app session, then redirect to dashboard
                            var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
                            handoffComponents.queryItems = [
                                URLQueryItem(name: "access_token", value: accessToken),
                                URLQueryItem(name: "refresh_token", value: refreshToken)
                            ]
                            
                            if let handoffURL = handoffComponents.url {
                                print("📱 Posting navigateToURL notification with URL: \(handoffURL)")
                                NotificationCenter.default.post(
                                    name: .navigateToURL,
                                    object: nil,
                                    userInfo: ["url": handoffURL]
                                )
                            } else {
                                print("📱 Failed to create handoff URL")
                            }
                            
                        } else if let error = json["error"] as? String {
                            // Check if error is due to unconfirmed email
                            if error.contains("Email not confirmed") || error.contains("email_confirmed_at") {
                                print("📱 Email sign in requires email confirmation")
                                self?.requiresEmailConfirmation = true
                                self?.pendingEmailConfirmation = email
                            } else {
                                print("📱 Email sign in error from server: \(error)")
                                self?.errorMessage = error
                            }
                        } else if let msg = json["msg"] as? String {
                            // Handle Supabase error format with 'msg' field
                            print("📱 Email sign in error from server: \(msg)")
                            self?.errorMessage = msg
                        } else if json["error_code"] != nil {
                            // Handle Supabase error format with 'error_code' field
                            let errorMessage = json["msg"] as? String ?? "Authentication failed"
                            print("📱 Email sign in error from server: \(errorMessage)")
                            self?.errorMessage = errorMessage
                        } else {
                            print("📱 Invalid email sign in response")
                            print("📱 Expected access_token and refresh_token, but got: \(json)")
                            self?.errorMessage = "Invalid response from server"
                        }
                    }
                } catch {
                    print("📱 Failed to parse email sign in response: \(error)")
                    self?.errorMessage = "Failed to parse server response"
                }
            }
        }.resume()
    }
    
    func signUpWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        print("📱 Starting email sign up for: \(email)")
        
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
                    print("📱 Email sign up error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📱 HTTP Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("📱 HTTP Error: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("📱 Error response: \(errorString)")
                        }
                    }
                }
                
                guard let data = data else {
                    print("📱 No data received from email sign up")
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📱 Email sign up response: \(json)")
                        print("📱 Signup response keys: \(Array(json.keys))")
                        
                        // Check if user exists in response
                        if let user = json["user"] as? [String: Any] {
                            print("📱 User object found: \(user)")
                            print("📱 User keys: \(Array(user.keys))")
                        }
                        
                        if let accessToken = json["access_token"] as? String,
                           let refreshToken = json["refresh_token"] as? String {
                            
                            print("📱 Email sign up successful, tokens received")
                            
                            // Save tokens to Keychain for persistence
                            self?.saveTokens(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Store tokens and mark as authenticated
                            self?.isAuthenticated = true
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                            print("📱 Email sign up authentication successful")
                            print("📱 isAuthenticated set to: \(self?.isAuthenticated ?? false)")
                            
                            // Start periodic validation
                            self?.startPeriodicValidation()
                            
                            // Force UI update
                            self?.objectWillChange.send()
                            
                            // Navigate to native-handoff to set up web app session, then redirect to dashboard
                            var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
                            handoffComponents.queryItems = [
                                URLQueryItem(name: "access_token", value: accessToken),
                                URLQueryItem(name: "refresh_token", value: refreshToken)
                            ]
                            
                            if let handoffURL = handoffComponents.url {
                                print("📱 Posting navigateToURL notification with URL: \(handoffURL)")
                                NotificationCenter.default.post(
                                    name: .navigateToURL,
                                    object: nil,
                                    userInfo: ["url": handoffURL]
                                )
                            } else {
                                print("📱 Failed to create handoff URL")
                            }
                            
                        } else if let userEmail = json["email"] as? String,
                                  json["confirmation_sent_at"] != nil {
                            
                            // Email confirmation required - response has confirmation_sent_at
                            print("📱 Email sign up successful but requires email confirmation")
                            self?.requiresEmailConfirmation = true
                            self?.pendingEmailConfirmation = userEmail
                            
                        } else if let user = json["user"] as? [String: Any],
                                  let userEmail = user["email"] as? String,
                                  user["email_confirmed_at"] == nil {
                            
                            // Email confirmation required - nested user object
                            print("📱 Email sign up successful but requires email confirmation (nested user)")
                            self?.requiresEmailConfirmation = true
                            self?.pendingEmailConfirmation = userEmail
                            
                        } else if let user = json["user"] as? [String: Any],
                                  let userEmail = user["email"] as? String {
                            
                            // Check if this is a signup response without tokens (email confirmation required)
                            if json["access_token"] == nil && json["refresh_token"] == nil {
                                print("📱 Email sign up successful but requires email confirmation (no tokens)")
                                self?.requiresEmailConfirmation = true
                                self?.pendingEmailConfirmation = userEmail
                            } else {
                                print("📱 Unexpected signup response structure: \(json)")
                                self?.errorMessage = "Unexpected response from server"
                            }
                            
                        } else if let error = json["error"] as? String {
                            print("📱 Email sign up error from server: \(error)")
                            self?.errorMessage = error
                        } else if let msg = json["msg"] as? String {
                            // Handle Supabase error format with 'msg' field
                            print("📱 Email sign up error from server: \(msg)")
                            self?.errorMessage = msg
                        } else if json["error_code"] != nil {
                            // Handle Supabase error format with 'error_code' field
                            let errorMessage = json["msg"] as? String ?? "Sign up failed"
                            print("📱 Email sign up error from server: \(errorMessage)")
                            self?.errorMessage = errorMessage
                        } else {
                            print("📱 Invalid email sign up response")
                            print("📱 Expected access_token and refresh_token, but got: \(json)")
                            self?.errorMessage = "Invalid response from server"
                        }
                    }
                } catch {
                    print("📱 Failed to parse email sign up response: \(error)")
                    self?.errorMessage = "Failed to parse server response"
                }
            }
        }.resume()
    }
    
    func resetPassword(email: String, completion: @escaping (Bool, String?) -> Void) {
        print("📱 Starting password reset for: \(email)")
        
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
                    print("📱 Password reset error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📱 Password reset HTTP Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        print("📱 Password reset email sent successfully")
                        completion(true, nil)
                        return
                    } else if httpResponse.statusCode != 200 {
                        print("📱 Password reset HTTP Error: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("📱 Password reset error response: \(errorString)")
                        }
                    }
                }
                
                // If we get here, it was successful
                completion(true, nil)
            }
        }.resume()
    }
    
    func signOut() {
        // Clear stored tokens from Keychain
        clearStoredTokens()
        
        // Clear authentication state
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
            self.errorMessage = nil
        }
        
        // No need to navigate to URL - ContentView will automatically show AuthView
        // when isAuthenticated becomes false
        print("📱 User signed out, tokens cleared, returning to native AuthView")
    }
    
    // MARK: - Periodic Account Validation
    
    func startPeriodicValidation() {
        // Validate account status every 30 minutes while app is active
        // This is less aggressive to prevent unnecessary logouts
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self = self, let user = self.currentUser, self.isAuthenticated else {
                return
            }
            
            // First try to refresh the token if it's close to expiring
            self.refreshAccessToken { [weak self] refreshSuccess in
                if !refreshSuccess {
                    // If refresh fails, then validate account status
                    self?.validateAccountStatus(user: user) { [weak self] isValid in
                        DispatchQueue.main.async {
                            if !isValid {
                                print("📱 Periodic validation failed - signing out user")
                                self?.signOut()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Manual method to force authentication state update (for debugging)
    func forceAuthenticationUpdate() {
        DispatchQueue.main.async {
            print("📱 Forcing authentication state update")
            self.objectWillChange.send()
        }
    }
    
    // Proactive token refresh - call this before making API requests
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
            print("📱 Token expires soon, refreshing proactively...")
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
