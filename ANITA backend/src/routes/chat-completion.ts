/**
 * Chat Completion API Route
 * Handles chat requests with OpenAI GPT
 */

import { Request, Response } from 'express';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeChatMessage } from '../utils/sanitizeInput';
import { fetchWithTimeout, TIMEOUTS } from '../utils/timeout';
import * as logger from '../utils/logger';

const openaiApiKey = process.env.OPENAI_API_KEY;
const openaiModel = process.env.OPENAI_MODEL || 'gpt-4o-mini';

export async function handleChatCompletion(req: Request, res: Response): Promise<void> {
  // Apply security headers
  applySecurityHeaders(res);

  // Handle OPTIONS preflight
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ 
      error: 'Method not allowed',
      message: `Method ${req.method} is not allowed. Use POST.`
    });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    
    // Validate API key
    if (!openaiApiKey) {
      logger.error('OpenAI API key not configured', { requestId });
      res.status(500).json({ 
        error: 'OpenAI API key not configured',
        message: 'Please set OPENAI_API_KEY environment variable',
        requestId
      });
      return;
    }

    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        res.status(400).json({ 
          error: 'Invalid JSON in request body',
          message: 'Failed to parse request body as JSON'
        });
        return;
      }
    }

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.CHAT_COMPLETION, 'chat-completion');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'chat-completion', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    const { messages, maxTokens = 800, temperature = 0.7 } = body;

    // Validate messages array
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ 
        error: 'Invalid messages array',
        message: 'messages must be a non-empty array'
      });
      return;
    }

    // Validate and sanitize message structure
    const sanitizedMessages = [];
    for (const msg of messages) {
      if (!msg || typeof msg !== 'object' || !msg.role || !msg.content) {
        res.status(400).json({ 
          error: 'Invalid message format',
          message: 'Each message must have "role" and "content" fields'
        });
        return;
      }
      
      // Sanitize content
      sanitizedMessages.push({
        role: msg.role,
        content: sanitizeChatMessage(msg.content)
      });
    }

    // Call OpenAI API with timeout (prevents hanging requests)
    logger.info('Calling OpenAI API', { requestId, messageCount: sanitizedMessages.length });
    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: openaiModel,
          messages: sanitizedMessages,
          max_tokens: maxTokens,
          temperature,
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );

    if (!response.ok) {
      const errorData = (await response.json().catch(() => ({}))) as { error?: { message?: string } };
      logger.error('OpenAI API request failed', { 
        status: response.status, 
        error: errorData.error?.message,
        requestId 
      });
      res.status(500).json({ 
        error: 'OpenAI API request failed',
        message: errorData.error?.message || `OpenAI API returned status ${response.status}`,
        requestId
      });
      return;
    }

    const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const aiResponse = data.choices?.[0]?.message?.content;

    if (!aiResponse) {
      logger.error('No response from OpenAI', { requestId });
      res.status(500).json({ 
        error: 'No response from OpenAI',
        message: 'The API response did not contain a valid message',
        requestId
      });
      return;
    }

    logger.info('Chat completion successful', { requestId });
    res.status(200).json({ 
      response: aiResponse,
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    const errorMessage = error instanceof Error ? error.message : 'Unknown';
    
    // Check if it's a timeout error
    if (errorMessage.includes('timeout')) {
      logger.error('Request timeout in chat completion', { error: errorMessage, requestId });
      res.status(504).json({ 
        error: 'Request timeout',
        message: 'The AI request took too long. Please try again.',
        requestId
      });
      return;
    }
    
    logger.error('Unexpected error in chat completion', { error: errorMessage, requestId });
    res.status(500).json({ 
      error: 'Internal server error',
      message: errorMessage,
      requestId
    });
  }
}

