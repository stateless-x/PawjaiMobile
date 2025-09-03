# PawjaiMobile

A native iOS app that provides a webview wrapper for the Pawjai authentication system.

## Features

- **Native WebView**: Uses WKWebView for optimal performance and native feel
- **Authentication Focus**: Opens directly to `pawjai.co/auth/signin`
- **Error Handling**: Graceful error handling with retry functionality
- **Loading States**: Visual feedback during page loading
- **Gesture Support**: Supports back/forward navigation gestures
- **Full Screen**: Web content takes up the full screen area

## Technical Details

- **Platform**: iOS (SwiftUI + UIKit)
- **Minimum iOS Version**: iOS 14.0+
- **Architecture**: SwiftUI with UIViewRepresentable for WebView integration
- **Network Security**: Configured to allow web content and network access via project settings

## Project Structure

```
PawjaiMobile/
├── PawjaiMobile/
│   ├── PawjaiMobileApp.swift      # Main app entry point
│   ├── ContentView.swift          # Main view using WebView
│   ├── WebView.swift              # WebView wrapper and container
│   └── Assets.xcassets/           # App assets
├── PawjaiMobile.xcodeproj/        # Xcode project file with web permissions
└── README.md                      # This file
```

## Setup Instructions

1. Open `PawjaiMobile.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

## Configuration

The app is configured with the following settings in the Xcode project:

- **App Transport Security**: Allows web content and network access
- **Device Orientation**: Supports portrait and landscape orientations
- **Scene Configuration**: Modern iOS app lifecycle management

## Customization

### Changing the URL
To change the opening URL, modify the URL in `ContentView.swift`:

```swift
WebViewContainer(url: URL(string: "https://your-new-url.com")!)
```

### Adding Navigation Controls
The WebView supports standard web navigation gestures. You can add custom navigation buttons by extending the `WebViewContainer`.

### Styling
The app uses SwiftUI's native styling. Modify colors, fonts, and layouts in the respective view files.

## Troubleshooting

### Web Content Not Loading
- Check your internet connection
- Verify the URL is accessible from your device
- Check the console for any error messages

### Build Issues
- Ensure you're using Xcode 14.0 or later
- Clean build folder (Shift+⌘+K) and rebuild
- Check that all files are included in the project target

## License

This project is part of the Pawjai application suite.
