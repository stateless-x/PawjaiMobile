# Pawjai Mobile App

A native iOS wrapper for the Pawjai web application with integrated authentication.

## Features

- **Native OAuth**: Full Google OAuth integration using ASWebAuthenticationSession
- **Token Management**: Handles authorization code exchange for access/refresh tokens
- **WebView Integration**: Seamless web app experience within native shell
- **Deep Link Support**: Handles OAuth callbacks via `pawjai://auth-callback`
- **Sign Out**: Native sign-out functionality

## Setup Instructions

### 1. Xcode Configuration

1. Open `PawjaiMobile.xcodeproj` in Xcode
2. Add custom URL scheme:
   - Go to Project Settings → Info → URL Types
   - Add new URL Type with:
     - Identifier: `pawjai-auth`
     - URL Schemes: `pawjai`

### 2. Supabase Configuration

1. Update `Configuration.swift` with your actual Supabase anon key:
   ```swift
   static let supabaseAnonKey = "your_actual_anon_key_here"
   ```

2. In Supabase Dashboard → Auth → Redirect URLs, add:
   ```
   pawjai://auth-callback
   ```

### 3. Web App Integration

The mobile app integrates with the web app through:
- `/auth/native-handoff` - Handles token handoff from native to web
- `/auth/callback` - Processes OAuth callbacks
- `/auth/signin` - Web-based sign-in page

## Architecture

### Authentication Flow

1. User taps "Sign in with Google" in native app
2. Native app opens ASWebAuthenticationSession with Supabase OAuth URL
3. User completes Google OAuth in the native session
4. OAuth callback returns authorization code to native app
5. Native app exchanges authorization code for access/refresh tokens
6. App navigates to dashboard WebView with authenticated session

### Key Components

- **AuthView**: Native sign-in interface
- **SupabaseManager**: Handles authentication state
- **WebViewContainer**: Displays web app with native controls
- **Configuration**: Centralized app configuration

## Development

The app uses SwiftUI and follows a simple MVVM pattern. The authentication is handled through a combination of native UI and web-based OAuth flow for simplicity and reliability.

## Notes

- The implementation uses native OAuth with proper token management
- Tokens are stored in memory and exchanged via Supabase's token endpoint
- The app assumes the web app is accessible at `https://pawjai.co`
- For production, consider implementing secure token storage (Keychain)
