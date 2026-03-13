/**
 * Create Financial Connections Session API Route
 * Creates a Stripe Financial Connections session so the user can link bank accounts.
 * Returns client_secret for use with Stripe SDK or hosted URL.
 */

import { Request, Response } from 'express';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

/** Read Stripe key at request time so it picks up .env loaded by index.ts (imports run before dotenv.config). */
function getStripe(): Stripe | null {
  const raw = process.env.STRIPE_SECRET_KEY ?? '';
  const key = raw.trim().replace(/^["']|["']$/g, '');
  if (key.length > 0 && key.startsWith('sk_')) {
    return new Stripe(key, { apiVersion: '2025-02-24.acacia' });
  }
  return null;
}

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleCreateFinancialConnectionsSession(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';

    const stripe = getStripe();
    if (!stripe) {
      logger.error('Stripe not configured', { requestId });
      res.status(500).json({
        error: 'Stripe is not configured. Set STRIPE_SECRET_KEY.',
        requestId,
      });
      return;
    }

    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch {
        res.status(400).json({ error: 'Invalid JSON' });
        return;
      }
    }

    const userId = body?.userId?.trim?.();
    const userEmail = body?.userEmail?.trim?.();

    if (!userId || userId.length > 200) {
      res.status(400).json({
        error: 'Missing or invalid userId',
        requestId,
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Database not configured', requestId });
      return;
    }

    // Get or create Stripe customer and store in profiles
    let customerId: string | null = null;

    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', userId)
      .single();

    if (profile?.stripe_customer_id) {
      customerId = profile.stripe_customer_id;
    } else {
      const customer = await stripe.customers.create({
        email: userEmail || undefined,
        metadata: { anita_user_id: userId },
      });
      customerId = customer.id;
      await supabase
        .from('profiles')
        .upsert(
          { id: userId, stripe_customer_id: customerId },
          { onConflict: 'id' }
        );
    }

    if (!customerId) {
      res.status(500).json({ error: 'Could not resolve Stripe customer', requestId });
      return;
    }

    const session = await stripe.financialConnections.sessions.create({
      account_holder: {
        type: 'customer',
        customer: customerId,
      },
      permissions: ['balances', 'transactions'],
      prefetch: ['balances', 'transactions'],
    });

    logger.info('Financial Connections session created', {
      sessionId: session.id,
      userId,
      requestId,
    });

    const clientSecret = session.client_secret ?? null;
    if (!clientSecret) {
      res.status(500).json({ error: 'Session missing client_secret', requestId });
      return;
    }

    res.status(200).json({
      client_secret: clientSecret,
      session_id: session.id,
      requestId,
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Create Financial Connections session failed', {
      error: error instanceof Error ? error.message : 'Unknown',
      requestId,
    });
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Failed to create session',
      requestId,
    });
  }
}
