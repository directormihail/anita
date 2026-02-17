/**
 * Clear User Data API Route
 * Deletes all app data for a user (transactions, conversations, messages, targets, assets, XP, subscriptions)
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

export async function handleClearUserData(req: Request, res: Response): Promise<void> {
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

    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch {
        res.status(400).json({
          error: 'Invalid JSON in request body',
          message: 'Failed to parse request body as JSON',
          requestId
        });
        return;
      }
    }

    const userId = body.userId as string;
    if (!userId || typeof userId !== 'string' || userId.trim() === '') {
      res.status(400).json({
        error: 'Missing required field',
        message: 'userId is required',
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

    const errors: string[] = [];

    // anita_data: transactions and messages (account_id)
    const { error: anitaDataError } = await supabase
      .from('anita_data')
      .delete()
      .eq('account_id', userId);

    if (anitaDataError) {
      logger.error('Error deleting anita_data', { error: anitaDataError.message, requestId, userId });
      errors.push(`anita_data: ${anitaDataError.message}`);
    }

    // conversations (user_id)
    const { error: convError } = await supabase
      .from('conversations')
      .delete()
      .eq('user_id', userId);

    if (convError) {
      logger.error('Error deleting conversations', { error: convError.message, requestId, userId });
      errors.push(`conversations: ${convError.message}`);
    }

    // targets (account_id)
    const { error: targetsError } = await supabase
      .from('targets')
      .delete()
      .eq('account_id', userId);

    if (targetsError) {
      logger.error('Error deleting targets', { error: targetsError.message, requestId, userId });
      errors.push(`targets: ${targetsError.message}`);
    }

    // assets (account_id)
    const { error: assetsError } = await supabase
      .from('assets')
      .delete()
      .eq('account_id', userId);

    if (assetsError) {
      logger.error('Error deleting assets', { error: assetsError.message, requestId, userId });
      errors.push(`assets: ${assetsError.message}`);
    }

    // user_xp_events (user_id) - if table exists
    const { error: xpEventsError } = await supabase
      .from('user_xp_events')
      .delete()
      .eq('user_id', userId);

    if (xpEventsError) {
      logger.warn('Error deleting user_xp_events (table may not exist)', { error: xpEventsError.message, requestId });
      // do not push to errors so we don't fail the whole request
    }

    // user_xp_stats (user_id)
    const { error: xpStatsError } = await supabase
      .from('user_xp_stats')
      .delete()
      .eq('user_id', userId);

    if (xpStatsError) {
      logger.warn('Error deleting user_xp_stats', { error: xpStatsError.message, requestId });
    }

    // user_subscriptions (user_id) - clear subscription record
    const { error: subError } = await supabase
      .from('user_subscriptions')
      .delete()
      .eq('user_id', userId);

    if (subError) {
      logger.warn('Error deleting user_subscriptions', { error: subError.message, requestId });
    }

    if (errors.length > 0) {
      res.status(500).json({
        error: 'Failed to clear some data',
        message: errors.join('; '),
        requestId
      });
      return;
    }

    logger.info('User data cleared', { requestId, userId });
    res.status(200).json({
      success: true,
      message: 'All user data has been deleted',
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in clear-user-data', {
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
