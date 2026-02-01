/**
 * ANITA Backend Server
 * TypeScript Express server for iOS app
 */

// Load environment variables FIRST, before any other imports
// This ensures all modules can access process.env values
import dotenv from 'dotenv';
import path from 'path';
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

// Now import everything else after env vars are loaded
import express, { Request, Response } from 'express';
import cors from 'cors';
import { handleChatCompletion } from './routes/chat-completion';
import { handleTranscribe } from './routes/transcribe';
import { handleAnalyzeFile } from './routes/analyze-file';
import { handleCreateCheckoutSession } from './routes/create-checkout-session';
import { handleGetTransactions } from './routes/get-transactions';
import { handleGetConversations } from './routes/get-conversations';
import { handleGetFinancialMetrics } from './routes/get-financial-metrics';
import { handleGetXPStats } from './routes/get-xp-stats';
import { handleGetTargets } from './routes/get-targets';
import { handleCreateTarget } from './routes/create-target';
import { handleUpdateTarget } from './routes/update-target';
import { handleDeleteTarget } from './routes/delete-target';
import { handleGetAssets } from './routes/get-assets';
import { handleCreateAsset } from './routes/create-asset';
import { handleUpdateAsset } from './routes/update-asset';
import { handleDeleteAsset } from './routes/delete-asset';
import { handleCreateConversation } from './routes/create-conversation';
import { handleGetMessages } from './routes/get-messages';
import { handleSaveMessage } from './routes/save-message';
import { handleSaveMessageFeedback } from './routes/save-message-feedback';
import { handleSaveTransaction } from './routes/save-transaction';
import { handleUpdateTransaction } from './routes/update-transaction';
import { handleDeleteTransaction } from './routes/delete-transaction';
import { handleVerifyIOSSubscription } from './routes/verify-ios-subscription';
import { handleGetSubscription } from './routes/get-subscription';
import { applySecurityHeaders } from './utils/securityHeaders';
import { requestIdMiddleware } from './middleware/requestId';
import * as logger from './utils/logger';

// #region agent log
const debugSupabaseUrl = process.env.SUPABASE_URL;
const debugSupabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
fetch('http://127.0.0.1:7242/ingest/60703aac-129d-4ef4-8e2a-73410ca29b0a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'index.ts:27',message:'dotenv.config() called - checking loaded env vars',data:{hasUrl:!!debugSupabaseUrl,urlLength:debugSupabaseUrl?.length||0,urlPreview:debugSupabaseUrl?.substring(0,50)||'null',hasServiceKey:!!debugSupabaseServiceKey,serviceKeyLength:debugSupabaseServiceKey?.length||0,serviceKeyPreview:debugSupabaseServiceKey?.substring(0,30)||'null',serviceKeyIsPlaceholder:debugSupabaseServiceKey?.includes('YOUR_')||debugSupabaseServiceKey?.includes('your_')||false},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'D'})}).catch(()=>{});
// #endregion

const app = express();
const PORT = Number(process.env.PORT) || 3001;

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
app.post('/api/v1/verify-ios-subscription', handleVerifyIOSSubscription);
app.get('/api/v1/subscription', handleGetSubscription);
app.get('/api/v1/transactions', handleGetTransactions);
app.get('/api/v1/conversations', handleGetConversations);
app.post('/api/v1/create-conversation', handleCreateConversation);
app.get('/api/v1/messages', handleGetMessages);
app.post('/api/v1/save-message', handleSaveMessage);
app.post('/api/v1/save-message-feedback', handleSaveMessageFeedback);
app.post('/api/v1/save-transaction', handleSaveTransaction);
app.post('/api/v1/update-transaction', handleUpdateTransaction);
app.post('/api/v1/delete-transaction', handleDeleteTransaction);
app.get('/api/v1/financial-metrics', handleGetFinancialMetrics);
app.get('/api/v1/xp-stats', handleGetXPStats);
app.get('/api/v1/targets', handleGetTargets);
app.post('/api/v1/create-target', handleCreateTarget);
app.post('/api/v1/update-target', handleUpdateTarget);
app.post('/api/v1/delete-target', handleDeleteTarget);
app.get('/api/v1/assets', handleGetAssets);
app.post('/api/v1/assets', handleCreateAsset);
app.post('/api/v1/update-asset', handleUpdateAsset);
app.post('/api/v1/delete-asset', handleDeleteAsset);

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
// Listen on 0.0.0.0 to allow connections from other devices on the network (e.g., iPhone)
app.listen(PORT, '0.0.0.0', () => {
  logger.info('ANITA Backend Server started', {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version
  });
  
  console.log('\n🚀 ANITA Backend API Server');
  console.log(`   Running on http://localhost:${PORT}`);
  console.log(`   Accessible from network: http://0.0.0.0:${PORT}`);
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log('\n   API Endpoints (v1):');
  console.log('   - POST /api/v1/chat-completion');
  console.log('   - POST /api/v1/transcribe');
  console.log('   - POST /api/v1/analyze-file');
  console.log('   - POST /api/v1/create-checkout-session');
  console.log('   - POST /api/v1/verify-ios-subscription');
  console.log('   - GET  /api/v1/subscription');
  console.log('   - GET  /api/v1/transactions');
  console.log('   - GET  /api/v1/conversations');
  console.log('   - POST /api/v1/create-conversation');
  console.log('   - GET  /api/v1/messages');
  console.log('   - POST /api/v1/save-message');
  console.log('   - POST /api/v1/save-message-feedback');
  console.log('   - POST /api/v1/save-transaction');
  console.log('   - POST /api/v1/update-transaction');
  console.log('   - POST /api/v1/delete-transaction');
  console.log('   - GET  /api/v1/financial-metrics');
  console.log('   - GET  /api/v1/xp-stats');
  console.log('   - GET  /api/v1/targets');
  console.log('   - POST /api/v1/create-target');
  console.log('   - POST /api/v1/update-target');
  console.log('   - POST /api/v1/delete-target');
  console.log('   - GET  /api/v1/assets');
  console.log('   - POST /api/v1/assets');
  console.log('   - POST /api/v1/update-asset');
  console.log('   - POST /api/v1/delete-asset');
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

