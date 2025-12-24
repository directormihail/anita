# ANITA Backend API

TypeScript backend API for ANITA iOS app.

## Features

- ✅ Chat completion with OpenAI
- ✅ Voice transcription with Whisper
- ✅ File analysis
- ✅ Stripe subscription checkout
- ✅ Rate limiting
- ✅ Security headers
- ✅ Input sanitization
- ✅ App Store compliance endpoints

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```

3. Run in development mode:
```bash
npm run dev
```

4. Build for production:
```bash
npm run build
npm start
```

## Environment Variables

See `.env.example` for all required environment variables.

## API Endpoints

### Versioned Endpoints (Recommended)
- `POST /api/v1/chat-completion` - Chat with ANITA
- `POST /api/v1/transcribe` - Transcribe voice messages
- `POST /api/v1/analyze-file` - Analyze uploaded files
- `POST /api/v1/create-checkout-session` - Create Stripe checkout session

### Legacy Endpoints (Backward Compatible)
- `POST /api/chat-completion` - Redirects to v1
- `POST /api/transcribe` - Redirects to v1
- `POST /api/analyze-file` - Redirects to v1
- `POST /api/create-checkout-session` - Redirects to v1

### Utility Endpoints
- `GET /health` - Health check
- `GET /privacy` - Privacy policy endpoint

## Features

### API Versioning
All endpoints support versioning (`/api/v1/...`) to allow future changes without breaking old iOS clients.

### Request ID Tracking
Every request gets a unique `X-Request-ID` header:
- Automatically generated if not provided
- Included in all responses
- Logged with every request for easy debugging

### Timeout Protection
AI requests have timeouts to prevent hanging:
- Chat completion: 30 seconds
- Transcription: 60 seconds
- File analysis: 45 seconds
- Returns 504 Gateway Timeout if exceeded

## iOS Integration

The backend is configured with CORS to allow requests from iOS apps. Make sure to set `ALLOWED_ORIGINS` in your `.env` file.

