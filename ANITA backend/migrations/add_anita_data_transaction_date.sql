-- =============================================================================
-- ANITA: Add transaction_date to anita_data so user-intended date is preserved
-- Run in Supabase → SQL Editor once. Required for transfers/goals to persist
-- and show after app reload.
-- =============================================================================

-- Add column if not present (safe to run multiple times)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'anita_data'
      AND column_name = 'transaction_date'
  ) THEN
    ALTER TABLE public.anita_data
    ADD COLUMN transaction_date TIMESTAMPTZ NULL;
    COMMENT ON COLUMN public.anita_data.transaction_date IS 'User-intended date for the transaction (used for month filter); if NULL, created_at is used.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_anita_data_transaction_date
  ON public.anita_data (transaction_date)
  WHERE transaction_date IS NOT NULL;
