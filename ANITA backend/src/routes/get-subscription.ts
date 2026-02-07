/**
 * Get Subscription API Route
 * Fetches user subscription status from Supabase
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

export async function handleGetSubscription(req: Request, res: Response): Promise<void> {
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

    // Fetch subscription from database
    const { data: subscription, error: subscriptionError } = await supabase
      .from('user_subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (subscriptionError && subscriptionError.code !== 'PGRST116') { // PGRST116 = not found
      logger.error('Error fetching subscription', { 
        error: subscriptionError.message, 
        requestId, 
        userId 
      });
      res.status(500).json({
        error: 'Failed to fetch subscription',
        message: subscriptionError.message,
        requestId
      });
      return;
    }

    // If no subscription found, return free plan
    if (!subscription) {
      res.status(200).json({
        success: true,
        subscription: {
          userId: userId,
          plan: 'free',
          status: 'active'
        },
        requestId
      });
      return;
    }

    // Return subscription data
    res.status(200).json({
      success: true,
      subscription: {
        userId: subscription.user_id,
        plan: subscription.plan,
        status: subscription.status,
        transactionId: subscription.transaction_id,
        updatedAt: subscription.updated_at
      },
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error fetching subscription', { 
      error: error instanceof Error ? error.message : 'Unknown',
      requestId
    });
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to fetch subscription',
      requestId
    });
  }
}
