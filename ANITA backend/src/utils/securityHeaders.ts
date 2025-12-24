/**
 * Security Headers Utility
 * Adds security headers to API responses
 */

export interface SecurityHeaders {
  'X-Content-Type-Options': string;
  'X-Frame-Options': string;
  'Referrer-Policy': string;
  'Permissions-Policy': string;
}

/**
 * Get default security headers
 * These headers prevent common security vulnerabilities
 */
export function getSecurityHeaders(): SecurityHeaders {
  return {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'microphone=(), camera=(), geolocation=()'
  };
}

/**
 * Apply security headers to response
 * Merges with existing headers without overwriting
 */
export function applySecurityHeaders(res: any, additionalHeaders?: Record<string, string>): void {
  const securityHeaders = getSecurityHeaders();
  
  // Apply security headers
  Object.entries(securityHeaders).forEach(([key, value]) => {
    try {
      if (!res.getHeader?.(key.toLowerCase()) && !res.headers?.[key.toLowerCase()]) {
        res.setHeader(key, value);
      }
    } catch (e) {
      // If setHeader fails, try alternative method
      try {
        res.setHeader(key, value);
      } catch (err) {
        // Ignore header setting errors
      }
    }
  });
  
  // Apply any additional headers
  if (additionalHeaders) {
    Object.entries(additionalHeaders).forEach(([key, value]) => {
      try {
        if (!res.getHeader?.(key.toLowerCase()) && !res.headers?.[key.toLowerCase()]) {
          res.setHeader(key, value);
        }
      } catch (e) {
        // Ignore header setting errors
      }
    });
  }
}

