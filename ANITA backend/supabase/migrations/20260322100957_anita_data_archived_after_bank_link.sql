-- Applied to hosted ANITA project via Supabase MCP (kezregiqfxlrvaxytdet).
-- Keep manual transaction rows in DB but hide them from app/API after user links a bank.

ALTER TABLE public.anita_data
  ADD COLUMN IF NOT EXISTS archived_after_bank_link boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.anita_data.archived_after_bank_link IS
  'When true, manual transaction is retained but excluded from Finance/chat metrics (user uses bank feed).';
