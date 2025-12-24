/**
 * Request ID Middleware
 * Generates and tracks request IDs for better logging and debugging
 */

import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';

// Extend Express Request type to include requestId
declare global {
  namespace Express {
    interface Request {
      requestId?: string;
    }
  }
}

/**
 * Middleware to generate and attach request ID
 * Adds x-request-id header to response
 */
export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Generate or use existing request ID from header
  const requestId = (req.headers['x-request-id'] as string) || randomUUID();
  
  // Attach to request object
  req.requestId = requestId;
  
  // Add to response headers
  res.setHeader('X-Request-ID', requestId);
  
  next();
}

