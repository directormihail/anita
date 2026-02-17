/**
 * Submit Support Request API Route
 * Stores user support messages in Supabase for handling. No website or email; in-app only.
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

export async function handleSubmitSupport(req: Request, res: Response): Promise<void> {
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

    const { userId, subject, message } = body;
    if (!userId || typeof userId !== 'string' || userId.trim() === '') {
      res.status(400).json({ error: 'userId is required', requestId });
      return;
    }
    const messageText = typeof message === 'string' ? sanitizeInput(message.trim()) : '';
    if (!messageText || messageText.length > 10000) {
      res.status(400).json({ error: 'message is required and must be 1–10000 characters', requestId });
      return;
    }
    const subjectText = typeof subject === 'string' ? sanitizeInput(subject.trim()).slice(0, 500) : null;

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Service unavailable', requestId });
      return;
    }

    const { data, error } = await supabase
      .from('user_support_requests')
      .insert({
        user_id: userId.trim(),
        subject: subjectText || null,
        message: messageText,
      })
      .select('id, created_at')
      .single();

    if (error) {
      logger.error('Error inserting support request', { requestId, error: error.message, code: (error as any).code });
      const hint = (error as any).code === '42P01'
        ? ' Create the table: run ANITA backend/create_support_feedback_tables.sql in Supabase → SQL Editor.'
        : '';
      res.status(500).json({
        error: 'Failed to submit support request',
        message: error.message + hint,
        requestId,
      });
      return;
    }

    res.status(200).json({ success: true, id: data?.id, requestId });
  } catch (e) {
    logger.error('Unexpected error in submit-support', { requestId, error: (e as Error).message });
    res.status(500).json({ error: 'Internal server error', requestId });
  }
}
