/**
 * Create Target API Route
 * Creates a new target/goal in Supabase targets table
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

export async function handleCreateTarget(req: Request, res: Response): Promise<void> {
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

    const { userId, title, description, targetAmount, currentAmount, currency, targetDate, targetType, priority } = body;

    if (!userId || !title || !targetAmount) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'userId, title, and targetAmount are required',
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

    // Build target data
    const targetData: any = {
      account_id: userId,
      title: title,
      description: description || null,
      target_amount: Number(targetAmount),
      current_amount: Number(currentAmount) || 0,
      currency: currency || 'EUR',
      status: 'active',
      target_type: targetType || 'savings',
      priority: priority || 'medium',
      auto_update: false
    };

    if (targetDate) {
      targetData.target_date = targetDate;
    }

    // Create the target
    const { data, error } = await supabase
      .from('targets')
      .insert([targetData])
      .select()
      .single();

    if (error) {
      logger.error('Error creating target', { error: error.message, requestId, userId, title });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to create target',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const createdTarget = {
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

    logger.info('Target created successfully', { requestId, targetId: data.id, userId, title });

    res.status(200).json({
      success: true,
      target: createdTarget,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in create-target', { 
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
