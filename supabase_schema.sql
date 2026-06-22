-- ==============================================================================
-- ADNORA CORE DATABASE SCHEMA
-- Note: Execute this entire script first. No RLS is included in this file.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CUSTOM ENUMS
-- ------------------------------------------------------------------------------
CREATE TYPE public.user_role AS ENUM ('admin', 'employee');
CREATE TYPE public.profile_status AS ENUM ('active', 'inactive');
CREATE TYPE public.work_mode_type AS ENUM ('permanent_office', 'permanent_wfh', 'hybrid', 'temporary_wfh');
CREATE TYPE public.attendance_day_status AS ENUM ('present', 'absent', 'half_day', 'on_leave');
CREATE TYPE public.session_type AS ENUM ('office', 'field_work', 'wfh');
CREATE TYPE public.session_status AS ENUM ('working', 'on_break', 'ended', 'auto_closed');
CREATE TYPE public.event_type AS ENUM ('session_started', 'break_out', 'break_in', 'session_ended', 'day_ended', 'auto_closed', 'correction_requested', 'correction_approved');
CREATE TYPE public.correction_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE public.leave_type AS ENUM ('casual', 'sick', 'lop');
CREATE TYPE public.leave_status AS ENUM ('approved');

-- ------------------------------------------------------------------------------
-- 2. TABLES
-- ------------------------------------------------------------------------------

-- Departments
CREATE TABLE public.departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- App Settings (Singleton conceptual)
CREATE TABLE public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL DEFAULT 'Adnora',
    default_geofence_radius INTEGER NOT NULL DEFAULT 100,
    auto_close_hour TIME NOT NULL DEFAULT '08:00',
    allow_multiple_devices BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Profiles (Tied to Supabase Auth)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_code TEXT UNIQUE, -- e.g., AD001
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    dob DATE,
    role user_role NOT NULL DEFAULT 'employee',
    status profile_status NOT NULL DEFAULT 'active',
    department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
    designation TEXT,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Office Settings
CREATE TABLE public.office_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius INTEGER NOT NULL DEFAULT 100,
    is_active BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Employee Work Modes
CREATE TABLE public.employee_work_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mode work_mode_type NOT NULL,
    start_date DATE,
    end_date DATE,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Employee Leaves (Admin Managed)
CREATE TABLE public.employee_leaves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leave_type leave_type NOT NULL,
    status leave_status NOT NULL DEFAULT 'approved',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Attendance Days
CREATE TABLE public.attendance_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status attendance_day_status NOT NULL DEFAULT 'present',
    total_work_minutes INTEGER DEFAULT 0,
    total_break_minutes INTEGER DEFAULT 0,
    total_overtime_minutes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, date)
);

-- Work Sessions
CREATE TABLE public.work_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_day_id UUID NOT NULL REFERENCES public.attendance_days(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_type session_type NOT NULL,
    status session_status NOT NULL DEFAULT 'working',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    start_latitude DOUBLE PRECISION,
    start_longitude DOUBLE PRECISION,
    end_latitude DOUBLE PRECISION,
    end_longitude DOUBLE PRECISION
);

-- Session Breaks
CREATE TABLE public.session_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_session_id UUID NOT NULL REFERENCES public.work_sessions(id) ON DELETE CASCADE,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    start_latitude DOUBLE PRECISION,
    start_longitude DOUBLE PRECISION,
    end_latitude DOUBLE PRECISION,
    end_longitude DOUBLE PRECISION
);

-- Attendance Events (Immutable Audit)
CREATE TABLE public.attendance_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_day_id UUID NOT NULL REFERENCES public.attendance_days(id) ON DELETE CASCADE,
    event_type event_type NOT NULL,
    session_type session_type,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Attendance Corrections
CREATE TABLE public.attendance_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_day_id UUID NOT NULL REFERENCES public.attendance_days(id) ON DELETE CASCADE,
    work_session_id UUID REFERENCES public.work_sessions(id) ON DELETE CASCADE,
    status correction_status NOT NULL DEFAULT 'pending',
    reason TEXT NOT NULL,
    admin_notes TEXT,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Holidays
CREATE TABLE public.holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    date DATE NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Activity Logs (Immutable)
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_role TEXT,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notifications
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Device Sessions
CREATE TABLE public.device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_name TEXT,
    browser TEXT,
    platform TEXT,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. INDEXES
-- ------------------------------------------------------------------------------
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_attendance_days_emp_date ON public.attendance_days(employee_id, date);
CREATE INDEX idx_work_sessions_day ON public.work_sessions(attendance_day_id);
CREATE INDEX idx_work_sessions_employee ON public.work_sessions(employee_id);
CREATE INDEX idx_attendance_events_emp_time ON public.attendance_events(employee_id, timestamp);
CREATE INDEX idx_activity_logs_entity ON public.activity_logs(entity_type, entity_id);
CREATE INDEX idx_notifications_user ON public.notifications(user_id, is_read);
CREATE INDEX idx_device_sessions_user ON public.device_sessions(user_id, last_seen);
CREATE INDEX idx_employee_leaves_emp ON public.employee_leaves(employee_id);

-- Enforce Single Active Office Rule at Postgres level
CREATE UNIQUE INDEX idx_single_active_office ON public.office_settings (is_active) WHERE is_active = true;

-- ------------------------------------------------------------------------------
-- 4. FUNCTIONS & TRIGGERS
-- ------------------------------------------------------------------------------

-- Generic Updated_At Trigger Function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply generic triggers
CREATE TRIGGER set_timestamp_profiles BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_timestamp_departments BEFORE UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_timestamp_app_settings BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_timestamp_office_settings BEFORE UPDATE ON public.office_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_timestamp_employee_work_modes BEFORE UPDATE ON public.employee_work_modes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_timestamp_attendance_corrections BEFORE UPDATE ON public.attendance_corrections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- IS_ADMIN Helper Function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- ROLE ESCALATION PROTECTION (Patched for Admin Bootstrap)
CREATE OR REPLACE FUNCTION public.protect_role_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Bypass trigger checks for internal database operations (SQL Editor / Service Role).
  -- In these backend contexts, no JWT is present, so auth.uid() is reliably NULL.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Block standard API clients from updating protected fields unless they are Admins
  IF NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Unauthorized attempt to modify protected profile fields';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER check_role_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_role_escalation();

-- Auto-create profile on auth.user signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Employee'), 'employee');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
A L T E R   T A B L E   p u b l i c . o f f i c e _ s e t t i n g s   A D D   C O L U M N   I F   N O T   E X I S T S   w o r k _ t a r g e t _ h o u r s   N U M E R I C ( 4 , 2 )   D E F A U L T   8 . 0 ;  
 