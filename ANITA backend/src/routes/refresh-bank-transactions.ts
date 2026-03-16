/**
 * Refresh Bank Transactions API Route
 * Re-fetches transactions from Stripe for all linked bank accounts and upserts into bank_transactions.
 * Use when webhook was delayed or user pulls to refresh in the app.
 */

import { Request, Response } from 'express';
import Stripe from 'stripe';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';
import { categorizeUncategorizedBankTransactions } from '../utils/categorizeBankTransactions';

function getStripe(): Stripe | null {
  const raw = (process.env.STRIPE_SECRET_KEY ?? '').trim().replace(/^["']|["']$/g, '');
  if (raw.length > 0 && raw.startsWith('sk_')) {
    return new Stripe(raw, { apiVersion: '2025-02-24.acacia' });
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

async function syncTransactionsForAccount(
  stripe: Stripe,
  stripeAccountId: string,
  bankAccountId: string,
  userId: string,
  supabase: SupabaseClient
): Promise<number> {
  const account = await stripe.financialConnections.accounts.retrieve(stripeAccountId);
  let count = 0;
  let startingAfter: string | undefined;

  while (true) {
    const list = await stripe.financialConnections.transactions.list({
      account: account.id,
      limit: 100,
      ...(startingAfter ? { starting_after: startingAfter } : {}),
    });

    for (const tx of list.data) {
      const amountCents = typeof tx.amount === 'number' ? tx.amount : (tx as any).amount ?? 0;
      const payload = {
        user_id: userId,
        bank_account_id: bankAccountId,
        stripe_transaction_id: tx.id,
        amount_cents: amountCents,
        currency: (tx.currency ?? 'usd').toLowerCase(),
        description: tx.description ?? null,
        merchant_name: (tx as any).merchant_name ?? null,
        transacted_at:
          typeof tx.transacted_at === 'number'
            ? new Date(tx.transacted_at * 1000).toISOString()
            : (tx as any).transacted_at ?? new Date().toISOString(),
        // Do NOT set category from Stripe – we use AI categorization; overwriting with Stripe's "other" would hide correct categories
        raw_category: (tx as any).raw_category ?? null,
        updated_at: new Date().toISOString(),
      };
      await supabase.from('bank_transactions').upsert(payload as Record<string, unknown>, {
        onConflict: 'bank_account_id,stripe_transaction_id',
        ignoreDuplicates: false,
      });
      count++;
    }

    if (!list.has_more || list.data.length === 0) break;
    startingAfter = list.data[list.data.length - 1].id;
  }

  return count;
}

export async function handleRefreshBankTransactions(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);
  const requestId = req.requestId || 'unknown';

  if (req.method !== 'POST' && req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const userId =
      (req.body?.userId as string)?.trim?.() ?? (req.query.userId as string)?.trim?.();
    if (!userId || userId.length > 200) {
      res.status(400).json({ error: 'Missing or invalid userId', requestId });
      return;
    }

    const stripe = getStripe();
    if (!stripe) {
      res.status(500).json({ error: 'Stripe not configured', requestId });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      res.status(500).json({ error: 'Database not configured', requestId });
      return;
    }

    const { data: accounts, error: accountsError } = await supabase
      .from('bank_accounts')
      .select('id, stripe_account_id')
      .eq('user_id', userId);

    if (accountsError) {
      logger.error('Error fetching bank accounts for refresh', {
        error: accountsError.message,
        requestId,
        userId,
      });
      res.status(500).json({ error: 'Failed to fetch bank accounts', requestId });
      return;
    }

    if (!accounts?.length) {
      res.status(200).json({
        success: true,
        accountsRefreshed: 0,
        transactionsSynced: 0,
        message: 'No linked bank accounts',
        requestId,
      });
      return;
    }

    let totalTx = 0;
    for (const acc of accounts) {
      try {
        const n = await syncTransactionsForAccount(
          stripe,
          acc.stripe_account_id,
          acc.id,
          userId,
          supabase
        );
        totalTx += n;
      } catch (err) {
        logger.warn('Refresh sync failed for one account', {
          accountId: acc.id,
          error: err instanceof Error ? err.message : 'Unknown',
          requestId,
        });
      }
    }

    // AI categorization: assign canonical ANITA categories to uncategorized bank transactions
    let categorized = { updated: 0, failed: 0 };
    try {
      categorized = await categorizeUncategorizedBankTransactions(supabase, userId, requestId);
    } catch (err) {
      logger.warn('AI categorization after refresh failed', {
        requestId,
        userId,
        error: err instanceof Error ? err.message : 'Unknown',
      });
    }

    res.status(200).json({
      success: true,
      accountsRefreshed: accounts.length,
      transactionsSynced: totalTx,
      categoriesAssigned: categorized.updated,
      requestId,
    });
  } catch (err) {
    logger.error('Refresh bank transactions error', {
      error: err instanceof Error ? err.message : 'Unknown',
      requestId,
    });
    res.status(500).json({
      error: err instanceof Error ? err.message : 'Internal server error',
      requestId,
    });
  }
}
