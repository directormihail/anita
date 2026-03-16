/**
 * Migrate User Data API Route
 * Moves all per-user financial data from one user id to another.
 *
 * Primary use-case: user connects bank / creates transactions as an anonymous
 * local user id, then signs up or logs in and gets a Supabase user id.
 * We migrate:
 * - anita_data.account_id          (manual transactions, goals, etc.)
 * - bank_accounts.user_id          (linked bank accounts)
 * - bank_transactions.user_id      (bank transactions)
 * - profiles.stripe_customer_id    (optional: move Stripe customer to new id if needed)
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleMigrateUserData(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);
  const requestId = req.requestId || 'unknown';

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch {
        res.status(400).json({ error: 'Invalid JSON', requestId });
        return;
      }
    }

    const fromUserId = body?.fromUserId?.trim?.();
    const toUserId = body?.toUserId?.trim?.();

    if (!fromUserId || !toUserId || fromUserId === toUserId) {
      res.status(400).json({
        error: 'Missing or invalid fromUserId/toUserId',
        requestId,
      });
      return;
    }

    if (fromUserId.length > 200 || toUserId.length > 200) {
      res.status(400).json({
        error: 'fromUserId/toUserId too long',
        requestId,
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured in migrate-user-data', { requestId });
      res.status(500).json({ error: 'Database not configured', requestId });
      return;
    }

    logger.info('Migrating user data', { requestId, fromUserId, toUserId });

    // 1) anita_data (manual transactions and other user data)
    const { error: anitaError } = await supabase
      .from('anita_data')
      .update({ account_id: toUserId })
      .eq('account_id', fromUserId);

    if (anitaError) {
      logger.error('migrate-user-data: failed to update anita_data', {
        requestId,
        fromUserId,
        toUserId,
        error: anitaError.message,
      });
    }

    // 2) bank_accounts
    const { error: bankAccountsError } = await supabase
      .from('bank_accounts')
      .update({ user_id: toUserId })
      .eq('user_id', fromUserId);

    if (bankAccountsError) {
      logger.error('migrate-user-data: failed to update bank_accounts', {
        requestId,
        fromUserId,
        toUserId,
        error: bankAccountsError.message,
      });
    }

    // 3) bank_transactions
    const { error: bankTxError } = await supabase
      .from('bank_transactions')
      .update({ user_id: toUserId })
      .eq('user_id', fromUserId);

    if (bankTxError) {
      logger.error('migrate-user-data: failed to update bank_transactions', {
        requestId,
        fromUserId,
        toUserId,
        error: bankTxError.message,
      });
    }

    // 4) profiles.stripe_customer_id – move Stripe customer to the new profile
    //    if the new profile does not have one yet.
    const { data: fromProfile } = await supabase
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', fromUserId)
      .maybeSingle();

    const stripeCustomerId = (fromProfile as { stripe_customer_id?: string } | null)
      ?.stripe_customer_id;

    if (stripeCustomerId) {
      const { data: toProfile } = await supabase
        .from('profiles')
        .select('stripe_customer_id')
        .eq('id', toUserId)
        .maybeSingle();

      const hasCustomerOnTo =
        (toProfile as { stripe_customer_id?: string } | null)?.stripe_customer_id != null;

      if (!hasCustomerOnTo) {
        const { error: moveStripeCustomerError } = await supabase
          .from('profiles')
          .update({ stripe_customer_id: stripeCustomerId })
          .eq('id', toUserId);

        if (moveStripeCustomerError) {
          logger.error('migrate-user-data: failed to move stripe_customer_id', {
            requestId,
            fromUserId,
            toUserId,
            error: moveStripeCustomerError.message,
          });
        }
      }
    }

    res.status(200).json({
      success: true,
      fromUserId,
      toUserId,
      requestId,
    });
  } catch (err) {
    logger.error('migrate-user-data: unexpected error', {
      requestId,
      error: err instanceof Error ? err.message : 'Unknown',
    });
    res.status(500).json({
      error: 'Internal server error',
      requestId,
    });
  }
}

