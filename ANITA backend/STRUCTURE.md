# ANITA Backend Structure

## Project Structure

```
ANITA backend/
├── src/
│   ├── index.ts                    # Main server entry point
│   ├── routes/                     # API route handlers
│   │   ├── chat-completion.ts      # Chat with ANITA
│   │   ├── transcribe.ts           # Voice transcription
│   │   ├── analyze-file.ts         # File analysis
│   │   └── create-checkout-session.ts # Stripe checkout
│   └── utils/                      # Utility functions
│       ├── logger.ts               # Logging utility
│       ├── rateLimiter.ts          # Rate limiting
│       ├── sanitizeInput.ts        # Input sanitization
│       └── securityHeaders.ts      # Security headers
├── package.json                     # Dependencies
├── tsconfig.json                    # TypeScript config
└── README.md                        # Documentation
```

## Key Features

### Security
- ✅ Rate limiting on all endpoints
- ✅ Input sanitization
- ✅ Security headers
- ✅ CORS configuration for iOS
- ✅ Request validation

### App Store Compliance
- ✅ Health check endpoint (`/health`)
- ✅ Privacy policy endpoint (`/privacy`)
- ✅ Proper error handling
- ✅ Logging (no sensitive data)

### API Endpoints

1. **POST /api/chat-completion**
   - Chat with ANITA AI
   - Rate limit: 20 requests/minute

2. **POST /api/transcribe**
   - Transcribe voice messages
   - Rate limit: 5 requests/minute

3. **POST /api/analyze-file**
   - Analyze uploaded files
   - Rate limit: 10 requests/minute

4. **POST /api/create-checkout-session**
   - Create Stripe checkout session
   - Rate limit: 10 requests/minute

5. **GET /health**
   - Health check for monitoring

6. **GET /privacy**
   - Privacy policy information

## Environment Variables

See `.env.example` for all required variables.

## Running the Server

```bash
# Development
npm run dev

# Production
npm run build
npm start
```

