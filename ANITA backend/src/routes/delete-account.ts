/**
 * Delete Account API Route
 * Permanently deletes all app data and the Supabase Auth user (required for App Store).
 * Order: 1) Clear all app data (same as clear-user-data), 2) Delete auth user.
 */

import { Request, Response } from 'express';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

function getSupabaseClient(): SupabaseClient | null {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

async function clearAllUserData(supabase: SupabaseClient, userId: string, requestId: string): Promise<string[]> {
  const errors: string[] = [];

  const { error: anitaDataError } = await supabase.from('anita_data').delete().eq('account_id', userId);
  if (anitaDataError) {
    logger.error('Error deleting anita_data', { error: anitaDataError.message, requestId, userId });
    errors.push(`anita_data: ${anitaDataError.message}`);
  }

  const { error: convError } = await supabase.from('conversations').delete().eq('user_id', userId);
  if (convError) {
    logger.error('Error deleting conversations', { error: convError.message, requestId, userId });
    errors.push(`conversations: ${convError.message}`);
  }

  const { error: targetsError } = await supabase.from('targets').delete().eq('account_id', userId);
  if (targetsError) {
    logger.error('Error deleting targets', { error: targetsError.message, requestId, userId });
    errors.push(`targets: ${targetsError.message}`);
  }

  const { error: assetsError } = await supabase.from('assets').delete().eq('account_id', userId);
  if (assetsError) {
    logger.error('Error deleting assets', { error: assetsError.message, requestId, userId });
    errors.push(`assets: ${assetsError.message}`);
  }

  const { error: xpEventsError } = await supabase.from('user_xp_events').delete().eq('user_id', userId);
  if (xpEventsError) {
    logger.warn('Error deleting user_xp_events', { error: xpEventsError.message, requestId });
  }

  const { error: xpStatsError } = await supabase.from('user_xp_stats').delete().eq('user_id', userId);
  if (xpStatsError) {
    logger.warn('Error deleting user_xp_stats', { error: xpStatsError.message, requestId });
  }

  const { error: subError } = await supabase.from('user_subscriptions').delete().eq('user_id', userId);
  if (subError) {
    logger.warn('Error deleting user_subscriptions', { error: subError.message, requestId });
  }

  // profiles (if exists) - often keyed by id
  const { error: profilesError } = await supabase.from('profiles').delete().eq('id', userId);
  if (profilesError) {
    logger.warn('Error deleting profiles', { error: profilesError.message, requestId });
  }

  return errors;
}

export async function handleDeleteAccount(req: Request, res: Response): Promise<void> {
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

    // 1) Clear all app data first
    const dataErrors = await clearAllUserData(supabase, userId, requestId);
    if (dataErrors.length > 0) {
      res.status(500).json({
        error: 'Failed to clear some data',
        message: dataErrors.join('; '),
        requestId
      });
      return;
    }

    // 2) Delete the Supabase Auth user (required for App Store account deletion)
    const { error: deleteUserError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      logger.error('Error deleting auth user', { error: deleteUserError.message, requestId, userId });
      res.status(500).json({
        error: 'Failed to delete account',
        message: 'Your data was cleared but we could not remove your account. Please contact Support.',
        requestId
      });
      return;
    }

    logger.info('Account deleted', { requestId, userId });
    res.status(200).json({
      success: true,
      message: 'Your account and all associated data have been permanently deleted',
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in delete-account', {
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
