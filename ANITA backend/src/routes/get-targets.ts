/**
 * Get Targets API Route
 * Fetches user financial targets/goals from Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleGetTargets(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ 
      error: 'Method not allowed',
      message: `Method ${req.method} is not allowed. Use GET.`
    });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    const userId = req.query.userId as string;

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
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

    // Fetch targets from targets table
    const { data, error } = await supabase
      .from('targets')
      .select('*')
      .eq('account_id', userId)
      .eq('status', 'active')
      .order('priority', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      logger.error('Error fetching targets', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch targets',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const targets = (data || []).map((item: any) => ({
      id: item.id,
      accountId: item.account_id,
      title: item.title,
      description: item.description || '',
      targetAmount: Number(item.target_amount) || 0,
      currentAmount: Number(item.current_amount) || 0,
      currency: item.currency || 'EUR',
      targetDate: item.target_date || null,
      status: item.status || 'active',
      targetType: item.target_type || 'savings',
      category: item.category || null,
      priority: item.priority || 'medium',
      autoUpdate: item.auto_update || false,
      createdAt: item.created_at,
      updatedAt: item.updated_at
    }));

    res.status(200).json({
      success: true,
      targets,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-targets', { 
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

