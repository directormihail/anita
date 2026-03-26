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

const ALLOWED_RULE_IDS = ['transaction_added', 'daily_chat_message', 'goal_completed', 'week_streak_7'];

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

    const result = Array.isArray(data) && data.length > 0 ? data[0] : data;
    const success = result?.success === true;
    const xpAwarded = result?.xp_awarded ?? 0;

    // Critical: "daily_chat_message" should reward EVERY user chat message.
    // If the backend RPC enforces a once-per-period rule (or if the xp_rule row is missing),
    // we fall back to inserting an XP event directly so get-xp-stats reflects chat usage.
    const shouldForceChatXP = ruleId === 'daily_chat_message' && (!success || xpAwarded <= 0);
    if (shouldForceChatXP) {
      const fallbackXpAmount = 5; // Keep in sync with UX expectation ("5 XP per chat message")
      const eventId = `xp_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
      const description = 'Chat with ANITA';

      // Ensure xp_rules row exists, otherwise foreign key insert into user_xp_events fails.
      await supabase.from('xp_rules').upsert(
        {
          id: ruleId,
          category: 'Engagement',
          name: 'Daily chat message',
          xp_amount: fallbackXpAmount,
          description: 'User chat with ANITA',
          frequency: 'event',
          extra_meta: {},
          updated_at: new Date().toISOString()
        },
        { onConflict: 'id' }
      );

      const { error: insertErr } = await supabase.from('user_xp_events').insert({
        id: eventId,
        user_id: userId,
        rule_id: ruleId,
        xp_amount: fallbackXpAmount,
        description,
        metadata: metadata || {}
      });

      if (insertErr) {
        logger.error('Failed to insert fallback chat XP event', {
          requestId,
          userId,
          ruleId,
          error: insertErr.message
        });
      } else {
        res.status(200).json({
          success: true,
          xpAwarded: fallbackXpAmount,
          message: 'XP awarded (chat message)'
          ,
          requestId
        });
        return;
      }
    }

    if (error) {
      logger.error('award_xp RPC error', { error: error.message, requestId, userId, ruleId });
      res.status(500).json({
        error: 'Database error',
        message: error.message,
        requestId
      });
      return;
    }

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
