/**
 * Get Transactions API Route
 * Fetches user transactions from Supabase
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

export async function handleGetTransactions(req: Request, res: Response): Promise<void> {
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
    const userId = req.query.userId as string;

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
        requestId
      });
      return;
    }

    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is not properly configured',
        requestId
      });
      return;
    }

    // Fetch transactions from anita_data table
    const { data, error } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .order('created_at', { ascending: false });

    if (error) {
      logger.error('Error fetching transactions', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch transactions',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const transactions = (data || []).map((item: any) => ({
      id: item.message_id || item.id,
      type: item.transaction_type || 'expense',
      amount: Number(item.transaction_amount) || 0,
      category: item.transaction_category || 'Other',
      description: item.transaction_description || '',
      date: item.transaction_date || item.created_at
    }));

    res.status(200).json({
      success: true,
      transactions,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-transactions', { 
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

