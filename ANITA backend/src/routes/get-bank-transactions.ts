/**
 * Get Bank Transactions API Route
 * Returns transactions from linked bank accounts (Stripe Financial Connections) for the given user.
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleGetBankTransactions(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    const userId = (req.query.userId as string)?.trim?.();
    const from = (req.query.from as string)?.trim?.(); // ISO date or YYYY-MM-DD
    const to = (req.query.to as string)?.trim?.();
    const limit = Math.min(parseInt(String(req.query.limit), 10) || 100, 500);

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
        requestId,
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Database not configured', requestId });
      return;
    }

    let query = supabase
      .from('bank_transactions')
      .select(`
        id,
        amount_cents,
        currency,
        description,
        merchant_name,
        transacted_at,
        category,
        raw_category,
        bank_account_id
      `)
      .eq('user_id', userId)
      .order('transacted_at', { ascending: false })
      .limit(limit);

    if (from) {
      query = query.gte('transacted_at', from);
    }
    if (to) {
      query = query.lte('transacted_at', to);
    }

    const { data: transactions, error } = await query;

    if (error) {
      logger.error('Error fetching bank transactions', { error: error.message, requestId, userId });
      res.status(500).json({ error: 'Failed to fetch transactions', requestId });
      return;
    }

    res.status(200).json({
      transactions: transactions ?? [],
      requestId,
    });
  } catch (err) {
    const requestId = req.requestId || 'unknown';
    logger.error('Get bank transactions error', {
      error: err instanceof Error ? err.message : 'Unknown',
      requestId,
    });
    res.status(500).json({ error: 'Internal server error', requestId });
  }
}
