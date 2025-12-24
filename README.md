# ANITA - AI Financial Assistant

ANITA is an intelligent financial assistant application that helps users manage their finances, track expenses, and get personalized financial insights through natural language conversations.

## Project Structure

This repository contains multiple components of the ANITA ecosystem:

```
.
├── ANITA backend/      # Backend API server (Node.js/TypeScript)
├── ANITA IOS/         # iOS mobile application (Swift/SwiftUI)
├── ANITA webapp/      # Web application (React/TypeScript)
└── anita-landing-page/ # Landing page
```

## Components

### Backend (`ANITA backend/`)
- **Technology**: Node.js, TypeScript, Express
- **Features**:
  - Chat completion API
  - File analysis (financial documents)
  - Audio transcription
  - Checkout session management
  - Health checks and privacy policy endpoints

### iOS App (`ANITA IOS/`)
- **Technology**: Swift, SwiftUI
- **Features**:
  - Chat interface with ANITA
  - Financial dashboard
  - Transaction tracking
  - Settings and preferences
  - Native iOS experience

### Web App (`ANITA webapp/`)
- **Technology**: React, TypeScript
- **Features**:
  - Responsive web interface
  - Mobile and desktop views
  - Financial analytics
  - Chat interface

## Getting Started

### Prerequisites
- Node.js (v18 or higher) for backend
- Xcode (latest version) for iOS development
- npm or yarn for package management

### Backend Setup

```bash
cd "ANITA backend"
npm install
npm run dev
```

The backend will run on `http://localhost:3001` by default.

### iOS Setup

1. Open `ANITA IOS/ANITA.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (⌘R)

### Web App Setup

```bash
cd "ANITA webapp"
npm install
npm start
```

## API Endpoints

- `POST /api/chat/completion` - Chat completion
- `POST /api/transcribe` - Audio transcription
- `POST /api/analyze-file` - File analysis
- `POST /api/create-checkout-session` - Payment processing
- `GET /api/health` - Health check
- `GET /api/privacy` - Privacy policy

## Configuration

### Backend
Set environment variables in `.env`:
- `PORT` - Server port (default: 3001)
- `OPENAI_API_KEY` - OpenAI API key
- Other service credentials

### iOS
Update `NetworkService.swift` with your backend URL:
```swift
private let baseURL = "http://localhost:3001"
```

## Development

### Backend
```bash
cd "ANITA backend"
npm run dev      # Development mode with hot reload
npm run build    # Build for production
npm start        # Run production build
```

### iOS
- Use Xcode for development
- SwiftUI previews available for rapid iteration

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Add your license here]

## Contact

[Add contact information]

