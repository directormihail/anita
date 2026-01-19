/**
 * Delete Transaction API Route
 * Deletes a transaction from Supabase anita_data table
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

export async function handleDeleteTransaction(req: Request, res: Response): Promise<void> {
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
          message: 'Failed to parse request body as JSON',
          requestId
        });
        return;
      }
    }

    const { transactionId, userId } = body;

    if (!transactionId || !userId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'transactionId and userId are required',
        requestId
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is not properly configured',
        requestId
      });
      return;
    }

    // Delete the transaction (using message_id as the identifier)
    const { error } = await supabase
      .from('anita_data')
      .delete()
      .eq('message_id', transactionId)
      .eq('account_id', userId)
      .eq('data_type', 'transaction');

    if (error) {
      logger.error('Error deleting transaction', { error: error.message, requestId, transactionId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to delete transaction',
        requestId
      });
      return;
    }

    res.status(200).json({
      success: true,
      message: 'Transaction deleted successfully',
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in delete-transaction', { 
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
