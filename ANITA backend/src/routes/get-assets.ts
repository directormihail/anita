/**
 * Get Assets API Route
 * Fetches user assets from Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  logger.error('Supabase configuration missing');
}

const supabase = supabaseUrl && supabaseServiceKey 
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

export async function handleGetAssets(req: Request, res: Response): Promise<void> {
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

    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is not properly configured',
        requestId
      });
      return;
    }

    // Fetch assets from assets table
    const { data, error } = await supabase
      .from('assets')
      .select('*')
      .eq('account_id', userId)
      .order('current_value', { ascending: false });

    if (error) {
      logger.error('Error fetching assets', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch assets',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const assets = (data || []).map((item: any) => ({
      id: item.id,
      accountId: item.account_id,
      name: item.name,
      type: item.type || 'other',
      currentValue: Number(item.current_value) || 0,
      description: item.description || '',
      currency: item.currency || 'EUR',
      createdAt: item.created_at,
      updatedAt: item.updated_at
    }));

    res.status(200).json({
      success: true,
      assets,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-assets', { 
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

