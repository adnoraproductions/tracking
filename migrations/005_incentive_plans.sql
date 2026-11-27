-- ==============================================================================
-- ADNORA v2.4 — role-based incentive plans
-- Run once in Supabase → SQL Editor (safe to re-run).
--
-- Each job role has its own plan: a daily KPI and P1 / P2 / P3 point slabs.
--   Designer : P1 900 · P2 1200 (₹2,000) · P3 1350 (₹3,500) · then a bonus per poster
--   Video    : P1 520 · P2 650 (₹2,500)  · P3 780 (₹5,750)  · then a bonus per 10 points
--   Digital marketer / Project manager: plan to be decided (no slabs yet)
--
-- The per-task bonus beyond P3 lives in its own admin-only table, so employees can
-- never read it — they only see the slab amounts.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.incentive_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  unit_label TEXT NOT NULL DEFAULT 'tasks',      -- shown as "6 more posters"
  unit_points INTEGER NOT NULL DEFAULT 10,        -- points one unit is worth
  daily_points INTEGER,                           -- daily KPI in points (NULL = not set)
  slabs JSONB NOT NULL DEFAULT '[]'::jsonb,       -- [{"level":"P1","min_points":900,"incentive":0}, ...] ascending
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hidden bonus beyond the top slab: amount per `per_points` points (admin only)
CREATE TABLE IF NOT EXISTS public.incentive_plan_bonus (
  plan_id UUID PRIMARY KEY REFERENCES public.incentive_plans(id) ON DELETE CASCADE,
  per_points INTEGER NOT NULL DEFAULT 10 CHECK (per_points > 0),
  amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount >= 0)
);

-- Which plan each employee is on
CREATE TABLE IF NOT EXISTS public.employee_incentive_plans (
  employee_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES public.incentive_plans(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.incentive_plans (key, name, unit_label, unit_points, daily_points, slabs, sort_order) VALUES
  ('designer', 'Designer', 'posters', 10, 30,
    '[{"level":"P1","min_points":900,"incentive":0},{"level":"P2","min_points":1200,"incentive":2000},{"level":"P3","min_points":1350,"incentive":3500}]', 1),
  ('video', 'Video Editor / Videographer', 'edits or shoots', 10, NULL,
    '[{"level":"P1","min_points":520,"incentive":0},{"level":"P2","min_points":650,"incentive":2500},{"level":"P3","min_points":780,"incentive":5750}]', 2),
  ('digital_marketing', 'Digital Marketer', 'tasks', 10, NULL, '[]', 3),
  ('project_manager', 'Project Manager', 'tasks', 10, NULL, '[]', 4)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.incentive_plan_bonus (plan_id, per_points, amount)
SELECT id, 10, CASE key WHEN 'designer' THEN 80 WHEN 'video' THEN 200 END
FROM public.incentive_plans WHERE key IN ('designer', 'video')
ON CONFLICT (plan_id) DO NOTHING;

-- First-time assignment guessed from each person's designation (admins skipped; editable in the app)
INSERT INTO public.employee_incentive_plans (employee_id, plan_id)
SELECT p.id, ip.id
FROM public.profiles p
JOIN public.incentive_plans ip ON ip.key = CASE
    WHEN p.designation ILIKE '%project manager%' THEN 'project_manager'
    WHEN p.designation ILIKE '%marketing%' THEN 'digital_marketing'
    WHEN p.designation ILIKE '%video%' OR p.designation ILIKE '%editor%' OR p.designation ILIKE '%camera%' OR p.designation ILIKE '%shoot%' THEN 'video'
    WHEN p.designation ILIKE '%design%' THEN 'designer'
  END
WHERE p.role::text <> 'admin'
ON CONFLICT (employee_id) DO NOTHING;

ALTER TABLE public.incentive_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incentive_plan_bonus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_incentive_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads incentive plans" ON public.incentive_plans;
CREATE POLICY "Anyone reads incentive plans" ON public.incentive_plans FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "Admins manage incentive plans" ON public.incentive_plans;
CREATE POLICY "Admins manage incentive plans" ON public.incentive_plans FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins only" ON public.incentive_plan_bonus;
CREATE POLICY "Admins only" ON public.incentive_plan_bonus FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Read own plan, managers read all" ON public.employee_incentive_plans;
CREATE POLICY "Read own plan, managers read all" ON public.employee_incentive_plans FOR SELECT USING (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Managers assign plans" ON public.employee_incentive_plans;
CREATE POLICY "Managers assign plans" ON public.employee_incentive_plans FOR ALL USING (public.is_manager()) WITH CHECK (public.is_manager());

DROP TRIGGER IF EXISTS set_timestamp_incentive_plans ON public.incentive_plans;
CREATE TRIGGER set_timestamp_incentive_plans BEFORE UPDATE ON public.incentive_plans FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS set_timestamp_employee_incentive_plans ON public.employee_incentive_plans;
CREATE TRIGGER set_timestamp_employee_incentive_plans BEFORE UPDATE ON public.employee_incentive_plans FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
