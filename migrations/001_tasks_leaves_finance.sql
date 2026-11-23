-- ==============================================================================
-- ADNORA v2 — Daily Tasks & Performance, Leave Requests, Finance & Payroll
-- Run this ONCE in Supabase → SQL Editor (safe to re-run; everything is idempotent).
-- Does not modify or remove any existing attendance table or function.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. ROLES: add a "manager" (project manager) role + helper
-- ------------------------------------------------------------------------------
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'manager';

-- Text comparison so this works in the same transaction as ADD VALUE above
CREATE OR REPLACE FUNCTION public.is_manager()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role::text IN ('admin', 'manager'));
$$;

-- Managers need to see employee names when approving
DROP POLICY IF EXISTS "Managers view all profiles" ON public.profiles;
CREATE POLICY "Managers view all profiles" ON public.profiles FOR SELECT USING (public.is_manager());

-- ------------------------------------------------------------------------------
-- 1. HR SETTINGS (single row): leave rules, performance tiers, incentive
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hr_settings (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  paid_casual_per_month NUMERIC(4,1) NOT NULL DEFAULT 1,
  paid_emergency_per_month NUMERIC(4,1) NOT NULL DEFAULT 1,
  casual_notice_days INTEGER NOT NULL DEFAULT 1,
  tier1_name TEXT NOT NULL DEFAULT 'Contributor',
  tier2_name TEXT NOT NULL DEFAULT 'Performer',
  tier3_name TEXT NOT NULL DEFAULT 'Top Performer',
  tier2_min_points INTEGER NOT NULL DEFAULT 100,
  tier3_min_points INTEGER NOT NULL DEFAULT 200,
  incentive_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  working_days_per_week INTEGER NOT NULL DEFAULT 6 CHECK (working_days_per_week IN (5, 6, 7)),
  currency TEXT NOT NULL DEFAULT 'INR',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO public.hr_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.hr_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone reads hr settings" ON public.hr_settings;
CREATE POLICY "Anyone reads hr settings" ON public.hr_settings FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "Admins manage hr settings" ON public.hr_settings;
CREATE POLICY "Admins manage hr settings" ON public.hr_settings FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ------------------------------------------------------------------------------
-- 2. DAILY TASKS & PERFORMANCE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.task_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  points INTEGER NOT NULL DEFAULT 10 CHECK (points >= 0),
  is_minor BOOLEAN NOT NULL DEFAULT false,   -- small fixes / corrections
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.task_categories (name, points, is_minor, sort_order) VALUES
  ('Poster Design', 10, false, 1),
  ('Video Editing', 10, false, 2),
  ('Shooting', 10, false, 3),
  ('Logo Design', 20, false, 4),
  ('Small Fix / Correction', 5, true, 5)
ON CONFLICT (name) DO NOTHING;

-- Minimum monthly KPI per employee per category
CREATE TABLE IF NOT EXISTS public.employee_kpis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.task_categories(id) ON DELETE CASCADE,
  monthly_target INTEGER NOT NULL DEFAULT 0 CHECK (monthly_target >= 0),
  UNIQUE (employee_id, category_id)
);

CREATE TABLE IF NOT EXISTS public.daily_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  task_date DATE NOT NULL DEFAULT CURRENT_DATE,
  category_id UUID NOT NULL REFERENCES public.task_categories(id),
  title TEXT NOT NULL,
  client_name TEXT,
  link TEXT,
  notes TEXT,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 100),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'approved', 'rejected')),
  points_awarded INTEGER NOT NULL DEFAULT 0,
  submitted_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_daily_tasks_emp_date ON public.daily_tasks (employee_id, task_date);
CREATE INDEX IF NOT EXISTS idx_daily_tasks_status ON public.daily_tasks (status);

