/**
 * Inspect what format we actually receive from Stripe Financial Connections
 * and what we store in Supabase. Run to understand why categorization might fail.
 *
 * Run: npx tsx scripts/inspect-stripe-transaction-format.ts [userId]
 * - If no userId: fetches from Stripe API (needs STRIPE_SECRET_KEY and one linked account).
 * - If userId: reads from Supabase bank_transactions (needs SUPABASE_* in .env).
 */

import * as dotenv from 'dotenv';
dotenv.config();

const userId = process.argv[2]?.trim();

async function fromStripe(): Promise<void> {
  const Stripe = (await import('stripe')).default;
  const key = (process.env.STRIPE_SECRET_KEY ?? '').trim().replace(/^["']|["']$/g, '');
  if (!key.startsWith('sk_')) {
    console.log('STRIPE_SECRET_KEY not set. Skipping Stripe fetch.');
    console.log('To see Stripe format: set STRIPE_SECRET_KEY and ensure you have a linked Financial Connections account.');
    return;
  }
  const stripe = new Stripe(key, { apiVersion: '2025-02-24.acacia' });
  // List accounts to get one account id
  const accounts = await stripe.financialConnections.accounts.list({ limit: 1 });
  if (!accounts.data.length) {
    console.log('No Financial Connections accounts found. Link a bank account first.');
    return;
  }
  const accountId = accounts.data[0].id;
  const list = await stripe.financialConnections.transactions.list({
    account: accountId,
    limit: 5,
  });
  console.log('\n=== STRIPE API: raw transaction object (first 2) ===');
  console.log('Stripe only returns: id, object, account, amount, currency, description, livemode, status, status_transitions, transacted_at, transaction_refresh, updated');
  console.log('There is NO merchant_name and NO raw_category in the API.\n');
  for (let i = 0; i < Math.min(2, list.data.length); i++) {
    const tx = list.data[i];
    console.log(JSON.stringify(tx, null, 2));
    console.log('Keys on tx:', Object.keys(tx));
    console.log('(tx as any).merchant_name:', (tx as any).merchant_name);
    console.log('(tx as any).raw_category:', (tx as any).raw_category);
    console.log('---');
  }
}

async function fromSupabase(uid: string): Promise<void> {
  const { createClient } = await import('@supabase/supabase-js');
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    console.log('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set.');
    return;
  }
  const supabase = createClient(url, key);
  const { data: rows, error } = await supabase
    .from('bank_transactions')
    .select('id, merchant_name, description, amount_cents, category, raw_category, transacted_at')
    .eq('user_id', uid)
    .order('transacted_at', { ascending: false })
    .limit(10);
  if (error) {
    console.error('Supabase error:', error.message);
    return;
  }
  console.log('\n=== SUPABASE bank_transactions (last 10) ===');
  console.log('We store: merchant_name, description, raw_category from Stripe. If Stripe does not send merchant_name/raw_category, they will be null.\n');
  (rows || []).forEach((r: any, i: number) => {
    console.log(`--- Row ${i + 1} ---`);
    console.log('  merchant_name:', r.merchant_name ?? '(null)');
    console.log('  description:', r.description ?? '(null)');
    console.log('  raw_category:', r.raw_category ?? '(null)');
    console.log('  amount_cents:', r.amount_cents);
    console.log('  category (our):', r.category ?? '(null)');
  });
}

async function main(): Promise<void> {
  console.log('ANITA: Inspect Stripe transaction format\n');
  if (userId) {
    await fromSupabase(userId);
  } else {
    await fromStripe();
  }
  console.log('\nConclusion: Categorization uses description (and merchant_name if present).');
  console.log('Stripe only provides "description" (e.g. "Rocket Rides"). Rule-based and AI use that.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
