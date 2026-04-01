/**
 * Get Bank Transactions API Route
 * Returns transactions from linked bank accounts (Stripe Financial Connections) for the given user.
 *
 * Category source: Each row's `category` is stored in DB. It is set only by
 * categorizeUncategorizedBankTransactions (see CATEGORY_FLOW.md). If you see wrong/missing
 * categories, pull-to-refresh to re-sync and re-categorize, or wait for the background
 * categorization triggered when this endpoint returns uncategorized rows.
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';
import { categorizeUncategorizedBankTransactions } from '../utils/categorizeBankTransactions';
import { requireAuthorizedUserId } from '../utils/requireAuthorizedUser';

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
    const limit = Math.min(parseInt(String(req.query.limit), 10) || 100, 1000);

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
        requestId,
      });
      return;
    }

    if (!(await requireAuthorizedUserId(req, res, userId, requestId))) {
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Database not configured', requestId });
      return;
    }

    // Inclusive date range so the full selected month is included
    // from date-only → start of day UTC; to date-only → end of day UTC
    const fromInclusive = from && /^\d{4}-\d{2}-\d{2}$/.test(from) ? `${from}T00:00:00.000Z` : from;
    const toInclusive = to && /^\d{4}-\d{2}-\d{2}$/.test(to) ? `${to}T23:59:59.999Z` : to;

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

    if (fromInclusive) {
      query = query.gte('transacted_at', fromInclusive);
    }
    if (toInclusive) {
      query = query.lte('transacted_at', toInclusive);
    }

    const { data: transactions, error } = await query;

    if (error) {
      logger.error('Error fetching bank transactions', { error: error.message, requestId, userId });
      res.status(500).json({ error: 'Failed to fetch transactions', requestId });
      return;
    }

    const list = transactions ?? [];
    const hasUncategorized = list.some((r: { category?: string | null }) => {
      const cat = (r.category ?? '').trim().toLowerCase();
      return cat === '' || ['other', 'uncategorized', 'unclassified'].includes(cat);
    });
    if (hasUncategorized) {
      setImmediate(() => {
        const supabase = getSupabaseClient();
        if (supabase) {
          categorizeUncategorizedBankTransactions(supabase, userId, requestId).catch((err) => {
            logger.warn('Background categorization after get-bank-transactions failed', {
              requestId,
              userId,
              error: err instanceof Error ? err.message : String(err),
            });
          });
        }
      });
    }

    res.status(200).json({
      transactions: list,
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
