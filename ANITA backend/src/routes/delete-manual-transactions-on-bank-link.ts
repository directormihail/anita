/**
 * Permanently deletes all manual transactions (anita_data, data_type = transaction) for a user
 * after they successfully connect a bank. Bank feed becomes the only transaction source in the app.
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

/** POST body: { userId: string } */
export async function handleDeleteManualTransactionsOnBankLink(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed', message: 'Use POST' });
    return;
  }

  const requestId = req.requestId || 'unknown';
  const userId = (req.body?.userId as string)?.trim();

  if (!userId) {
    res.status(400).json({ error: 'Missing userId', requestId });
    return;
  }

  if (!(await requireAuthorizedUserId(req, res, userId, requestId))) {
    return;
  }

  const supabase = getSupabaseClient();
  if (!supabase) {
    res.status(500).json({ error: 'Database not configured', requestId });
    return;
  }

  try {
    const { data, error } = await supabase
      .from('anita_data')
      .delete()
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .select('id');

    if (error) {
      logger.error('Delete manual transactions on bank link failed', { requestId, userId, error: error.message });
      res.status(500).json({ error: 'Database error', message: error.message, requestId });
      return;
    }

    const deletedCount = data?.length ?? 0;
    logger.info('Deleted manual transactions after bank link', { requestId, userId, deletedCount });
    res.status(200).json({ success: true, deletedCount, requestId });
  } catch (e) {
    logger.error('delete-manual-transactions-on-bank-link', {
      requestId,
      error: e instanceof Error ? e.message : 'Unknown'
    });
    res.status(500).json({ error: 'Internal server error', requestId });
  }
}
