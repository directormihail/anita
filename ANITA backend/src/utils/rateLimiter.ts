/**
 * Rate Limiter Utility
 * Prevents API spamming with token bucket algorithm
 * Uses in-memory storage for local dev, can be upgraded to Redis/Upstash for production
 */

interface RateLimitConfig {
  maxRequests: number;
  windowMs: number; // Time window in milliseconds
}

interface RateLimitStore {
  [key: string]: {
    count: number;
    resetTime: number;
  };
}

// In-memory store (for local dev and single-instance deployments)
// For production with multiple instances, use Redis/Upstash
const rateLimitStore: RateLimitStore = {};

// Clean up old entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  Object.keys(rateLimitStore).forEach(key => {
    if (rateLimitStore[key].resetTime < now) {
      delete rateLimitStore[key];
    }
  });
}, 5 * 60 * 1000);

/**
 * Get client identifier from request
 * Uses IP address or user ID if available
 */
function getClientId(req: any): string {
  // Try to get user ID first (more accurate for authenticated users)
  if (req.body?.userId) {
    return `user:${req.body.userId}`;
  }
  
  // Fallback to IP address
  const forwarded = req.headers?.['x-forwarded-for'];
  const ip = forwarded 
    ? (Array.isArray(forwarded) ? forwarded[0] : forwarded.split(',')[0].trim())
    : req.headers?.['x-real-ip'] 
    || req.ip
    || req.connection?.remoteAddress 
    || req.socket?.remoteAddress
    || 'unknown';
  
  return `ip:${ip}`;
}

/**
 * Check if request is within rate limit
 * Returns { allowed: boolean, remaining: number, resetTime: number }
 * @param routePrefix - Unique prefix for each route to prevent key conflicts
 */
export function checkRateLimit(
  req: any,
  config: RateLimitConfig,
  routePrefix: string = 'default'
): { allowed: boolean; remaining: number; resetTime: number; retryAfter?: number } {
  const clientId = getClientId(req);
  const now = Date.now();
  // Include route prefix to ensure each route has separate rate limit tracking
  const key = `${routePrefix}:${clientId}:${config.windowMs}`;
  
  let entry = rateLimitStore[key];
  
  // Initialize or reset if window expired
  if (!entry || entry.resetTime < now) {
    entry = {
      count: 0,
      resetTime: now + config.windowMs
    };
    rateLimitStore[key] = entry;
  }
  
  // Check if limit exceeded
  if (entry.count >= config.maxRequests) {
    const retryAfter = Math.ceil((entry.resetTime - now) / 1000);
    return {
      allowed: false,
      remaining: 0,
      resetTime: entry.resetTime,
      retryAfter
    };
  }
  
  // Increment counter
  entry.count++;
  
  return {
    allowed: true,
    remaining: config.maxRequests - entry.count,
    resetTime: entry.resetTime
  };
}

/**
 * Rate limit configurations for different endpoints
 */
export const RATE_LIMITS = {
  CHAT_COMPLETION: { maxRequests: 20, windowMs: 60 * 1000 }, // 20 per minute
  FILE_ANALYSIS: { maxRequests: 10, windowMs: 60 * 1000 }, // 10 per minute
  TRANSCRIPTION: { maxRequests: 5, windowMs: 60 * 1000 }, // 5 per minute
  CHECKOUT: { maxRequests: 10, windowMs: 60 * 1000 }, // 10 per minute
} as const;

/**
 * Middleware function for rate limiting
 * Use in API routes: const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.CHAT_COMPLETION, 'chat-completion');
 * @param routePrefix - Unique prefix for each route to prevent key conflicts
 */
export function rateLimitMiddleware(
  req: any,
  config: RateLimitConfig,
  routePrefix: string = 'default'
): { allowed: boolean; response?: { status: number; body: any } } {
  const result = checkRateLimit(req, config, routePrefix);
  
  if (!result.allowed) {
    return {
      allowed: false,
      response: {
        status: 429,
        body: {
          error: 'Rate limit exceeded',
          message: `Too many requests. Please try again in ${result.retryAfter} seconds.`,
          retryAfter: result.retryAfter
        }
      }
    };
  }
  
  return { allowed: true };
}

