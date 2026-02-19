-- Create user_subscriptions table for iOS In-App Purchase (StoreKit) and web subscription tracking.
-- Run this in Supabase SQL Editor if the table does not exist.

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired')),
  transaction_id TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Optional: RLS policies (adjust to your auth model)
-- ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can read own subscription" ON public.user_subscriptions FOR SELECT USING (auth.uid() = user_id);
-- Service role (backend) can insert/update via SUPABASE_SERVICE_ROLE_KEY.

COMMENT ON TABLE public.user_subscriptions IS 'Stores subscription plan per user (iOS IAP and web)';
