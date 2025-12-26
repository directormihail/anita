/**
 * Get Messages API Route
 * Fetches messages from a conversation in Supabase
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

export async function handleGetMessages(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ 
      error: 'Method not allowed',
      message: `Method ${req.method} is not allowed. Use GET.`
    });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    const conversationId = req.query.conversationId as string;
    const userId = req.query.userId as string;

    if (!conversationId) {
      res.status(400).json({
        error: 'Missing conversationId',
        message: 'conversationId query parameter is required',
        requestId
      });
      return;
    }

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
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

    // Fetch messages from anita_data table
    const { data, error } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('conversation_id', conversationId)
      .eq('data_type', 'message')
      .order('created_at', { ascending: true });

    if (error) {
      logger.error('Error fetching messages', { error: error.message, requestId, conversationId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch messages',
        requestId
      });
      return;
    }

    res.status(200).json({
      success: true,
      messages: data || [],
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-messages', { 
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

