/**
 * Save Message Feedback API Route
 * Saves user feedback (like/dislike) for a message to Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleSaveMessageFeedback(req: Request, res: Response): Promise<void> {
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
      messageId, 
      conversationId,
      feedbackType // 'like' or 'dislike'
    } = body;

    if (!userId || !messageId || !feedbackType) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'userId, messageId, and feedbackType are required',
        requestId
      });
      return;
    }

    if (feedbackType !== 'like' && feedbackType !== 'dislike') {
      res.status(400).json({
        error: 'Invalid feedback type',
        message: 'feedbackType must be either "like" or "dislike"',
        requestId
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      const missingVars = [];
      const supabaseUrl = process.env.SUPABASE_URL;
      const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
      
      if (!supabaseUrl || supabaseUrl.trim() === '' || supabaseUrl.includes('YOUR_') || supabaseUrl.includes('your_') || supabaseUrl.includes('placeholder')) {
        missingVars.push('SUPABASE_URL');
      }
      
      if (!supabaseServiceKey || supabaseServiceKey.trim() === '' || supabaseServiceKey.includes('YOUR_') || supabaseServiceKey.includes('your_') || supabaseServiceKey.includes('placeholder')) {
        missingVars.push('SUPABASE_SERVICE_ROLE_KEY');
      }
      
      logger.error('Supabase not configured', { requestId, missingVars });
      
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is incorrectly configured',
        requestId
      });
      return;
    }

    // Check if feedback already exists for this message and user
    const { data: existingFeedback } = await supabase
      .from('message_feedback')
      .select('*')
      .eq('user_id', userId)
      .eq('message_id', messageId)
      .maybeSingle();

    let result;
    if (existingFeedback) {
      // Update existing feedback
      const { data, error } = await supabase
        .from('message_feedback')
        .update({
          feedback_type: feedbackType,
          updated_at: new Date().toISOString()
        })
        .eq('id', existingFeedback.id)
        .select()
        .single();

      if (error) {
        logger.error('Error updating message feedback', { error: error.message, requestId, messageId, userId });
        res.status(500).json({
          error: 'Database error',
          message: 'Failed to update feedback',
          requestId
        });
        return;
      }

      result = data;
    } else {
      // Insert new feedback
      const feedbackData: any = {
        user_id: userId,
        message_id: messageId,
        conversation_id: conversationId || null,
        feedback_type: feedbackType,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from('message_feedback')
        .insert([feedbackData])
        .select()
        .single();

      if (error) {
        logger.error('Error saving message feedback', { error: error.message, requestId, messageId, userId });
        res.status(500).json({
          error: 'Database error',
          message: 'Failed to save feedback',
          requestId
        });
        return;
      }

      result = data;
    }

    res.status(200).json({
      success: true,
      feedback: result,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in save-message-feedback', { 
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

