-- ADNORA OS - Supabase Production Database Schema
-- STRICT SECURITY VERSION (Reordered for Fresh Projects)
-- Run this in the Supabase SQL Editor

-- ============================================================================
-- 0. CLEANUP (Drops existing tables so the script can be re-run)
-- ============================================================================
DROP TABLE IF EXISTS public.wifi_config CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.attendance_events CASCADE;
DROP TABLE IF EXISTS public.attendance_sessions CASCADE;
DROP TABLE IF EXISTS public.drive_items CASCADE;
DROP TABLE IF EXISTS public.journal_notes CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;
DROP TABLE IF EXISTS public.project_members CASCADE;
DROP TABLE IF EXISTS public.projects CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.departments CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ============================================================================
-- 1. TABLES & FOREIGN KEYS
-- ============================================================================

-- 1.1 Profiles Table (Linked to auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT DEFAULT 'employee',
  is_active BOOLEAN DEFAULT true,
  onboarding_complete BOOLEAN DEFAULT false,
  avatar_url TEXT,
  phone TEXT,
  department TEXT,
  designation TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.2 Departments
CREATE TABLE public.departments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.3 Clients
CREATE TABLE public.clients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.4 Projects
CREATE TABLE public.projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'planning', -- planning, active, paused, completed
  start_date DATE,
  due_date DATE,
  manager_id UUID REFERENCES public.profiles(id),
  progress INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.5 Project Members
CREATE TABLE public.project_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id, user_id)
);

-- 1.6 Tasks
CREATE TABLE public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
  assignee_id UUID REFERENCES public.profiles(id),
  status TEXT DEFAULT 'todo', -- todo, in_progress, review, done
  priority TEXT DEFAULT 'medium', -- low, medium, high, urgent
  due_date TIMESTAMPTZ,
  checklist JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.7 Journal Notes
CREATE TABLE public.journal_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
  creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_private BOOLEAN DEFAULT false,
  is_pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.8 Drive Items
CREATE TABLE public.drive_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  uploaded_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.9 Attendance Sessions (Daily Records)
CREATE TABLE public.attendance_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  first_clock_in TIMESTAMPTZ,
  last_clock_out TIMESTAMPTZ,
  total_seconds INT DEFAULT 0,
  break_seconds INT DEFAULT 0,
  status TEXT DEFAULT 'active', -- active, completed, absent
  UNIQUE(user_id, date)
);

-- 1.10 Attendance Events (Detailed Logs)
CREATE TABLE public.attendance_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID REFERENCES public.attendance_sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- connect, disconnect
  wifi_ssid TEXT,
  wifi_bssid TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- 1.11 Notifications
CREATE TABLE public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT,
  type TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 1.12 WiFi Configuration
CREATE TABLE public.wifi_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ssid TEXT NOT NULL,
  bssid TEXT,
  label TEXT,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================================
-- 2. HELPER FUNCTIONS
-- ============================================================================

-- Helper Function to check if a user is an admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = user_id AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;


-- ============================================================================
-- 3. ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drive_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_config ENABLE ROW LEVEL SECURITY;


-- ============================================================================
-- 4. RLS POLICIES
-- ============================================================================

-- Profiles
CREATE POLICY "Users can read own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins have full access to profiles" ON public.profiles FOR ALL USING (public.is_admin(auth.uid()));

-- Departments
CREATE POLICY "Employees can view departments" ON public.departments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admins have full access to departments" ON public.departments FOR ALL USING (public.is_admin(auth.uid()));

-- Clients
CREATE POLICY "Admins have full access to clients" ON public.clients FOR ALL USING (public.is_admin(auth.uid()));

-- Projects
CREATE POLICY "Project members can view projects" ON public.projects FOR SELECT USING (
  id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
  public.is_admin(auth.uid())
);
CREATE POLICY "Admins have full access to projects" ON public.projects FOR ALL USING (public.is_admin(auth.uid()));

