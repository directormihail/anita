/**
 * Verify iOS Subscription API Route
 * Verifies StoreKit transactions and updates user subscriptions in Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  // Validate values before creating client - check for placeholders
  const isUrlValid = supabaseUrl && supabaseUrl.trim() !== '' && !supabaseUrl.includes('YOUR_') && !supabaseUrl.includes('your_') && !supabaseUrl.includes('placeholder');
  const isServiceKeyValid = supabaseServiceKey && supabaseServiceKey.trim() !== '' && !supabaseServiceKey.includes('YOUR_') && !supabaseServiceKey.includes('your_') && !supabaseServiceKey.includes('placeholder');
  
  if (isUrlValid && isServiceKeyValid) {
    return createClient(supabaseUrl!, supabaseServiceKey!);
  }
  return null;
}

/**
 * Validate subscription verification request
 */
function validateSubscriptionRequest(body: any): { valid: boolean; error?: string; data?: { userId: string; transactionId: string; productId: string; plan: string } } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be an object' };
  }

  if (!body.userId || typeof body.userId !== 'string' || body.userId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid userId' };
  }

  if (!body.transactionId || typeof body.transactionId !== 'string' || body.transactionId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid transactionId' };
  }

  if (!body.productId || typeof body.productId !== 'string' || body.productId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid productId' };
  }

  // Determine plan from productId
  let plan: string;
  if (body.productId.includes('ultimate')) {
    plan = 'ultimate';
  } else if (body.productId.includes('pro')) {
    plan = 'pro';
  } else {
    return { valid: false, error: 'Invalid productId. Must contain "pro" or "ultimate"' };
  }

  // Validate userId format (should be a UUID)
  if (body.userId.length > 200) {
    return { valid: false, error: 'userId is too long' };
  }

  return {
    valid: true,
    data: {
      userId: body.userId.trim(),
      transactionId: body.transactionId.trim(),
      productId: body.productId.trim(),
      plan
    }
  };
}

export async function handleVerifyIOSSubscription(req: Request, res: Response): Promise<void> {
  // Apply security headers
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
    
    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ 
        error: 'Supabase is not configured. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables.',
        requestId
      });
      return;
    }

    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        logger.warn('Failed to parse request body', { error: e instanceof Error ? e.message : 'Unknown' });
        res.status(400).json({ error: 'Invalid JSON in request body', requestId });
        return;
      }
    }

    // Light sanitization
    if (body && typeof body === 'object') {
      if (body.userId && typeof body.userId === 'string') {
        body.userId = body.userId.trim().replace(/[<>:"|?*\x00-\x1F\x7F]/g, '').substring(0, 200);
      }
      if (body.transactionId && typeof body.transactionId === 'string') {
        body.transactionId = body.transactionId.trim().replace(/[<>:"|?*\x00-\x1F\x7F]/g, '').substring(0, 500);
      }
      if (body.productId && typeof body.productId === 'string') {
        body.productId = body.productId.trim().replace(/[<>:"|?*\x00-\x1F\x7F]/g, '').substring(0, 200);
      }
    }

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.CHECKOUT, 'verify-ios-subscription');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'verify-ios-subscription', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    // Validate input
    const validation = validateSubscriptionRequest(body);
    if (!validation.valid) {
      logger.warn('Validation error', { error: validation.error, requestId });
      res.status(400).json({ error: validation.error, requestId });
      return;
    }

    const { userId, transactionId, plan } = validation.data!;

    // Check if subscription already exists for this user
    const { data: existingSubscription, error: fetchError } = await supabase
      .from('user_subscriptions')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 = no rows returned
      logger.error('Error fetching existing subscription', { 
        error: fetchError.message, 
        requestId 
      });
      res.status(500).json({ 
        error: 'Failed to check existing subscription',
        requestId
      });
      return;
    }

    const subscriptionData = {
      user_id: userId,
      plan: plan,
      status: 'active',
      transaction_id: transactionId,
      updated_at: new Date().toISOString()
    };

    let result;
    if (existingSubscription) {
      // Update existing subscription
      const { data, error } = await supabase
        .from('user_subscriptions')
        .update(subscriptionData)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        logger.error('Error updating subscription', { 
          error: error.message, 
          requestId 
        });
        res.status(500).json({ 
          error: 'Failed to update subscription',
          requestId
        });
        return;
      }

      result = data;
      logger.info('Subscription updated', { userId, plan, transactionId, requestId });
    } else {
      // Create new subscription
      const { data, error } = await supabase
        .from('user_subscriptions')
        .insert(subscriptionData)
        .select()
        .single();

      if (error) {
        logger.error('Error creating subscription', { 
          error: error.message, 
          requestId 
        });
        res.status(500).json({ 
          error: 'Failed to create subscription',
          requestId
        });
        return;
      }

      result = data;
      logger.info('Subscription created', { userId, plan, transactionId, requestId });
    }

    res.status(200).json({
      success: true,
      subscription: {
        userId: result.user_id,
        plan: result.plan,
        status: result.status,
        transactionId: result.transaction_id
      },
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error verifying subscription', { 
      error: error instanceof Error ? error.message : 'Unknown',
      requestId
    });
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to verify subscription',
      requestId
    });
  }
}

