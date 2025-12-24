/**
 * Create Checkout Session API Route
 * Creates Stripe checkout sessions for subscriptions
 */

import { Request, Response } from 'express';
import Stripe from 'stripe';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

if (!stripeSecretKey) {
  logger.error('Stripe secret key not configured');
}

const stripe = stripeSecretKey 
  ? new Stripe(stripeSecretKey, {
      apiVersion: '2025-02-24.acacia',
    })
  : null;

// Subscription plan prices in cents
const SUBSCRIPTION_PLANS = {
  pro: {
    priceId: process.env.STRIPE_PRO_PRICE_ID || 'price_pro_monthly',
    amount: 499, // $4.99 in cents
    name: 'Pro Plan',
  },
  ultimate: {
    priceId: process.env.STRIPE_ULTIMATE_PRICE_ID || 'price_ultimate_monthly',
    amount: 999, // $9.99 in cents
    name: 'Ultimate Plan',
  },
};

/**
 * Validate checkout request
 */
function validateCheckoutRequest(body: any): { valid: boolean; error?: string; data?: { plan: string; userId: string; userEmail?: string } } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be an object' };
  }

  if (!body.plan || typeof body.plan !== 'string' || !['pro', 'ultimate'].includes(body.plan)) {
    return { valid: false, error: 'Invalid plan. Must be "pro" or "ultimate"' };
  }

  if (!body.userId || typeof body.userId !== 'string' || body.userId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid userId' };
  }

  // Validate userId format (should be a UUID or valid string)
  if (body.userId.length > 200) {
    return { valid: false, error: 'userId is too long' };
  }

  // Validate email if provided
  if (body.userEmail !== undefined) {
    if (typeof body.userEmail !== 'string') {
      return { valid: false, error: 'userEmail must be a string if provided' };
    }
    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (body.userEmail.length > 0 && !emailRegex.test(body.userEmail)) {
      return { valid: false, error: 'Invalid email format' };
    }
    if (body.userEmail.length > 255) {
      return { valid: false, error: 'Email is too long' };
    }
  }

  return {
    valid: true,
    data: {
      plan: body.plan,
      userId: body.userId.trim(),
      userEmail: body.userEmail?.trim() || undefined
    }
  };
}

export async function handleCreateCheckoutSession(req: Request, res: Response): Promise<void> {
  // Apply security headers
  applySecurityHeaders(res);

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    
    if (!stripe) {
      logger.error('Stripe not configured', { requestId });
      res.status(500).json({ 
        error: 'Stripe is not configured. Please set STRIPE_SECRET_KEY environment variable.',
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
        res.status(400).json({ error: 'Invalid JSON in request body' });
        return;
      }
    }

    // Light sanitization - only for user-provided strings
    if (body && typeof body === 'object') {
      if (body.userId && typeof body.userId === 'string') {
        // Light sanitization for userId - only remove dangerous characters, preserve UUIDs
        body.userId = body.userId.trim().replace(/[<>:"|?*\x00-\x1F\x7F]/g, '').substring(0, 200);
      }
      if (body.userEmail && typeof body.userEmail === 'string') {
        // Light sanitization for email - preserve email format
        body.userEmail = body.userEmail.trim().replace(/[<>:"|?*\x00-\x1F\x7F]/g, '').substring(0, 255);
      }
    }

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.CHECKOUT, 'create-checkout-session');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'create-checkout-session', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    // Validate input
    const validation = validateCheckoutRequest(body);
    if (!validation.valid) {
      logger.warn('Validation error', { error: validation.error, requestId });
      res.status(400).json({ error: validation.error, requestId });
      return;
    }

    const { plan, userId, userEmail } = validation.data!;

    const selectedPlan = SUBSCRIPTION_PLANS[plan as keyof typeof SUBSCRIPTION_PLANS];
    
    // Determine base URL for redirects
    // For iOS app, use deep link or app URL scheme
    let baseUrl = process.env.APP_URL || 'https://anita.app';
    if (process.env.VERCEL_URL) {
      baseUrl = `https://${process.env.VERCEL_URL}`;
    } else if (process.env.REACT_APP_URL) {
      baseUrl = process.env.REACT_APP_URL;
    }

    // Create Checkout Session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: selectedPlan.name,
              description: `Monthly subscription to ${selectedPlan.name}`,
            },
            recurring: {
              interval: 'month',
            },
            unit_amount: selectedPlan.amount,
          },
          quantity: 1,
        },
      ],
      mode: 'subscription',
      customer_email: userEmail || undefined,
      client_reference_id: userId,
      metadata: {
        userId,
        plan,
      },
      success_url: `${baseUrl}?payment=success&session_id={CHECKOUT_SESSION_ID}&plan=${plan}`,
      cancel_url: `${baseUrl}?payment=cancelled`,
    });

    logger.info('Stripe checkout session created', { sessionId: session.id, requestId });

    res.status(200).json({
      sessionId: session.id,
      url: session.url,
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error creating checkout session', { 
      error: error instanceof Error ? error.message : 'Unknown',
      requestId
    });
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to create checkout session',
      requestId
    });
  }
}

