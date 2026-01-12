/**
 * Get Transactions API Route
 * Fetches user transactions from Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { normalizeCategory } from '../utils/categoryNormalizer';
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
    const month = req.query.month as string; // Format: "2024-01" (YYYY-MM)
    const year = req.query.year as string;

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
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

    // Build query
    let query = supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction');
    
    // Filter by month if provided
    if (month && year) {
      const monthNum = parseInt(month) - 1;
      const yearNum = parseInt(year);
      const monthStart = new Date(yearNum, monthNum, 1).toISOString();
      const monthEnd = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999).toISOString();
      query = query.gte('created_at', monthStart).lte('created_at', monthEnd);
    } else if (month) {
      // Format: "2024-01"
      const [yearStr, monthStr] = month.split('-');
      const monthNum = parseInt(monthStr) - 1;
      const yearNum = parseInt(yearStr);
      const monthStart = new Date(yearNum, monthNum, 1).toISOString();
      const monthEnd = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999).toISOString();
      query = query.gte('created_at', monthStart).lte('created_at', monthEnd);
    }
    
    const { data, error } = await query.order('created_at', { ascending: false });

    if (error) {
      logger.error('Error fetching transactions', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch transactions',
        requestId
      });
      return;
    }

    // Transform data to match expected format and normalize categories
    const transactions = (data || []).map((item: any) => ({
      id: item.message_id || item.id,
      type: item.transaction_type || 'expense',
      amount: Number(item.transaction_amount) || 0,
      category: normalizeCategory(item.transaction_category), // Normalize to proper case
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

