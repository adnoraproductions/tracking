-- ==============================================================================
-- ADNORA v2.1 — allow more than one bill per client in the same month
-- Run once in Supabase → SQL Editor (safe to re-run).
-- ==============================================================================
DROP INDEX IF EXISTS public.idx_fin_invoices_recurring_period;

-- Plain (non-unique) index for month lookups
CREATE INDEX IF NOT EXISTS idx_fin_invoices_client_period ON public.fin_invoices (client_id, period_month);