-- Guard: only managers/admins approve; points are calculated by the database
CREATE OR REPLACE FUNCTION public.daily_tasks_guard()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_points INTEGER;
BEGIN
  NEW.updated_at := NOW();
  IF auth.uid() IS NOT NULL AND NOT public.is_manager() THEN
    IF TG_OP = 'UPDATE' AND OLD.status = 'approved' THEN
      RAISE EXCEPTION 'Approved tasks cannot be edited';
    END IF;
    IF NEW.status IN ('approved', 'rejected') THEN
      RAISE EXCEPTION 'Only a project manager or admin can approve tasks';
    END IF;
    NEW.employee_id := auth.uid();
    NEW.reviewed_by := NULL; NEW.reviewed_at := NULL;
  END IF;

  IF NEW.status = 'pending' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'pending') THEN
    NEW.submitted_at := NOW();
    NEW.review_note := NULL;
  END IF;

  IF NEW.status = 'approved' THEN
    IF TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'approved' OR OLD.quantity <> NEW.quantity OR OLD.category_id <> NEW.category_id THEN
      SELECT points INTO v_points FROM public.task_categories WHERE id = NEW.category_id;
      NEW.points_awarded := COALESCE(v_points, 0) * NEW.quantity;
      NEW.reviewed_by := auth.uid();
      NEW.reviewed_at := NOW();
    END IF;
  ELSE
    NEW.points_awarded := 0;
    IF NEW.status = 'rejected' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'rejected') THEN
      NEW.reviewed_by := auth.uid();
      NEW.reviewed_at := NOW();
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_daily_tasks_guard ON public.daily_tasks;
CREATE TRIGGER trg_daily_tasks_guard BEFORE INSERT OR UPDATE ON public.daily_tasks
  FOR EACH ROW EXECUTE FUNCTION public.daily_tasks_guard();

