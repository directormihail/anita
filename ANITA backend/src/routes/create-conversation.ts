/**
 * Create Conversation API Route
 * Creates a new conversation in Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  // Validate values before creating client - check for placeholders
  const isUrlValid = supabaseUrl && supabaseUrl.trim() !== '' && !supabaseUrl.includes('YOUR_') && !supabaseUrl.includes('your_') && !supabaseUrl.includes('placeholder');
  const isServiceKeyValid = supabaseServiceKey && supabaseServiceKey.trim() !== '' && !supabaseServiceKey.includes('YOUR_') && !supabaseServiceKey.includes('your_') && !supabaseServiceKey.includes('placeholder');
  
  if (isUrlValid && isServiceKeyValid) {
    return createClient(supabaseUrl!, supabaseServiceKey!);
  }
  return null;
}

export async function handleCreateConversation(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

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

    const { userId, title = 'New Chat' } = body;

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId is required in request body',
        requestId
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      const missingVars = [];
      
      // Check URL - only flag if actually missing or placeholder
      if (!isUrlValid) {
        missingVars.push('SUPABASE_URL');
      }
      
      // Check Service Key - only flag if actually missing or placeholder
      if (!isServiceKeyValid) {
        missingVars.push('SUPABASE_SERVICE_ROLE_KEY');
      }
      
      // #region agent log
      fetch('http://127.0.0.1:7242/ingest/60703aac-129d-4ef4-8e2a-73410ca29b0a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'create-conversation.ts:74-88',message:'Supabase configuration check failed',data:{supabaseIsNull:!supabase,isUrlValid,isServiceKeyValid,urlValue:supabaseUrl?.substring(0,60)||'null',serviceKeyValue:supabaseServiceKey?.substring(0,60)||'null',missingVars},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'C'})}).catch(()=>{});
      // #endregion
      
      logger.error('Supabase not configured', { requestId, missingVars });
      
      // Provide specific error message based on what's missing
      let errorMessage = 'Supabase is incorrectly configured.';
      if (missingVars.length > 0) {
        errorMessage += ` Missing or placeholder values for: ${missingVars.join(', ')}.`;
        if (missingVars.includes('SUPABASE_SERVICE_ROLE_KEY')) {
          errorMessage += ' Please set SUPABASE_SERVICE_ROLE_KEY in your backend .env file. See GET_SERVICE_ROLE_KEY.md for instructions.';
        }
      } else {
        errorMessage += ' Both SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.';
      }
      
      res.status(500).json({
        error: 'Database not configured',
        message: errorMessage,
        requestId,
        help: 'Get your service role key from: Supabase Dashboard → Settings → API → service_role key'
      });
      return;
    }

    // Check if user exists in auth.users before creating conversation
    // This prevents foreign key constraint violations
    try {
      const { data: userData, error: userError } = await supabase.auth.admin.getUserById(userId);
      
      if (userError || !userData?.user) {
        logger.error('User not found in auth.users', { 
          error: userError?.message, 
          requestId, 
          userId 
        });
        
        res.status(400).json({
          error: 'User not found',
          message: `User with ID ${userId} does not exist. Please sign in or sign up first.`,
          requestId,
          hint: 'The user must be authenticated in Supabase before creating conversations.'
        });
        return;
      }
    } catch (adminError) {
      // If admin API is not available, log and continue - the foreign key error will be caught below
      logger.warn('Could not verify user existence via admin API', { 
        error: adminError instanceof Error ? adminError.message : 'Unknown error',
        requestId, 
        userId 
      });
      // Continue to attempt conversation creation - if user doesn't exist, foreign key error will be caught
    }

    // Create conversation
    const { data, error } = await supabase
      .from('conversations')
      .insert([{
        user_id: userId,
        title: title
      }])
      .select()
      .single();

    if (error) {
      logger.error('Error creating conversation', { 
        error: error.message, 
        errorCode: error.code,
        errorDetails: error.details,
        errorHint: error.hint,
        requestId, 
        userId 
      });
      
      // Check for foreign key constraint violation
      let errorMessage = `Failed to create conversation: ${error.message}`;
      if (error.message && error.message.includes('foreign key constraint') && error.message.includes('user_id')) {
        errorMessage = `Failed to create conversation: User with ID ${userId} does not exist. Please sign in or sign up first.`;
        res.status(400).json({
          error: 'User not found',
          message: errorMessage,
          errorCode: error.code,
          errorDetails: error.details,
          requestId,
          hint: 'The user must be authenticated in Supabase before creating conversations.'
        });
        return;
      }
      
      // Check for invalid API key error specifically
      if (error.message && (error.message.includes('Invalid API key') || error.message.includes('JWT') || error.code === 'PGRST301')) {
        errorMessage = `Failed to create conversation: Invalid API key. Please check SUPABASE_SERVICE_ROLE_KEY in backend .env file. See FIX_INVALID_API_KEY.md for instructions.`;
      }
      
      res.status(500).json({
        error: 'Database error',
        message: errorMessage,
        errorCode: error.code,
        errorDetails: error.details,
        requestId
      });
      return;
    }

    res.status(200).json({
      success: true,
      conversation: data,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in create-conversation', { 
      error: error instanceof Error ? error.message : 'Unknown error',
      requestId 
    });
    
    res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred',
      requestId
    });
  }
}

