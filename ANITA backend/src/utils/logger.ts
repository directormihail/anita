/**
 * Logger Utility
 * Server-side only logging for security events
 * Does NOT log sensitive data
 */

type LogLevel = 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  context?: Record<string, unknown>;
}

/**
 * Sanitize log context to remove sensitive data
 */
function sanitizeContext(context?: Record<string, unknown>): Record<string, unknown> | undefined {
  if (!context) return undefined;

  const sensitiveKeys = [
    'password',
    'token',
    'apiKey',
    'api_key',
    'secret',
    'authorization',
    'auth',
    'creditCard',
    'credit_card',
    'ssn',
    'email',
    'phone'
  ];

  const sanitized: Record<string, unknown> = {};
  
  Object.entries(context).forEach(([key, value]) => {
    const lowerKey = key.toLowerCase();
    
    // Skip sensitive keys
    if (sensitiveKeys.some(sk => lowerKey.includes(sk))) {
      sanitized[key] = '[REDACTED]';
      return;
    }
    
    // If value is an object, sanitize recursively
    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      sanitized[key] = sanitizeContext(value as Record<string, unknown>);
    } else if (typeof value === 'string' && value.length > 200) {
      // Truncate long strings
      sanitized[key] = value.substring(0, 200) + '...';
    } else {
      sanitized[key] = value;
    }
  });
  
  return sanitized;
}

/**
 * Format log entry
 */
function formatLog(entry: LogEntry): string {
  const timestamp = entry.timestamp;
  const level = entry.level.toUpperCase().padEnd(5);
  const message = entry.message;
  const requestId = entry.context?.requestId ? `[${entry.context.requestId}]` : '';
  const contextWithoutRequestId = entry.context ? { ...entry.context } : {};
  if (contextWithoutRequestId.requestId) {
    delete contextWithoutRequestId.requestId;
  }
  const contextStr = Object.keys(contextWithoutRequestId).length > 0 
    ? ` ${JSON.stringify(sanitizeContext(contextWithoutRequestId))}` 
    : '';
  
  return `[${timestamp}] ${level} ${requestId} ${message}${contextStr}`;
}

/**
 * Log info message
 */
export function info(message: string, context?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level: 'info',
    message,
    timestamp: new Date().toISOString(),
    context
  };

  console.log(formatLog(entry));
}

/**
 * Log warning message
 */
export function warn(message: string, context?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level: 'warn',
    message,
    timestamp: new Date().toISOString(),
    context
  };

  console.warn(formatLog(entry));
}

/**
 * Log debug message
 */
export function debug(message: string, context?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level: 'info',
    message,
    timestamp: new Date().toISOString(),
    context
  };
  console.log(formatLog(entry));
}

/**
 * Log error message
 */
export function error(message: string, context?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level: 'error',
    message,
    timestamp: new Date().toISOString(),
    context
  };

  console.error(formatLog(entry));
}

