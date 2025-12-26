/**
 * ANITA Backend Server
 * TypeScript Express server for iOS app
 */

import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { handleChatCompletion } from './routes/chat-completion';
import { handleTranscribe } from './routes/transcribe';
import { handleAnalyzeFile } from './routes/analyze-file';
import { handleCreateCheckoutSession } from './routes/create-checkout-session';
import { handleGetTransactions } from './routes/get-transactions';
import { handleGetConversations } from './routes/get-conversations';
import { handleGetFinancialMetrics } from './routes/get-financial-metrics';
import { handleGetXPStats } from './routes/get-xp-stats';
import { handleGetTargets } from './routes/get-targets';
import { handleGetAssets } from './routes/get-assets';
import { handleCreateConversation } from './routes/create-conversation';
import { handleGetMessages } from './routes/get-messages';
import { handleSaveMessage } from './routes/save-message';
import { applySecurityHeaders } from './utils/securityHeaders';
import { requestIdMiddleware } from './middleware/requestId';
import * as logger from './utils/logger';

// Load environment variables
// Use explicit path to ensure .env is loaded from project root
import path from 'path';
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

// #region agent log
const debugSupabaseUrl = process.env.SUPABASE_URL;
const debugSupabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
fetch('http://127.0.0.1:7242/ingest/60703aac-129d-4ef4-8e2a-73410ca29b0a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'index.ts:27',message:'dotenv.config() called - checking loaded env vars',data:{hasUrl:!!debugSupabaseUrl,urlLength:debugSupabaseUrl?.length||0,urlPreview:debugSupabaseUrl?.substring(0,50)||'null',hasServiceKey:!!debugSupabaseServiceKey,serviceKeyLength:debugSupabaseServiceKey?.length||0,serviceKeyPreview:debugSupabaseServiceKey?.substring(0,30)||'null',serviceKeyIsPlaceholder:debugSupabaseServiceKey?.includes('YOUR_')||debugSupabaseServiceKey?.includes('your_')||false},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'D'})}).catch(()=>{});
// #endregion

const app = express();
const PORT = process.env.PORT || 3001;

// Trust proxy for accurate IP addresses
app.set('trust proxy', true);

// CORS configuration for iOS app
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim())
  : ['*']; // Allow all origins in development

const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin || allowedOrigins.includes('*')) {
      callback(null, true);
    } else if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-Request-ID'],
  exposedHeaders: ['X-Request-ID'],
};

app.use(cors(corsOptions));

// Request ID middleware (must be early in the chain)
app.use(requestIdMiddleware);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Security headers middleware (applied to all routes)
app.use((_req, res, next) => {
  applySecurityHeaders(res);
  next();
});

// Health check endpoint (required for App Store)
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'ANITA Backend API',
    version: '1.0.0'
  });
});

// Privacy policy endpoint (required for App Store)
app.get('/privacy', (_req: Request, res: Response) => {
  res.status(200).json({
    privacyPolicy: 'https://anita.app/privacy',
    dataCollection: 'We collect minimal data necessary for app functionality.',
    dataUsage: 'Data is used solely for providing financial advisory services.',
    dataSharing: 'We do not sell or share your data with third parties.',
    contact: 'privacy@anita.app'
  });
});

// API Routes with versioning (v1)
// This allows us to change logic in the future without breaking old iOS clients
app.post('/api/v1/chat-completion', handleChatCompletion);
app.post('/api/v1/transcribe', handleTranscribe);
app.post('/api/v1/analyze-file', handleAnalyzeFile);
app.post('/api/v1/create-checkout-session', handleCreateCheckoutSession);
app.get('/api/v1/transactions', handleGetTransactions);
app.get('/api/v1/conversations', handleGetConversations);
app.post('/api/v1/create-conversation', handleCreateConversation);
app.get('/api/v1/messages', handleGetMessages);
app.post('/api/v1/save-message', handleSaveMessage);
app.get('/api/v1/financial-metrics', handleGetFinancialMetrics);
app.get('/api/v1/xp-stats', handleGetXPStats);
app.get('/api/v1/targets', handleGetTargets);
app.get('/api/v1/assets', handleGetAssets);

// Legacy routes (redirect to v1 for backward compatibility)
app.post('/api/chat-completion', handleChatCompletion);
app.post('/api/transcribe', handleTranscribe);
app.post('/api/analyze-file', handleAnalyzeFile);
app.post('/api/create-checkout-session', handleCreateCheckoutSession);

// OPTIONS requests are handled by CORS middleware automatically

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Error handler
app.use((err: Error, req: Request, res: Response, _next: express.NextFunction) => {
  logger.error('Unhandled error', { 
    error: err.message, 
    stack: err.stack,
    path: req.path,
    method: req.method,
    requestId: req.requestId
  });
  
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'production' 
      ? 'An unexpected error occurred' 
      : err.message,
    requestId: req.requestId
  });
});

// Start server
app.listen(PORT, () => {
  logger.info('ANITA Backend Server started', {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version
  });
  
  console.log('\n🚀 ANITA Backend API Server');
  console.log(`   Running on http://localhost:${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log('\n   API Endpoints (v1):');
  console.log('   - POST /api/v1/chat-completion');
  console.log('   - POST /api/v1/transcribe');
  console.log('   - POST /api/v1/analyze-file');
  console.log('   - POST /api/v1/create-checkout-session');
  console.log('   - GET  /api/v1/transactions');
  console.log('   - GET  /api/v1/conversations');
  console.log('   - POST /api/v1/create-conversation');
  console.log('   - GET  /api/v1/messages');
  console.log('   - POST /api/v1/save-message');
  console.log('   - GET  /api/v1/financial-metrics');
  console.log('   - GET  /api/v1/xp-stats');
  console.log('   - GET  /api/v1/targets');
  console.log('   - GET  /api/v1/assets');
  console.log('   - GET  /health');
  console.log('   - GET  /privacy');
  console.log('\n   ✅ Ready for iOS app!\n');
  
  // Check environment variables
  const requiredEnvVars = [
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'OPENAI_API_KEY',
    'STRIPE_SECRET_KEY',
  ];
  
  const missing = requiredEnvVars.filter(
    key => !process.env[key] || process.env[key] === 'your_' + key.toLowerCase() + '_here'
  );
  
  if (missing.length > 0) {
    console.log('   ⚠️  Missing or placeholder environment variables:');
    missing.forEach(key => console.log(`      - ${key}`));
    console.log('   Add them to .env file\n');
  } else {
    console.log('   ✅ All required environment variables are set\n');
  }
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

