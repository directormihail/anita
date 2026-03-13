/**
 * Stripe Webhook handler for Financial Connections
 * Handles financial_connections.account.created and account.refreshed;
 * fetches balances/transactions from Stripe and stores them in Supabase.
 */

import { Request, Response } from 'express';
import Stripe from 'stripe';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import * as logger from '../utils/logger';

/** Read at request time so .env is loaded (same as create-financial-connections-session). */
function getStripe(): Stripe | null {
  const raw = (process.env.STRIPE_SECRET_KEY ?? '').trim().replace(/^["']|["']$/g, '');
  if (raw.length > 0 && raw.startsWith('sk_')) {
    return new Stripe(raw, { apiVersion: '2025-02-24.acacia' });
  }
  return null;
}

function getWebhookSecret(): string | null {
  const raw = (process.env.STRIPE_WEBHOOK_SECRET ?? '').trim().replace(/^["']|["']$/g, '');
  return raw.length > 0 && raw.startsWith('whsec_') ? raw : null;
}

function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

/**
 * Resolve ANITA user_id from Stripe customer id (from profiles.stripe_customer_id).
 */
async function getUserIdFromStripeCustomer(supabase: SupabaseClient, stripeCustomerId: string): Promise<string | null> {
  const { data } = await supabase
    .from('profiles')
    .select('id')
    .eq('stripe_customer_id', stripeCustomerId)
    .single();
  return data?.id ?? null;
}

/**
 * Upsert bank_accounts row and return id.
 */
async function upsertBankAccount(
  supabase: SupabaseClient,
  userId: string,
  stripeAccountId: string,
  details: { institutionName?: string; last4?: string; subcategory?: string }
): Promise<string> {
  const { data: existing } = await supabase
    .from('bank_accounts')
    .select('id')
    .eq('stripe_account_id', stripeAccountId)
    .maybeSingle();

  const row: Record<string, unknown> = {
    user_id: userId,
    stripe_account_id: stripeAccountId,
    institution_name: details.institutionName ?? null,
    last4: details.last4 ?? null,
    subcategory: details.subcategory ?? null,
    updated_at: new Date().toISOString(),
  };

  const existingId = (existing as { id?: string } | null)?.id;
  if (existingId) {
    await supabase.from('bank_accounts').update(row).eq('id', existingId);
    return existingId;
  }

  const { data: inserted } = await supabase
    .from('bank_accounts')
    .insert({ ...row, created_at: new Date().toISOString() })
    .select('id')
    .single();

  const insertedId = (inserted as { id?: string } | null)?.id;
  if (!insertedId) throw new Error('Failed to insert bank_accounts');
  return insertedId;
}

/**
 * Sync transactions for a Financial Connections account into bank_transactions.
 */
async function syncTransactionsForAccount(
  stripeAccount: Stripe.FinancialConnections.Account,
  bankAccountId: string,
  userId: string,
  supabase: SupabaseClient
): Promise<void> {
  if (!stripe) return;

  let hasMore = true;
  let startingAfter: string | undefined;

  while (hasMore) {
    const list = await stripe.financialConnections.transactions.list({
      account: stripeAccount.id,
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
        transacted_at: typeof tx.transacted_at === 'number' ? new Date(tx.transacted_at * 1000).toISOString() : (tx as any).transacted_at ?? new Date().toISOString(),
        category: (tx as any).category ?? null,
        raw_category: (tx as any).raw_category ?? null,
        updated_at: new Date().toISOString(),
      };
      await supabase.from('bank_transactions').upsert(payload as Record<string, unknown>, {
        onConflict: 'bank_account_id,stripe_transaction_id',
        ignoreDuplicates: false,
      });
    }

    hasMore = list.has_more;
    if (list.data.length) startingAfter = list.data[list.data.length - 1].id;
    else hasMore = false;
  }
}

/**
 * Process a single Financial Connections account: upsert bank_accounts, then sync transactions.
 */
async function processAccount(
  supabase: SupabaseClient,
  accountId: string,
  stripeCustomerId: string
): Promise<void> {
  const userId = await getUserIdFromStripeCustomer(supabase, stripeCustomerId);
  if (!userId) {
    logger.warn('Stripe webhook: no user found for customer', { stripeCustomerId, accountId });
    return;
  }

  const stripe = getStripe();
  if (!stripe) return;
  const account = await stripe.financialConnections.accounts.retrieve(accountId);
  const institution = (account as any).institution_name ?? account.display_name ?? null;
  const last4 = (account as any).last4 ?? null;
  const subcategory = (account as any).subcategory ?? null;

  const bankAccountId = await upsertBankAccount(supabase, userId, account.id, {
    institutionName: institution,
    last4,
    subcategory,
  });

  await syncTransactionsForAccount(account, bankAccountId, userId, supabase);
}

export async function handleStripeWebhook(req: Request, res: Response): Promise<void> {
  const requestId = req.requestId || 'unknown';

  if (req.method !== 'POST') {
    res.status(405).end();
    return;
  }

  const webhookSecret = getWebhookSecret();
  if (!webhookSecret) {
    logger.error('STRIPE_WEBHOOK_SECRET not set', { requestId });
    res.status(500).json({ error: 'Webhook not configured' });
    return;
  }

  const stripe = getStripe();
  if (!stripe) {
    logger.error('Stripe not configured for webhook', { requestId });
    res.status(500).json({ error: 'Stripe not configured' });
    return;
  }

  const sig = req.headers['stripe-signature'] as string;
  if (!sig) {
    res.status(400).json({ error: 'Missing stripe-signature' });
    return;
  }

  // req.body is raw Buffer when using express.raw() for this route
  const rawBody = req.body as Buffer;
  if (!rawBody || !Buffer.isBuffer(rawBody)) {
    res.status(400).json({ error: 'Invalid body' });
    return;
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Unknown';
    logger.warn('Stripe webhook signature verification failed', { requestId, error: msg });
    res.status(400).json({ error: `Webhook Error: ${msg}` });
    return;
  }

  const supabase = getSupabaseClient();
  if (!supabase) {
    logger.error('Supabase not configured in webhook', { requestId });
    res.status(500).json({ error: 'Database not configured' });
    return;
  }

  try {
    const eventType = event.type as string;
    if (eventType === 'financial_connections.account.created' || eventType === 'financial_connections.account.refreshed') {
      const account = (event.data as { object: Stripe.FinancialConnections.Account }).object;
      const customerId = typeof account.account_holder === 'string' ? account.account_holder : (account.account_holder as { customer?: string })?.customer ?? (account as any).customer;
      if (customerId) {
        await processAccount(supabase, account.id, customerId);
      }
    }
  } catch (err) {
    logger.error('Stripe webhook processing error', {
      requestId,
      type: event.type,
      error: err instanceof Error ? err.message : 'Unknown',
    });
    res.status(500).json({ error: 'Webhook handler failed' });
    return;
  }

  res.status(200).json({ received: true });
}
