/**
 * Get Bank Accounts API Route
 * Returns bank accounts linked via Stripe Financial Connections for the given user.
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';
import { requireAuthorizedUserId } from '../utils/requireAuthorizedUser';

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleGetBankAccounts(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    const userId = (req.query.userId as string)?.trim?.();

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

    const { data: accounts, error } = await supabase
      .from('bank_accounts')
      .select('id, stripe_account_id, institution_name, last4, subcategory, created_at, updated_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) {
      logger.error('Error fetching bank accounts', { error: error.message, requestId, userId });
      res.status(500).json({ error: 'Failed to fetch accounts', requestId });
      return;
    }

    res.status(200).json({
      accounts: accounts ?? [],
      requestId,
    });
  } catch (err) {
    const requestId = req.requestId || 'unknown';
    logger.error('Get bank accounts error', {
      error: err instanceof Error ? err.message : 'Unknown',
      requestId,
    });
    res.status(500).json({ error: 'Internal server error', requestId });
  }
}
