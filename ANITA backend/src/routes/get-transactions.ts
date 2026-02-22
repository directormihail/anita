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

    const monthStart = (m: string, y: string) => {
      const monthNum = parseInt(m) - 1;
      const yearNum = parseInt(y);
      return {
        start: new Date(Date.UTC(yearNum, monthNum, 1, 0, 0, 0, 0)).toISOString(),
        end: new Date(Date.UTC(yearNum, monthNum + 1, 0, 23, 59, 59, 999)).toISOString()
      };
    };

    let data: any[] = [];

    if (month && year) {
      const { start: monthStartStr, end: monthEndStr } = month.length > 2
        ? monthStart(month.split('-')[0], month.split('-')[1])
        : monthStart(month, year);
      // 1) Rows with transaction_date in range (persisted user date; survives reload)
      const { data: byTxDate, error: e1 } = await supabase
        .from('anita_data')
        .select('*')
        .eq('account_id', userId)
        .eq('data_type', 'transaction')
        .gte('transaction_date', monthStartStr)
        .lte('transaction_date', monthEndStr)
        .order('created_at', { ascending: false });
      if (!e1 && byTxDate && byTxDate.length > 0) data = byTxDate;
      // 2) Rows with transaction_date null and created_at in range (legacy or no migration yet)
      const { data: byCreated, error: e2 } = await supabase
        .from('anita_data')
        .select('*')
        .eq('account_id', userId)
        .eq('data_type', 'transaction')
        .gte('created_at', monthStartStr)
        .lte('created_at', monthEndStr)
        .order('created_at', { ascending: false });
      if (!e2 && byCreated) {
        const fromTxDateIds = new Set((data || []).map((r: any) => r.message_id || r.id));
        const legacy = (byCreated || []).filter((r: any) => !fromTxDateIds.has(r.message_id || r.id));
        data = [...(data || []), ...legacy].sort((a: any, b: any) => {
          const tA = a.transaction_date || a.created_at || '';
          const tB = b.transaction_date || b.created_at || '';
          return tB.localeCompare(tA);
        });
      }
      if (data.length === 0 && byCreated && byCreated.length > 0) data = byCreated;
      if (e2) {
        logger.error('Error fetching transactions', { error: e2.message, requestId, userId });
        res.status(500).json({ error: 'Database error', message: 'Failed to fetch transactions', requestId });
        return;
      }
    } else if (month) {
      const [yearStr, monthStr] = month.split('-');
      const { start: monthStartStr, end: monthEndStr } = monthStart(monthStr, yearStr);
      const { data: byCreated, error: e } = await supabase
        .from('anita_data')
        .select('*')
        .eq('account_id', userId)
        .eq('data_type', 'transaction')
        .gte('created_at', monthStartStr)
        .lte('created_at', monthEndStr)
        .order('created_at', { ascending: false });
      if (e) {
        logger.error('Error fetching transactions', { error: e.message, requestId, userId });
        res.status(500).json({ error: 'Database error', message: 'Failed to fetch transactions', requestId });
        return;
      }
      if (byCreated) data = byCreated;
    } else {
      const { data: allData, error: e } = await supabase
        .from('anita_data')
        .select('*')
        .eq('account_id', userId)
        .eq('data_type', 'transaction')
        .order('created_at', { ascending: false });
      if (e) {
        logger.error('Error fetching transactions', { error: e.message, requestId, userId });
        res.status(500).json({ error: 'Database error', message: 'Failed to fetch transactions', requestId });
        return;
      }
      if (allData) data = allData;
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

