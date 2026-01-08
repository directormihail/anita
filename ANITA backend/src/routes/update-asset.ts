/**
 * Update Asset API Route
 * Updates an asset in Supabase assets table
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

export async function handleUpdateAsset(req: Request, res: Response): Promise<void> {
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
    
    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        res.status(400).json({ 
          error: 'Invalid JSON in request body',
          message: 'Failed to parse request body as JSON',
          requestId
        });
        return;
      }
    }

    const { assetId, userId, currentValue, name, type, description } = body;

    if (!assetId || !userId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'assetId and userId are required',
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

    // Build update object with only provided fields
    const updateData: any = {
      updated_at: new Date().toISOString()
    };

    if (currentValue !== undefined) {
      updateData.current_value = Number(currentValue);
    }
    if (name !== undefined) {
      updateData.name = name.trim();
    }
    if (type !== undefined) {
      updateData.type = type.toLowerCase();
    }
    if (description !== undefined) {
      updateData.description = description?.trim() || null;
    }

    // Update the asset
    const { data, error } = await supabase
      .from('assets')
      .update(updateData)
      .eq('id', assetId)
      .eq('account_id', userId)
      .select()
      .single();

    if (error) {
      logger.error('Error updating asset', { error: error.message, requestId, assetId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to update asset',
        requestId
      });
      return;
    }

    if (!data) {
      res.status(404).json({
        error: 'Asset not found',
        message: 'Asset not found or you do not have permission to update it',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const updatedAsset = {
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

    res.status(200).json({
      success: true,
      asset: updatedAsset,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in update-asset', { 
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
