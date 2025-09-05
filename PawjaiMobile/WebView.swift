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
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Enable file uploads and camera capture
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        
        // Enable file uploads
        webView.configuration.userContentController.add(context.coordinator, name: "fileUpload")
        
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

                
                    // Only redirect to AuthView if we're actually on a signin/signup page
                    // or if we're on the home page (which happens after sign-out)
                    // and not on a redirect or callback page
                    if ((path.contains("/auth/signin") || path.contains("/auth/signup") || path == "/") && 
                       !path.contains("/auth/callback") && 
                       !path.contains("/auth/native-handoff")) {
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
            
            // Handle custom URL schemes
            if url.scheme == "pawjai" {
                if url.host == "signout" {
                    DispatchQueue.main.async {
                        SupabaseManager.shared.signOut()
                    }
                }
                decisionHandler(.cancel)
                return
            }
            
            // Check if the web app is trying to redirect to signin/signup pages
            let path = url.path
            // Only redirect to AuthView if we're actually navigating to a signin/signup page
            // or to the home page (which happens after sign-out)
            // and not to a redirect or callback page
            if ((path.contains("/auth/signin") || path.contains("/auth/signup") || path == "/") && 
               !path.contains("/auth/callback") && 
               !path.contains("/auth/native-handoff")) {
                
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
        
        // Request photo library permission
        private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                let granted = status == .authorized || status == .limited
                completion(granted)
            }
        }
        
        // Check current permission status
        private func checkCameraPermission() -> Bool {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return status == .authorized
        }
        
        private func checkMicrophonePermission() -> Bool {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return status == .authorized
        }
        
        private func checkPhotoLibraryPermission() -> Bool {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            return status == .authorized || status == .limited
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

        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToURL)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                currentURL = url
            }
        }
    }
}
