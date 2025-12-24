/**
 * Input Sanitization Utility
 * Prevents XSS, removes dangerous content, and enforces length limits
 */

/**
 * Sanitize user input
 * - Trims whitespace
 * - Removes HTML tags
 * - Removes invisible Unicode characters
 * - Removes potential XSS payloads
 * - Enforces max length
 */
export function sanitizeInput(
  input: string | null | undefined,
  maxLength?: number
): string {
  if (!input || typeof input !== 'string') {
    return '';
  }

  let sanitized = input
    // Trim whitespace
    .trim()
    // Remove HTML tags
    .replace(/<[^>]*>/g, '')
    // Remove script tags (case insensitive, multiline)
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    // Remove javascript: protocol
    .replace(/javascript:/gi, '')
    // Remove data: protocol (can be used for XSS)
    .replace(/data:/gi, '')
    // Remove vbscript: protocol
    .replace(/vbscript:/gi, '')
    // Remove on* event handlers (onclick, onerror, etc.)
    .replace(/on\w+\s*=/gi, '')
    // Remove invisible Unicode characters (zero-width spaces, etc.)
    .replace(/[\u200B-\u200D\uFEFF\u00AD]/g, '')
    // Remove control characters except newlines and tabs
    .replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '')
    // Remove potential XSS payloads
    .replace(/&lt;script/gi, '')
    .replace(/&lt;iframe/gi, '')
    .replace(/&lt;object/gi, '')
    .replace(/&lt;embed/gi, '')
    .replace(/&lt;link/gi, '')
    .replace(/&lt;meta/gi, '')
    // Normalize whitespace (multiple spaces to single space)
    .replace(/\s+/g, ' ')
    // Trim again after processing
    .trim();

  // Apply max length if specified
  if (maxLength && sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength);
  }

  return sanitized;
}

/**
 * Sanitize text for chat messages
 * More permissive but still safe - only removes XSS vectors, preserves content
 */
export function sanitizeChatMessage(input: string | null | undefined): string {
  if (!input || typeof input !== 'string') {
    return '';
  }

  // Light sanitization for chat messages - only remove dangerous XSS vectors
  let sanitized = input
    // Remove script tags (case insensitive, multiline)
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    // Remove javascript: protocol
    .replace(/javascript:/gi, '')
    // Remove data: protocol URLs (can be used for XSS)
    .replace(/data:(?!image\/[png|jpg|jpeg|gif|webp];base64,)/gi, '')
    // Remove vbscript: protocol
    .replace(/vbscript:/gi, '')
    // Remove on* event handlers (onclick, onerror, etc.)
    .replace(/on\w+\s*=/gi, '')
    // Remove invisible Unicode characters (zero-width spaces, etc.)
    .replace(/[\u200B-\u200D\uFEFF\u00AD]/g, '')
    // Remove control characters except newlines and tabs
    .replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '')
    // Trim whitespace
    .trim();

  // Apply max length if specified
  const maxLength = 50000;
  if (sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength);
  }

  return sanitized;
}

/**
 * Sanitize text for file analysis
 */
export function sanitizeFileContent(input: string | null | undefined): string {
  return sanitizeInput(input, 10 * 1024 * 1024); // Max 10MB
}

/**
 * Sanitize title/name fields
 */
export function sanitizeTitle(input: string | null | undefined): string {
  return sanitizeInput(input, 200); // Max 200 chars for titles
}

