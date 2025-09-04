//
//  SupabaseManager.swift
//  PawjaiMobile
//
//  Created by Purin Buriwong on 3/9/2568 BE.
//

import Foundation
import AuthenticationServices

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
        self.supabaseURL = URL(string: Configuration.supabaseURL)!
        self.supabaseAnonKey = Configuration.supabaseAnonKey
        self.redirectURL = Configuration.redirectURL
        super.init()
    }
    
    // MARK: - Authentication Methods
    
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        // Create the OAuth URL for Google
        let oauthURL = createGoogleOAuthURL()
        
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
    
    private func createGoogleOAuthURL() -> URL {
        // Create the Supabase OAuth URL directly
        var components = URLComponents(string: "\(Configuration.supabaseURL)/auth/v1/authorize")!
        
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: Configuration.redirectURL), // Use native app callback
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        let oauthURL = components.url!
        print("🔗 OAuth URL: \(oauthURL)")
        print("🔗 Redirect URL: \(Configuration.redirectURL)")
        
        return oauthURL
    }
    
    private func handleOAuthCallback(url: URL) {
        print("📱 Received callback URL: \(url)")
        print("📱 URL scheme: \(url.scheme ?? "nil")")
        print("📱 URL host: \(url.host ?? "nil")")
        print("📱 URL path: \(url.path)")
        print("📱 URL query: \(url.query ?? "nil")")
        print("📱 URL fragment: \(url.fragment ?? "nil")")
        
        // Check if tokens are in the URL fragment (after #)
        if let fragment = url.fragment {
            print("📱 Parsing fragment: \(fragment)")
            var fragmentComponents = URLComponents()
            fragmentComponents.query = fragment
            
            guard let fragmentItems = fragmentComponents.queryItems else {
                errorMessage = "Invalid callback fragment"
                return
            }
            
            // Extract tokens from fragment
            var accessToken: String?
            var refreshToken: String?
            var error: String?
            
            for item in fragmentItems {
                switch item.name {
                case "access_token":
                    accessToken = item.value
                case "refresh_token":
                    refreshToken = item.value
                case "error":
                    error = item.value
                default:
                    break
                }
            }
            
            if let error = error {
                errorMessage = "OAuth error: \(error)"
                return
            }
            
            guard let accessToken = accessToken, let refreshToken = refreshToken else {
                errorMessage = "Missing authentication tokens in fragment"
                return
            }
            
            // Store tokens and mark as authenticated
            self.isAuthenticated = true
            self.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
            
            // Navigate to native handoff endpoint with tokens
            var handoffComponents = URLComponents(string: "\(Configuration.webAppURL)/auth/native-handoff")!
            handoffComponents.queryItems = [
                URLQueryItem(name: "access_token", value: accessToken),
                URLQueryItem(name: "refresh_token", value: refreshToken)
            ]
            
            if let handoffURL = handoffComponents.url {
                print("📱 Navigating to handoff URL: \(handoffURL)")
                NotificationCenter.default.post(
                    name: .navigateToURL,
                    object: nil,
                    userInfo: ["url": handoffURL]
                )
            }
            return
        }
        
        // Fallback: Parse the callback URL to extract the authorization code (old flow)
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            errorMessage = "Invalid callback URL"
            return
        }
        
        // Extract the authorization code or error
        var code: String?
        var error: String?
        
        for item in queryItems {
            switch item.name {
            case "code":
                code = item.value
            case "error":
                error = item.value
            default:
                break
            }
        }
        
        if let error = error {
            errorMessage = "OAuth error: \(error)"
            return
        }
        
        guard let code = code else {
            errorMessage = "No authorization code received"
            return
        }
        
        // Exchange the authorization code for tokens
        exchangeCodeForTokens(code: code)
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
                            
                            // Store tokens and mark as authenticated
                            self?.isAuthenticated = true
                            self?.currentUser = User(accessToken: accessToken, refreshToken: refreshToken)
                            
                            // Navigate to native handoff endpoint with tokens
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
                        } else if let error = json["error"] as? String {
                            self?.errorMessage = "Token exchange error: \(error)"
                        } else {
                            self?.errorMessage = "Invalid token response"
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to parse token response"
                }
            }
        }.resume()
    }
    
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
        
        // Navigate back to sign-in
        NotificationCenter.default.post(
            name: .navigateToURL,
            object: nil,
            userInfo: ["url": URL(string: "\(Configuration.webAppURL)/auth/signin")!]
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

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToURL = Notification.Name("navigateToURL")
}
