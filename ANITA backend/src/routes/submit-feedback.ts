/**
 * Submit Feedback API Route
 * Stores user feedback in Supabase for product improvement. In-app only.
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeInput } from '../utils/sanitizeInput';
import * as logger from '../utils/logger';

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleSubmitFeedback(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);
  const requestId = (req as any).requestId || 'unknown';

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed', requestId });
    return;
  }

  try {
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch {
        res.status(400).json({ error: 'Invalid JSON', requestId });
        return;
      }
    }

    const { userId, message, rating } = body;
    if (!userId || typeof userId !== 'string' || userId.trim() === '') {
      res.status(400).json({ error: 'userId is required', requestId });
      return;
    }
    const messageText = typeof message === 'string' ? sanitizeInput(message.trim()) : '';
    if (messageText.length > 10000) {
      res.status(400).json({ error: 'message must be at most 10000 characters', requestId });
      return;
    }
    const ratingNum = rating != null ? Number(rating) : null;
    const validRating = ratingNum !== null && Number.isInteger(ratingNum) && ratingNum >= 1 && ratingNum <= 5 ? ratingNum : null;
    // Existing user_feedback table (from webapp migration) has rating NOT NULL; default to 1
    const ratingForDb = validRating ?? 1;

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Service unavailable', requestId });
      return;
    }

    const { data, error } = await supabase
      .from('user_feedback')
      .insert({
        user_id: userId.trim(),
        message: messageText || null,
        rating: ratingForDb,
      })
      .select('id, created_at')
      .single();

    if (error) {
      logger.error('Error inserting feedback', { requestId, error: error.message, code: (error as any).code });
      const hint = (error as any).code === '42P01'
        ? ' Run create_support_feedback_tables.sql in Supabase SQL Editor.'
        : '';
      res.status(500).json({
        error: 'Failed to submit feedback',
        message: error.message + hint,
        requestId,
      });
      return;
    }

    res.status(200).json({ success: true, id: data?.id, requestId });
  } catch (e) {
    logger.error('Unexpected error in submit-feedback', { requestId, error: (e as Error).message });
    res.status(500).json({ error: 'Internal server error', requestId });
  }
}
