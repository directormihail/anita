-- Optional manual run (hosted project already has this via migration `20260322100957_anita_data_archived_after_bank_link`).
-- See: ANITA backend/supabase/migrations/20260322100957_anita_data_archived_after_bank_link.sql

ALTER TABLE public.anita_data
  ADD COLUMN IF NOT EXISTS archived_after_bank_link boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.anita_data.archived_after_bank_link IS
  'When true, manual transaction is retained but excluded from Finance/chat metrics (user uses bank feed).';
