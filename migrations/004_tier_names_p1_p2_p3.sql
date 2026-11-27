-- ==============================================================================
-- ADNORA v2.3 — performance levels named P1 / P2 / P3
-- P1 = starting level, P2 = middle level, P3 = top level (earns the incentive)
-- Run once in Supabase → SQL Editor (safe to re-run).
-- ==============================================================================
UPDATE public.hr_settings
SET tier1_name = 'P1', tier2_name = 'P2', tier3_name = 'P3', updated_at = NOW()
WHERE id = 1;

ALTER TABLE public.hr_settings ALTER COLUMN tier1_name SET DEFAULT 'P1';
ALTER TABLE public.hr_settings ALTER COLUMN tier2_name SET DEFAULT 'P2';
ALTER TABLE public.hr_settings ALTER COLUMN tier3_name SET DEFAULT 'P3';
