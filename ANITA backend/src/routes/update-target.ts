/**
 * Update Target API Route
 * Updates a target/goal in Supabase targets table
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

export async function handleUpdateTarget(req: Request, res: Response): Promise<void> {
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

    const { targetId, userId, targetAmount, currentAmount, title, description, targetDate, status, priority } = body;

    if (!targetId || !userId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'targetId and userId are required',
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

    if (targetAmount !== undefined) {
      updateData.target_amount = Number(targetAmount);
    }
    if (currentAmount !== undefined) {
      updateData.current_amount = Number(currentAmount);
    }
    if (title !== undefined) {
      updateData.title = title;
    }
    if (description !== undefined) {
      updateData.description = description;
    }
    if (targetDate !== undefined) {
      updateData.target_date = targetDate;
    }
    if (status !== undefined) {
      updateData.status = status;
    }
    if (priority !== undefined) {
      updateData.priority = priority;
    }

    // Update the target
    const { data, error } = await supabase
      .from('targets')
      .update(updateData)
      .eq('id', targetId)
      .eq('account_id', userId)
      .select()
      .single();

    if (error) {
      logger.error('Error updating target', { error: error.message, requestId, targetId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to update target',
        requestId
      });
      return;
    }

    if (!data) {
      res.status(404).json({
        error: 'Target not found',
        message: 'Target not found or you do not have permission to update it',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const updatedTarget = {
      id: data.id,
      accountId: data.account_id,
      title: data.title,
      description: data.description || '',
      targetAmount: Number(data.target_amount) || 0,
      currentAmount: Number(data.current_amount) || 0,
      currency: data.currency || 'EUR',
      targetDate: data.target_date || null,
      status: data.status || 'active',
      targetType: data.target_type || 'savings',
      category: data.category || null,
      priority: data.priority || 'medium',
      autoUpdate: data.auto_update || false,
      createdAt: data.created_at,
      updatedAt: data.updated_at
    };

    res.status(200).json({
      success: true,
      target: updatedTarget,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in update-target', { 
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
