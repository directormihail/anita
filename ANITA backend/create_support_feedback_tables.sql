-- =============================================================================
-- ANITA: Support table (required for Settings → Support in the app)
-- Run this in Supabase → SQL Editor if you see "Failed to submit support request".
-- =============================================================================

-- Support requests from Settings → Support (iOS + web)
CREATE TABLE IF NOT EXISTS public.user_support_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  subject TEXT,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_support_requests_user_id ON public.user_support_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_user_support_requests_created_at ON public.user_support_requests(created_at DESC);

ALTER TABLE public.user_support_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert own support request" ON public.user_support_requests;
CREATE POLICY "Users can insert own support request"
  ON public.user_support_requests FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

-- Note: user_feedback is created by webapp migration 20241220000016_create_user_feedback.sql.
-- Backend and iOS use that same table; no need to create it here.
