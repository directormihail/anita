/**
 * App Open API Route
 * Records an app open and optionally awards week_streak_7 (100 XP) if user opened 7 days this week.
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

export async function handleAppOpen(req: Request, res: Response): Promise<void> {
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
        res.status(400).json({ error: 'Invalid JSON', message: 'Failed to parse body' });
        return;
      }
    }

    const { userId } = body;

    if (!userId) {
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

    const { data, error } = await supabase.rpc('record_app_open', {
      p_user_id: userId
    });

    if (error) {
      logger.error('record_app_open RPC error', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: error.message,
        requestId
      });
      return;
    }

    const row = Array.isArray(data) && data.length > 0 ? data[0] : data;
    const awardedStreak = row?.awarded_streak === true;
    const daysThisWeek = typeof row?.days_this_week === 'number' ? row.days_this_week : 0;

    res.status(200).json({
      success: true,
      awardedStreak,
      daysThisWeek,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in app-open', {
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
