/**
 * Transcription API Route
 * Transcribes voice messages using OpenAI Whisper
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeInput } from '../utils/sanitizeInput';
import { fetchWithTimeout, TIMEOUTS } from '../utils/timeout';
import * as logger from '../utils/logger';

// Lazy-load environment variables to ensure they're loaded after dotenv.config()
function getOpenAIConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini'
  };
}

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

/**
 * Validate transcription request
 */
function validateTranscribeRequest(body: any): { valid: boolean; error?: string; data?: { audioFileUrl: string; conversationId: string; userId: string } } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be an object' };
  }

  if (!body.audioFileUrl || typeof body.audioFileUrl !== 'string' || body.audioFileUrl.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid audioFileUrl' };
  }

  // Validate URL format
  try {
    new URL(body.audioFileUrl);
  } catch {
    return { valid: false, error: 'audioFileUrl must be a valid URL' };
  }

  if (body.audioFileUrl.length > 2048) {
    return { valid: false, error: 'audioFileUrl is too long' };
  }

  if (!body.conversationId || typeof body.conversationId !== 'string' || body.conversationId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid conversationId' };
  }

  if (body.conversationId.length > 200) {
    return { valid: false, error: 'conversationId is too long' };
  }

  if (!body.userId || typeof body.userId !== 'string' || body.userId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid userId' };
  }

  if (body.userId.length > 200) {
    return { valid: false, error: 'userId is too long' };
  }

  return {
    valid: true,
    data: {
      audioFileUrl: body.audioFileUrl.trim(),
      conversationId: body.conversationId.trim(),
      userId: body.userId.trim()
    }
  };
}

export async function handleTranscribe(req: Request, res: Response): Promise<void> {
  // Apply security headers
  applySecurityHeaders(res);

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    
    // Get configs (lazy-loaded to ensure env vars are available)
    const openaiConfig = getOpenAIConfig();
    const openaiApiKey = openaiConfig.apiKey;
    const supabase = getSupabaseClient();
    
    // Validate API keys
    if (!openaiApiKey) {
      logger.error('OpenAI API key not configured', { requestId });
      res.status(500).json({ error: 'OpenAI API key not configured', requestId });
      return;
    }

    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Supabase not configured', requestId });
      return;
    }

    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        res.status(400).json({ error: 'Invalid JSON in request body' });
        return;
      }
    }

    // Sanitize input first
    if (body && typeof body === 'object') {
      if (body.audioFileUrl && typeof body.audioFileUrl === 'string') {
        body.audioFileUrl = sanitizeInput(body.audioFileUrl, 2048);
      }
      if (body.conversationId && typeof body.conversationId === 'string') {
        body.conversationId = sanitizeInput(body.conversationId, 200);
      }
      if (body.userId && typeof body.userId === 'string') {
        body.userId = sanitizeInput(body.userId, 200);
      }
    }

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.TRANSCRIPTION, 'transcribe');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'transcribe', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    // Validate input
    const validation = validateTranscribeRequest(body);
    if (!validation.valid) {
      logger.warn('Validation error', { error: validation.error, requestId });
      res.status(400).json({ error: validation.error, requestId });
      return;
    }

    const { audioFileUrl, conversationId, userId } = validation.data!;

    // Download the audio file from Supabase
    const response = await fetch(audioFileUrl);
    if (!response.ok) {
      throw new Error(`Failed to download audio file: ${response.statusText}`);
    }

    const audioBlob = await response.blob();
    const formData = new FormData();
    formData.append('file', audioBlob, 'audio.webm');
    formData.append('model', 'whisper-1');
    formData.append('language', 'en');

    // Transcribe with OpenAI Whisper (with timeout)
    logger.info('Calling Whisper API', { requestId });
    const whisperResponse = await fetchWithTimeout(
      'https://api.openai.com/v1/audio/transcriptions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`,
        },
        body: formData,
      },
      TIMEOUTS.TRANSCRIPTION
    );

    if (!whisperResponse.ok) {
      const errorData = (await whisperResponse.json().catch(() => ({ error: { message: 'Unknown error' } }))) as { error?: { message?: string } };
      logger.error('Whisper API error', { 
        status: whisperResponse.status, 
        error: errorData.error?.message,
        requestId 
      });
      throw new Error(`Whisper API error: ${errorData.error?.message || 'Unknown error'}`);
    }

    const whisperData = (await whisperResponse.json()) as { text?: string };
    const transcript = whisperData.text;

    if (!transcript) {
      throw new Error('No transcript from Whisper API');
    }

    // Get conversation history
    const { data: messages, error: messagesError } = await supabase
      .from('anita_data')
      .select('*')
      .eq('conversation_id', conversationId)
      .eq('data_type', 'message')
      .order('created_at', { ascending: true });

    if (messagesError) {
      logger.error('Failed to get conversation history', { error: messagesError.message });
      throw new Error(`Failed to get conversation history: ${messagesError.message}`);
    }

    // Prepare conversation context for GPT
    const conversationHistory = messages || [];
    const messages_for_gpt = [
      {
        role: 'system',
        content: `You are ANITA, a helpful and friendly personal finance AI assistant. You help users track their income and expenses, create financial goals, and provide financial advice. Be conversational, supportive, and use emojis appropriately. Keep responses concise but helpful.`
      },
      ...conversationHistory.map((msg: any) => ({
        role: msg.sender === 'user' ? 'user' : 'assistant',
        content: msg.text || msg.message_text
      })),
      {
        role: 'user',
        content: transcript
      }
    ];

    // Get AI response from GPT (with timeout)
    logger.info('Calling GPT for response', { requestId });
    const gptResponse = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: openaiConfig.model,
          messages: messages_for_gpt,
          max_tokens: 500,
          temperature: 0.7,
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );

    if (!gptResponse.ok) {
      const errorData = (await gptResponse.json().catch(() => ({ error: { message: 'Unknown error' } }))) as { error?: { message?: string } };
      logger.error('GPT API error', { 
        status: gptResponse.status, 
        error: errorData.error?.message,
        requestId 
      });
      throw new Error(`GPT API error: ${errorData.error?.message || 'Unknown error'}`);
    }

    const gptData = (await gptResponse.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const aiResponse = gptData.choices?.[0]?.message?.content;

    if (!aiResponse) {
      throw new Error('No response from GPT API');
    }

    // Save to conversations table
    const { error: saveError } = await supabase
      .from('conversations')
      .update({
        audio_file: audioFileUrl,
        transcription: transcript,
        ai_response: aiResponse,
        updated_at: new Date().toISOString()
      })
      .eq('id', conversationId)
      .eq('user_id', userId);

    if (saveError) {
      logger.error('Failed to save voice message data', { error: saveError.message });
      throw new Error(`Failed to save voice message data: ${saveError.message}`);
    }

    logger.info('Transcription successful', { conversationId, requestId });
    res.status(200).json({
      success: true,
      transcript,
      aiResponse,
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    const errorMessage = error instanceof Error ? error.message : 'Unknown';
    
    // Check if it's a timeout error
    if (errorMessage.includes('timeout')) {
      logger.error('Request timeout in transcription', { error: errorMessage, requestId });
      res.status(504).json({
        success: false,
        error: 'Request timeout',
        message: 'The transcription request took too long. Please try again.',
        requestId
      });
      return;
    }
    
    logger.error('Unexpected error in transcription', { error: errorMessage, requestId });
    res.status(500).json({
      success: false,
      error: errorMessage,
      requestId
    });
  }
}

