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
                self.currentUser = storedUser
                self.isAuthenticated = true
                print("📱 Restored authentication state from storage")
                
                // Force UI update and notify ContentView to load dashboard
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                    let dashboardURL = URL(string: "\(Configuration.webAppURL)/dashboard")!
                    NotificationCenter.default.post(
                        name: .navigateToURL,
                        object: nil,
                        userInfo: ["url": dashboardURL]
                    )
                    print("📱 Posted navigateToURL notification for restored auth state")
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
        // Consider tokens valid for 24 hours (86400 seconds)
        return tokenAge < 86400
    }
    
    private func clearStoredTokens() {
        deleteFromKeychain(forKey: "access_token")
        deleteFromKeychain(forKey: "refresh_token")
        deleteFromKeychain(forKey: "token_timestamp")
        print("📱 Tokens cleared from Keychain")
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
                print("📱 Callback URL: \(callbackURL?.absoluteString ?? "nil")")
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
                print("📱 Callback URL: \(callbackURL?.absoluteString ?? "nil")")
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
                
                print("📱 Processing Apple OAuth callback: \(callbackURL)")
                self?.handleOAuthCallback(url: callbackURL)
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    private func createOAuthURL(provider: String) -> URL {
        // Create the Supabase OAuth URL directly
        var components = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/authorize")!
        
        var queryItems = [
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
        print("📱 Received callback URL: \(url)")
        print("📱 URL scheme: \(url.scheme ?? "nil")")
        print("📱 URL host: \(url.host ?? "nil")")
        print("📱 URL path: \(url.path)")
        print("📱 URL query: \(url.query ?? "nil")")
        print("📱 URL fragment: \(url.fragment ?? "nil")")
        
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
        print("📱 Parsing tokens from fragment: \(fragment)")
        
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
    
    // Manual method to force authentication state update (for debugging)
    func forceAuthenticationUpdate() {
        DispatchQueue.main.async {
            print("📱 Forcing authentication state update")
            self.objectWillChange.send()
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
