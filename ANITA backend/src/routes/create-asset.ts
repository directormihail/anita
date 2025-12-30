/**
 * Create Asset API Route
 * Creates a new asset for a user in Supabase
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

interface CreateAssetRequestBody {
  userId: string;
  name: string;
  type: string;
  currentValue: number;
  description?: string;
}

export async function handleCreateAsset(req: Request, res: Response): Promise<void> {
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
    const body: CreateAssetRequestBody = req.body;

    // Validate required fields
    if (!body.userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId is required',
        requestId
      });
      return;
    }

    if (!body.name || body.name.trim().length === 0) {
      res.status(400).json({
        error: 'Missing name',
        message: 'Asset name is required',
        requestId
      });
      return;
    }

    if (!body.type) {
      res.status(400).json({
        error: 'Missing type',
        message: 'Asset type is required',
        requestId
      });
      return;
    }

    if (body.currentValue === undefined || body.currentValue === null || isNaN(body.currentValue)) {
      res.status(400).json({
        error: 'Invalid currentValue',
        message: 'Current value must be a valid number',
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

    // Get user's currency preference (default to EUR)
    const currency = 'EUR'; // TODO: Get from user preferences if available

    // Insert asset into database
    const { data, error } = await supabase
      .from('assets')
      .insert([{
        account_id: body.userId,
        name: body.name.trim(),
        type: body.type.toLowerCase(),
        current_value: body.currentValue,
        description: body.description?.trim() || null,
        currency: currency
      }])
      .select()
      .single();

    if (error) {
      logger.error('Error creating asset', { error: error.message, requestId, userId: body.userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to create asset',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const asset = {
      id: data.id,
      accountId: data.account_id,
      name: data.name,
      type: data.type || 'other',
      currentValue: Number(data.current_value) || 0,
      description: data.description || '',
      currency: data.currency || 'EUR',
      createdAt: data.created_at,
      updatedAt: data.updated_at
    };

    res.status(201).json({
      success: true,
      asset,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error creating asset', { error, requestId });
    res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred',
      requestId
    });
  }
}

