-- ==============================================================================
-- ADNORA v2.2 — professional performance tier names
-- Run once in Supabase → SQL Editor (safe to re-run).
-- Also includes migration 002 (multiple bills per client per month), in case it
-- has not been run yet.
-- ==============================================================================

-- Tier names: only replaces the old default names, so custom names you typed are kept
UPDATE public.hr_settings SET tier1_name = 'Contributor'   WHERE id = 1 AND tier1_name = 'Rising';
UPDATE public.hr_settings SET tier2_name = 'Performer'     WHERE id = 1 AND tier2_name = 'Achiever';
UPDATE public.hr_settings SET tier3_name = 'Top Performer' WHERE id = 1 AND tier3_name = 'Champion';

ALTER TABLE public.hr_settings ALTER COLUMN tier1_name SET DEFAULT 'Contributor';
ALTER TABLE public.hr_settings ALTER COLUMN tier2_name SET DEFAULT 'Performer';
ALTER TABLE public.hr_settings ALTER COLUMN tier3_name SET DEFAULT 'Top Performer';

-- (from 002) allow more than one bill per client in the same month
DROP INDEX IF EXISTS public.idx_fin_invoices_recurring_period;
CREATE INDEX IF NOT EXISTS idx_fin_invoices_client_period ON public.fin_invoices (client_id, period_month);