ALTER TABLE public.task_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_kpis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads task categories" ON public.task_categories;
CREATE POLICY "Anyone reads task categories" ON public.task_categories FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "Admins manage task categories" ON public.task_categories;
CREATE POLICY "Admins manage task categories" ON public.task_categories FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Read own kpis, managers read all" ON public.employee_kpis;
CREATE POLICY "Read own kpis, managers read all" ON public.employee_kpis FOR SELECT USING (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Managers manage kpis" ON public.employee_kpis;
CREATE POLICY "Managers manage kpis" ON public.employee_kpis FOR ALL USING (public.is_manager()) WITH CHECK (public.is_manager());

DROP POLICY IF EXISTS "Read own tasks, managers read all" ON public.daily_tasks;
CREATE POLICY "Read own tasks, managers read all" ON public.daily_tasks FOR SELECT USING (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Insert own tasks" ON public.daily_tasks;
CREATE POLICY "Insert own tasks" ON public.daily_tasks FOR INSERT WITH CHECK (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Update own open tasks, managers all" ON public.daily_tasks;
CREATE POLICY "Update own open tasks, managers all" ON public.daily_tasks FOR UPDATE
  USING ((employee_id = auth.uid() AND status <> 'approved') OR public.is_manager())
  WITH CHECK (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Delete own open tasks, managers all" ON public.daily_tasks;
CREATE POLICY "Delete own open tasks, managers all" ON public.daily_tasks FOR DELETE
  USING ((employee_id = auth.uid() AND status <> 'approved') OR public.is_manager());

-- ------------------------------------------------------------------------------
-- 3. LEAVE REQUESTS
--    1 paid casual + 1 paid emergency per month (configurable in hr_settings).
--    Casual leave must be applied at least `casual_notice_days` before the leave.
--    Anything beyond the monthly allowance is automatically counted as unpaid.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  leave_type TEXT NOT NULL CHECK (leave_type IN ('casual', 'emergency', 'unpaid')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  half_day BOOLEAN NOT NULL DEFAULT false,
  days NUMERIC(5,1) NOT NULL DEFAULT 0,
  paid_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  unpaid_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS idx_leave_requests_emp ON public.leave_requests (employee_id, start_date);

-- Count working days in a range (skips Sundays when 6-day week, Sat+Sun for 5-day week, and holidays)
CREATE OR REPLACE FUNCTION public.count_leave_days(p_start DATE, p_end DATE)
RETURNS NUMERIC LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_week INTEGER; v_count NUMERIC;
BEGIN
  SELECT working_days_per_week INTO v_week FROM public.hr_settings WHERE id = 1;
  SELECT COUNT(*) INTO v_count
  FROM generate_series(p_start, p_end, INTERVAL '1 day') AS d
  WHERE NOT (COALESCE(v_week, 6) = 6 AND EXTRACT(ISODOW FROM d) = 7)
    AND NOT (COALESCE(v_week, 6) = 5 AND EXTRACT(ISODOW FROM d) IN (6, 7))
    AND NOT EXISTS (SELECT 1 FROM public.holidays h WHERE h.date = d::date);
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_requests_guard()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  s public.hr_settings%ROWTYPE;
  v_allow NUMERIC; v_used NUMERIC; v_mgr BOOLEAN := public.is_manager();
  v_recalc BOOLEAN := false;
BEGIN
  SELECT * INTO s FROM public.hr_settings WHERE id = 1;

  IF TG_OP = 'INSERT' THEN
    IF auth.uid() IS NOT NULL AND NOT v_mgr THEN
      NEW.employee_id := auth.uid();
      NEW.status := 'pending';
      IF NEW.leave_type = 'casual' AND NEW.start_date < CURRENT_DATE + COALESCE(s.casual_notice_days, 1) THEN
        RAISE EXCEPTION 'Casual leave must be applied at least % day(s) in advance. Use Emergency leave for urgent needs.', COALESCE(s.casual_notice_days, 1);
      END IF;
    END IF;
    IF NEW.half_day THEN NEW.end_date := NEW.start_date; END IF;
    v_recalc := true;
  ELSE
    -- employees may only cancel their own pending request
    IF auth.uid() IS NOT NULL AND NOT v_mgr THEN
      IF NOT (OLD.status = 'pending' AND NEW.status = 'cancelled') THEN
        RAISE EXCEPTION 'You can only cancel a pending leave request';
      END IF;
      RETURN NEW;
    END IF;
    IF NEW.status IN ('approved', 'rejected') AND OLD.status IS DISTINCT FROM NEW.status THEN
      NEW.reviewed_by := auth.uid();
      NEW.reviewed_at := NOW();
    END IF;
    v_recalc := (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
             OR NEW.start_date <> OLD.start_date OR NEW.end_date <> OLD.end_date
             OR NEW.half_day <> OLD.half_day OR NEW.leave_type <> OLD.leave_type;
  END IF;

  IF v_recalc THEN
    NEW.days := CASE WHEN NEW.half_day THEN 0.5 ELSE public.count_leave_days(NEW.start_date, NEW.end_date) END;
    IF NEW.days <= 0 THEN
      RAISE EXCEPTION 'Selected dates contain no working days';
    END IF;
    v_allow := CASE NEW.leave_type
                 WHEN 'casual' THEN COALESCE(s.paid_casual_per_month, 1)
                 WHEN 'emergency' THEN COALESCE(s.paid_emergency_per_month, 1)
                 ELSE 0 END;
    -- paid days already used this month (pending + approved while applying; approved only when approving)
    SELECT COALESCE(SUM(paid_days), 0) INTO v_used
    FROM public.leave_requests
    WHERE employee_id = NEW.employee_id
      AND leave_type = NEW.leave_type
      AND id <> NEW.id
      AND date_trunc('month', start_date) = date_trunc('month', NEW.start_date)
      AND status = ANY (CASE WHEN NEW.status = 'approved' THEN ARRAY['approved'] ELSE ARRAY['pending', 'approved'] END);
    NEW.paid_days := LEAST(NEW.days, GREATEST(v_allow - v_used, 0));
    NEW.unpaid_days := NEW.days - NEW.paid_days;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_leave_requests_guard ON public.leave_requests;
CREATE TRIGGER trg_leave_requests_guard BEFORE INSERT OR UPDATE ON public.leave_requests
  FOR EACH ROW EXECUTE FUNCTION public.leave_requests_guard();

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Read own leaves, managers read all" ON public.leave_requests;
CREATE POLICY "Read own leaves, managers read all" ON public.leave_requests FOR SELECT USING (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Apply own leave" ON public.leave_requests;
CREATE POLICY "Apply own leave" ON public.leave_requests FOR INSERT WITH CHECK (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Cancel own leave, managers review" ON public.leave_requests;
CREATE POLICY "Cancel own leave, managers review" ON public.leave_requests FOR UPDATE
  USING (employee_id = auth.uid() OR public.is_manager()) WITH CHECK (employee_id = auth.uid() OR public.is_manager());
DROP POLICY IF EXISTS "Admins delete leaves" ON public.leave_requests;
CREATE POLICY "Admins delete leaves" ON public.leave_requests FOR DELETE USING (public.is_admin());

-- ------------------------------------------------------------------------------
-- 4. FINANCE (admin only): clients, invoices, payments received, expenses, payroll
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fin_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  client_type TEXT NOT NULL DEFAULT 'recurring' CHECK (client_type IN ('recurring', 'one_time')),
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  services TEXT,
  monthly_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
  billing_day INTEGER NOT NULL DEFAULT 1 CHECK (billing_day BETWEEN 1 AND 28),
  start_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fin_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.fin_clients(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  period_month DATE,                      -- first day of the billed month (recurring)
  issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  is_cancelled BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_fin_invoices_recurring_period
  ON public.fin_invoices (client_id, period_month) WHERE period_month IS NOT NULL AND NOT is_cancelled;

CREATE TABLE IF NOT EXISTS public.fin_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.fin_clients(id) ON DELETE CASCADE,
  invoice_id UUID REFERENCES public.fin_invoices(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  paid_on DATE NOT NULL DEFAULT CURRENT_DATE,
  method TEXT,
  reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fin_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  category TEXT NOT NULL,
  vendor TEXT,
  description TEXT,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  method TEXT,
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.employee_salaries (
  employee_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  monthly_salary NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payroll_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  month DATE NOT NULL,                    -- first day of month
  base_salary NUMERIC(12,2) NOT NULL DEFAULT 0,
  working_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  present_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  paid_leave_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  unpaid_days NUMERIC(5,1) NOT NULL DEFAULT 0,
  attendance_deduction NUMERIC(12,2) NOT NULL DEFAULT 0,
  points INTEGER NOT NULL DEFAULT 0,
  tier TEXT,
  incentive NUMERIC(12,2) NOT NULL DEFAULT 0,
  bonus NUMERIC(12,2) NOT NULL DEFAULT 0,
  other_deduction NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_pay NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'paid')),
  paid_on DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (employee_id, month)
);

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['fin_clients', 'fin_invoices', 'fin_payments', 'fin_expenses', 'employee_salaries', 'payroll_records'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "Admins only" ON public.%I', t);
    EXECUTE format('CREATE POLICY "Admins only" ON public.%I FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin())', t);
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS set_timestamp_fin_invoices ON public.fin_invoices;
CREATE TRIGGER set_timestamp_fin_invoices BEFORE UPDATE ON public.fin_invoices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS set_timestamp_payroll_records ON public.payroll_records;
CREATE TRIGGER set_timestamp_payroll_records BEFORE UPDATE ON public.payroll_records FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS set_timestamp_employee_salaries ON public.employee_salaries;
CREATE TRIGGER set_timestamp_employee_salaries BEFORE UPDATE ON public.employee_salaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
