/**
 * Award XP API Route
 * Calls Supabase award_xp RPC (e.g. daily_chat_message, goal_completed)
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

const ALLOWED_RULE_IDS = ['daily_chat_message', 'goal_completed', 'week_streak_7'];

export async function handleAwardXP(req: Request, res: Response): Promise<void> {
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

    const { userId, ruleId, metadata = {} } = body;

    if (!userId || !ruleId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'userId and ruleId are required',
        requestId
      });
      return;
    }

    if (!ALLOWED_RULE_IDS.includes(ruleId)) {
      res.status(400).json({
        error: 'Invalid ruleId',
        message: `ruleId must be one of: ${ALLOWED_RULE_IDS.join(', ')}`,
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

    const { data, error } = await supabase.rpc('award_xp', {
      p_user_id: userId,
      p_rule_id: ruleId,
      p_metadata: metadata
    });

    if (error) {
      logger.error('award_xp RPC error', { error: error.message, requestId, userId, ruleId });
      res.status(500).json({
        error: 'Database error',
        message: error.message,
        requestId
      });
      return;
    }

    const result = Array.isArray(data) && data.length > 0 ? data[0] : data;
    const success = result?.success === true;
    const xpAwarded = result?.xp_awarded ?? 0;

    res.status(200).json({
      success,
      xpAwarded,
      message: result?.message ?? (success ? 'XP awarded' : 'XP not awarded (e.g. already awarded for this period)'),
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in award-xp', {
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
