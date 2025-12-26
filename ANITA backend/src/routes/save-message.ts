/**
 * Save Message API Route
 * Saves a message to Supabase anita_data table
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  logger.error('Supabase configuration missing');
}

const supabase = supabaseUrl && supabaseServiceKey 
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

export async function handleSaveMessage(req: Request, res: Response): Promise<void> {
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

    const { 
      userId, 
      conversationId, 
      messageId, 
      messageText, 
      sender, 
      voiceData, 
      transactionData 
    } = body;

    if (!userId || !conversationId || !messageText || !sender) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'userId, conversationId, messageText, and sender are required',
        requestId
      });
      return;
    }

    if (!supabase) {
      const missingVars = [];
      
      // Check URL - only flag if actually missing or placeholder
      if (!supabaseUrl || supabaseUrl.trim() === '' || supabaseUrl.includes('YOUR_') || supabaseUrl.includes('your_') || supabaseUrl.includes('placeholder')) {
        missingVars.push('SUPABASE_URL');
      }
      
      // Check Service Key - only flag if actually missing or placeholder
      if (!supabaseServiceKey || supabaseServiceKey.trim() === '' || supabaseServiceKey.includes('YOUR_') || supabaseServiceKey.includes('your_') || supabaseServiceKey.includes('placeholder')) {
        missingVars.push('SUPABASE_SERVICE_ROLE_KEY');
      }
      
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

    // Prepare message data
    const messageData: any = {
      account_id: userId,
      conversation_id: conversationId,
      message_text: messageText,
      sender: sender,
      message_id: messageId || `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      data_type: 'message',
      created_at: new Date().toISOString()
    };

    // Add optional fields
    if (voiceData) {
      messageData.voice_data = typeof voiceData === 'string' ? voiceData : JSON.stringify(voiceData);
    }

    if (transactionData) {
      messageData.transaction_data = typeof transactionData === 'string' ? transactionData : JSON.stringify(transactionData);
    }

    // Save message to anita_data table
    const { data, error } = await supabase
      .from('anita_data')
      .insert([messageData])
      .select()
      .single();

    if (error) {
      logger.error('Error saving message', { error: error.message, requestId, conversationId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to save message',
        requestId
      });
      return;
    }

    // Update conversation updated_at timestamp
    await supabase
      .from('conversations')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', conversationId)
      .eq('user_id', userId);

    res.status(200).json({
      success: true,
      message: data,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in save-message', { 
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