-- Project Members
CREATE POLICY "Project members can view project members" ON public.project_members FOR SELECT USING (
  auth.uid() = user_id OR 
  project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
  public.is_admin(auth.uid())
);
CREATE POLICY "Admins have full access to project members" ON public.project_members FOR ALL USING (public.is_admin(auth.uid()));

-- Tasks
CREATE POLICY "Assigned users can view tasks" ON public.tasks FOR SELECT USING (
  assignee_id = auth.uid() OR 
  project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
  public.is_admin(auth.uid())
);
CREATE POLICY "Assigned users can update tasks" ON public.tasks FOR UPDATE USING (
  assignee_id = auth.uid() OR public.is_admin(auth.uid())
);
CREATE POLICY "Admins have full access to tasks" ON public.tasks FOR ALL USING (public.is_admin(auth.uid()));

-- Journal Notes
CREATE POLICY "View journal notes" ON public.journal_notes FOR SELECT USING (
  (is_private = false AND project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid())) OR
  (is_private = true AND creator_id = auth.uid()) OR
  public.is_admin(auth.uid())
);
CREATE POLICY "Users can create journal notes" ON public.journal_notes FOR INSERT WITH CHECK (
  creator_id = auth.uid() AND (project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR public.is_admin(auth.uid()))
);
CREATE POLICY "Users can update own journal notes" ON public.journal_notes FOR UPDATE USING (creator_id = auth.uid() OR public.is_admin(auth.uid()));

-- Drive Items
CREATE POLICY "Project members can view drive items" ON public.drive_items FOR SELECT USING (
  project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR
  public.is_admin(auth.uid())
);
CREATE POLICY "Project members can upload drive items" ON public.drive_items FOR INSERT WITH CHECK (
  uploaded_by = auth.uid() AND (project_id IN (SELECT project_id FROM public.project_members WHERE user_id = auth.uid()) OR public.is_admin(auth.uid()))
);

-- Attendance Sessions
CREATE POLICY "Users view own attendance" ON public.attendance_sessions FOR SELECT USING (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Users manage own attendance" ON public.attendance_sessions FOR INSERT WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Users update own attendance" ON public.attendance_sessions FOR UPDATE USING (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Admins full attendance" ON public.attendance_sessions FOR ALL USING (public.is_admin(auth.uid()));

-- Attendance Events
CREATE POLICY "Users view own attendance events" ON public.attendance_events FOR SELECT USING (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Users insert own attendance events" ON public.attendance_events FOR INSERT WITH CHECK (user_id = auth.uid() OR public.is_admin(auth.uid()));

-- Notifications
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (user_id = auth.uid() OR public.is_admin(auth.uid()));
CREATE POLICY "Admins full notifications" ON public.notifications FOR ALL USING (public.is_admin(auth.uid()));

-- WiFi Configuration
CREATE POLICY "Employees can view wifi configs" ON public.wifi_config FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can manage wifi configs" ON public.wifi_config FOR ALL USING (public.is_admin(auth.uid()));


-- ============================================================================
-- 5. TRIGGER FUNCTIONS
-- ============================================================================

-- 5.1 Auto-create profile for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', 'User'), 
    CASE WHEN new.email = 'abijithar.i8@gmail.com' THEN 'admin' ELSE 'employee' END
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.2 Prevent Privilege Escalation via Role Modification
CREATE OR REPLACE FUNCTION public.protect_role_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow dashboard (postgres) or service_role to bypass this check
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN NEW;
  END IF;

  -- If the role is being changed, verify the user is an admin
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF NOT public.is_admin(auth.uid()) THEN
      RAISE EXCEPTION 'Privilege escalation attempt detected. Only admins can modify roles.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 6. TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

DROP TRIGGER IF EXISTS enforce_role_protection ON public.profiles;
CREATE TRIGGER enforce_role_protection
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.protect_role_escalation();

-- ============================================================================
-- 7. PERMISSION GRANTS (Required for App Access)
-- ============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;



