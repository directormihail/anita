-- Stripe Financial Connections: bank_accounts, bank_transactions, and stripe_customer_id on profiles
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query) before using SFC.

-- 1) Add stripe_customer_id to profiles (for linking Stripe Customer to ANITA user)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS stripe_customer_id text;

COMMENT ON COLUMN profiles.stripe_customer_id IS 'Stripe Customer ID for Financial Connections / checkout';

-- 2) Bank accounts linked via Stripe Financial Connections
CREATE TABLE IF NOT EXISTS bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_account_id text NOT NULL UNIQUE,
  institution_name text,
  last4 text,
  subcategory text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, stripe_account_id)
);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_user_id ON bank_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_stripe_account_id ON bank_accounts(stripe_account_id);

-- 3) Transactions from linked bank accounts (synced via Stripe webhooks / refresh)
CREATE TABLE IF NOT EXISTS bank_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,
  stripe_transaction_id text,
  amount_cents bigint NOT NULL,
  currency text DEFAULT 'usd',
  description text,
  merchant_name text,
  transacted_at timestamptz NOT NULL,
  category text,
  raw_category text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(bank_account_id, stripe_transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_bank_transactions_user_id ON bank_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_bank_account_id ON bank_transactions(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_transacted_at ON bank_transactions(transacted_at);

-- RLS (optional but recommended): ensure users only see their own data
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bank_accounts_select_own ON bank_accounts;
CREATE POLICY bank_accounts_select_own ON bank_accounts
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS bank_accounts_insert_own ON bank_accounts;
CREATE POLICY bank_accounts_insert_own ON bank_accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS bank_transactions_select_own ON bank_transactions;
CREATE POLICY bank_transactions_select_own ON bank_transactions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS bank_transactions_insert_own ON bank_transactions;
CREATE POLICY bank_transactions_insert_own ON bank_transactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Backend uses service role, so RLS is bypassed; these policies protect direct Supabase client access.
