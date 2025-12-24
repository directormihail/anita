# ANITA iOS App

SwiftUI iOS application for ANITA - Your Personal Finance AI Assistant.

## Features

- 💬 **Chat Interface**: Text-based conversations with ANITA AI assistant
- 🎤 **Voice Recording**: Record and transcribe voice messages
- 📄 **File Analysis**: Upload and analyze financial documents (PDF, Excel, CSV, etc.)
- ⚙️ **Settings**: Configure backend URL, check connection status, manage subscriptions
- 🔒 **App Store Compliant**: Includes privacy policy, health checks, and proper permissions

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Project Structure

```
ANITA/
├── ANITAApp.swift          # App entry point
├── ContentView.swift       # Main tab navigation
├── Info.plist             # App configuration and permissions
├── Models/
│   └── Models.swift        # Data models for API requests/responses
├── Services/
│   └── NetworkService.swift # Backend API service
├── ViewModels/
│   ├── ChatViewModel.swift
│   ├── VoiceViewModel.swift
│   └── FileAnalysisViewModel.swift
├── Views/
│   ├── ChatView.swift
│   ├── VoiceView.swift
│   ├── FileAnalysisView.swift
│   └── SettingsView.swift
└── Assets.xcassets/       # App icons and assets
```

## Setup

1. **Open the project**:
   ```bash
   open ANITA.xcodeproj
   ```

2. **Configure Backend URL**:
   - The app defaults to `http://localhost:3001` for development
   - Update the backend URL in Settings view or modify `NetworkService.swift`
   - For production, update the default URL in `NetworkService.swift`

3. **Build and Run**:
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## Backend Integration

The app connects to the ANITA backend API with the following endpoints:

- `POST /api/v1/chat-completion` - Chat with ANITA
- `POST /api/v1/transcribe` - Transcribe voice messages
- `POST /api/v1/analyze-file` - Analyze uploaded files
- `POST /api/v1/create-checkout-session` - Create Stripe checkout session
- `GET /health` - Health check
- `GET /privacy` - Privacy policy

## Permissions

The app requires the following permissions (configured in Info.plist):

- **Microphone**: For voice recording and transcription
- **Photo Library**: For accessing financial documents
- **Documents**: For file analysis

## App Store Compliance

The app includes:

- ✅ Privacy policy endpoint integration
- ✅ Health check endpoint for monitoring
- ✅ Proper permission descriptions
- ✅ Secure network communication (HTTPS)
- ✅ Error handling and user feedback
- ✅ Subscription management via Stripe

## Development Notes

### Backend URL Configuration

The backend URL can be configured in two ways:

1. **Runtime**: Use the Settings view to update the backend URL
2. **Code**: Modify the default URL in `NetworkService.swift`

### Voice Recording

The voice recording feature requires:
1. Audio file upload to Supabase storage (not yet implemented in this version)
2. The backend expects a Supabase storage URL for transcription

To complete the voice feature, you'll need to:
- Integrate Supabase iOS SDK
- Upload recorded audio files to Supabase storage
- Pass the public URL to the transcription endpoint

### File Analysis

Currently supports text-based files. For full support of PDF, Excel, and images, you'll need to:
- Add PDF parsing libraries
- Add Excel/CSV parsing
- Add OCR capabilities for images

## License

Copyright © 2024 ANITA. All rights reserved.

