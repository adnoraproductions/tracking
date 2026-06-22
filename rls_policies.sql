-- ==============================================================================
-- ADNORA RLS POLICIES
-- Note: Execute this AFTER supabase_schema.sql
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.office_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_work_modes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_sessions ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- GLOBAL DATA (Read by all authenticated users, managed by Admins)
-- ==============================================================================
CREATE POLICY "Anyone can view departments" ON public.departments FOR SELECT USING (true);
CREATE POLICY "Admins manage departments" ON public.departments FOR ALL USING (public.is_admin());

CREATE POLICY "Anyone can view app settings" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Admins manage app settings" ON public.app_settings FOR ALL USING (public.is_admin());

CREATE POLICY "Anyone can view active office" ON public.office_settings FOR SELECT USING (true);
CREATE POLICY "Admins manage offices" ON public.office_settings FOR ALL USING (public.is_admin());

CREATE POLICY "Anyone can view holidays" ON public.holidays FOR SELECT USING (true);
CREATE POLICY "Admins manage holidays" ON public.holidays FOR ALL USING (public.is_admin());

-- ==============================================================================
-- PROFILES 
-- ==============================================================================
CREATE POLICY "Users view own profile, Admins view all" ON public.profiles FOR SELECT USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Admins can update all profiles" ON public.profiles FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "Admins can insert profiles" ON public.profiles FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "Admins can delete profiles" ON public.profiles FOR DELETE USING (public.is_admin());

-- ==============================================================================
-- EMPLOYEE DATA (Work Modes, Leaves)
-- ==============================================================================
CREATE POLICY "Users view own work modes" ON public.employee_work_modes FOR SELECT USING (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Admins manage work modes" ON public.employee_work_modes FOR ALL USING (public.is_admin());

CREATE POLICY "Users view own leaves" ON public.employee_leaves FOR SELECT USING (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Admins manage leaves" ON public.employee_leaves FOR ALL USING (public.is_admin());

-- ==============================================================================
-- ATTENDANCE ENGINE (Days, Sessions, Breaks)
-- ==============================================================================
CREATE POLICY "Users manage own attendance days" ON public.attendance_days FOR ALL USING (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Users manage own work sessions" ON public.work_sessions FOR ALL USING (auth.uid() = employee_id OR public.is_admin());

-- Session Breaks (Requires subquery to match session owner)
CREATE POLICY "Users view own breaks" ON public.session_breaks FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.work_sessions WHERE id = work_session_id AND (employee_id = auth.uid() OR public.is_admin()))
);
CREATE POLICY "Users insert own breaks" ON public.session_breaks FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.work_sessions WHERE id = work_session_id AND employee_id = auth.uid())
    OR public.is_admin()
);
CREATE POLICY "Users update own breaks" ON public.session_breaks FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.work_sessions WHERE id = work_session_id AND (employee_id = auth.uid() OR public.is_admin()))
) WITH CHECK (
    EXISTS (SELECT 1 FROM public.work_sessions WHERE id = work_session_id AND (employee_id = auth.uid() OR public.is_admin()))
);
CREATE POLICY "Users delete own breaks" ON public.session_breaks FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.work_sessions WHERE id = work_session_id AND (employee_id = auth.uid() OR public.is_admin()))
);

-- ==============================================================================
-- IMMUTABLE AUDIT LOGS (No UPDATE or DELETE allowed for ANYONE)
-- ==============================================================================
-- Attendance Events
CREATE POLICY "Users view own events, Admins view all" ON public.attendance_events FOR SELECT USING (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Users insert own events, Admins insert any" ON public.attendance_events FOR INSERT WITH CHECK (auth.uid() = employee_id OR public.is_admin());

-- Activity Logs
CREATE POLICY "Admins view all activity logs" ON public.activity_logs FOR SELECT USING (public.is_admin());
CREATE POLICY "Authenticated users can insert activity logs" ON public.activity_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ==============================================================================
-- ATTENDANCE CORRECTIONS (Employees Insert/Select, Admins manage all)
-- ==============================================================================
CREATE POLICY "Users view own corrections" ON public.attendance_corrections FOR SELECT USING (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Users insert own corrections" ON public.attendance_corrections FOR INSERT WITH CHECK (auth.uid() = employee_id OR public.is_admin());
CREATE POLICY "Admins update corrections" ON public.attendance_corrections FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "Admins delete corrections" ON public.attendance_corrections FOR DELETE USING (public.is_admin());

-- ==============================================================================
-- NOTIFICATIONS
-- ==============================================================================
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "Admins can insert notifications" ON public.notifications FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "Admins can delete notifications" ON public.notifications FOR DELETE USING (public.is_admin());

-- ==============================================================================
-- DEVICE SESSIONS
-- ==============================================================================
CREATE POLICY "Users manage own device sessions" ON public.device_sessions FOR ALL USING (auth.uid() = user_id OR public.is_admin());
