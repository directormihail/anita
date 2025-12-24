/**
 * Timeout Utility
 * Creates fetch requests with timeout for AI API calls
 * Prevents hanging requests that Apple doesn't like
 */

/**
 * Fetch with timeout
 * @param url - URL to fetch
 * @param options - Fetch options
 * @param timeoutMs - Timeout in milliseconds (default: 30000 = 30 seconds)
 * @returns Promise<Response>
 */
export async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs: number = 30000
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timeout after ${timeoutMs}ms`);
    }
    throw error;
  }
}

/**
 * Timeout configurations for different endpoints
 */
export const TIMEOUTS = {
  CHAT_COMPLETION: 30000, // 30 seconds for chat
  TRANSCRIPTION: 60000,   // 60 seconds for audio transcription
  FILE_ANALYSIS: 45000,   // 45 seconds for file analysis
  DEFAULT: 30000,         // 30 seconds default
} as const;

