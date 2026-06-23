-- ==============================================================================
-- ADNORA ATTENDANCE RPCs
-- Run this in your Supabase SQL Editor to enable transactional attendance logic.
-- ==============================================================================

-- 1. START SESSION
CREATE OR REPLACE FUNCTION public.rpc_start_session(
  p_session_type public.session_type,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employee_id UUID;
  v_attendance_day_id UUID;
  v_work_session_id UUID;
  v_current_date DATE;
BEGIN
  v_employee_id := auth.uid();
  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_current_date := CURRENT_DATE;

  -- 1. Get or create today's attendance_day
  SELECT id INTO v_attendance_day_id
  FROM public.attendance_days
  WHERE employee_id = v_employee_id AND date = v_current_date;

  IF v_attendance_day_id IS NULL THEN
    INSERT INTO public.attendance_days (employee_id, date, status)
    VALUES (v_employee_id, v_current_date, 'present')
    RETURNING id INTO v_attendance_day_id;
  END IF;

  -- 2. Check if there is already an active session
  IF EXISTS (
    SELECT 1 FROM public.work_sessions 
    WHERE employee_id = v_employee_id AND status IN ('working', 'on_break')
  ) THEN
    RAISE EXCEPTION 'An active session already exists. End it first.';
  END IF;

  -- 3. Create work_session
  INSERT INTO public.work_sessions (attendance_day_id, employee_id, session_type, status, started_at, start_latitude, start_longitude)
  VALUES (v_attendance_day_id, v_employee_id, p_session_type, 'working', NOW(), p_lat, p_lng)
  RETURNING id INTO v_work_session_id;

  -- 4. Log immutable event
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, latitude, longitude, timestamp)
  VALUES (v_employee_id, v_attendance_day_id, 'session_started', p_session_type, p_lat, p_lng, NOW());

  RETURN jsonb_build_object('success', true, 'work_session_id', v_work_session_id, 'attendance_day_id', v_attendance_day_id);
END;
$$;


-- 2. END SESSION
CREATE OR REPLACE FUNCTION public.rpc_end_session(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employee_id UUID;
  v_work_session_id UUID;
  v_attendance_day_id UUID;
  v_session_type public.session_type;
BEGIN
  v_employee_id := auth.uid();
  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Find active session
  SELECT id, attendance_day_id, session_type INTO v_work_session_id, v_attendance_day_id, v_session_type
  FROM public.work_sessions
  WHERE employee_id = v_employee_id AND status IN ('working', 'on_break')
  LIMIT 1;

  IF v_work_session_id IS NULL THEN
    RAISE EXCEPTION 'No active session found.';
  END IF;

  -- 2. If on break, implicitly end the break first
  UPDATE public.session_breaks
  SET ended_at = NOW(), end_latitude = p_lat, end_longitude = p_lng
  WHERE work_session_id = v_work_session_id AND ended_at IS NULL;

  -- 3. End work session
  UPDATE public.work_sessions
  SET status = 'ended', ended_at = NOW(), end_latitude = p_lat, end_longitude = p_lng
  WHERE id = v_work_session_id;

  -- 4. Log immutable event
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, latitude, longitude, timestamp)
  VALUES (v_employee_id, v_attendance_day_id, 'session_ended', v_session_type, p_lat, p_lng, NOW());

  -- 5. Update totals
  PERFORM public.rpc_update_day_totals(v_attendance_day_id);

  RETURN jsonb_build_object('success', true, 'work_session_id', v_work_session_id);
END;
$$;


-- 3. TOGGLE BREAK (Break Out / Break In)
CREATE OR REPLACE FUNCTION public.rpc_toggle_break(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employee_id UUID;
  v_work_session_id UUID;
  v_attendance_day_id UUID;
  v_status public.session_status;
  v_session_type public.session_type;
  v_break_id UUID;
BEGIN
  v_employee_id := auth.uid();
  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Find active session
  SELECT id, attendance_day_id, status, session_type INTO v_work_session_id, v_attendance_day_id, v_status, v_session_type
  FROM public.work_sessions
  WHERE employee_id = v_employee_id AND status IN ('working', 'on_break')
  LIMIT 1;

  IF v_work_session_id IS NULL THEN
    RAISE EXCEPTION 'No active session found.';
  END IF;

  IF v_status = 'working' THEN
    -- Going ON BREAK (Break Out)
    INSERT INTO public.session_breaks (work_session_id, started_at, start_latitude, start_longitude)
    VALUES (v_work_session_id, NOW(), p_lat, p_lng)
    RETURNING id INTO v_break_id;

    UPDATE public.work_sessions SET status = 'on_break' WHERE id = v_work_session_id;
    
    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, latitude, longitude, timestamp)
    VALUES (v_employee_id, v_attendance_day_id, 'break_out', v_session_type, p_lat, p_lng, NOW());

    RETURN jsonb_build_object('success', true, 'action', 'break_out', 'break_id', v_break_id);
    
  ELSIF v_status = 'on_break' THEN
    -- Returning to WORK (Break In)
    UPDATE public.session_breaks
    SET ended_at = NOW(), end_latitude = p_lat, end_longitude = p_lng
    WHERE work_session_id = v_work_session_id AND ended_at IS NULL;

    UPDATE public.work_sessions SET status = 'working' WHERE id = v_work_session_id;

    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, latitude, longitude, timestamp)
    VALUES (v_employee_id, v_attendance_day_id, 'break_in', v_session_type, p_lat, p_lng, NOW());

    PERFORM public.rpc_update_day_totals(v_attendance_day_id);

    RETURN jsonb_build_object('success', true, 'action', 'break_in');
  END IF;
END;
$$;


-- 4. END DAY
CREATE OR REPLACE FUNCTION public.rpc_end_day(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_employee_id UUID;
  v_attendance_day_id UUID;
BEGIN
  v_employee_id := auth.uid();
  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Find today's active attendance day
  SELECT id INTO v_attendance_day_id
  FROM public.attendance_days
  WHERE employee_id = v_employee_id AND date = CURRENT_DATE
  LIMIT 1;

  IF v_attendance_day_id IS NULL THEN
    RAISE EXCEPTION 'No active day found.';
  END IF;

  -- 2. End any open session/breaks implicitly
  PERFORM public.rpc_end_session(p_lat, p_lng);

  -- 3. Log End Day event
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, latitude, longitude, timestamp)
  VALUES (v_employee_id, v_attendance_day_id, 'day_ended', p_lat, p_lng, NOW());

  RETURN jsonb_build_object('success', true, 'attendance_day_id', v_attendance_day_id);
END;
$$;

-- 5. RECALCULATE DAY TOTALS
CREATE OR REPLACE FUNCTION public.rpc_update_day_totals(p_attendance_day_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_work_mins NUMERIC;
  v_break_mins NUMERIC;
BEGIN
  -- Total raw session time (including breaks)
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (ended_at - started_at))/60.0), 0)
  INTO v_work_mins
  FROM public.work_sessions
  WHERE attendance_day_id = p_attendance_day_id AND ended_at IS NOT NULL;

  -- Total break time
  SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (sb.ended_at - sb.started_at))/60.0), 0)
  INTO v_break_mins
  FROM public.session_breaks sb
  JOIN public.work_sessions ws ON sb.work_session_id = ws.id
  WHERE ws.attendance_day_id = p_attendance_day_id AND sb.ended_at IS NOT NULL;

  -- Net work time = Raw session time - Break time
  v_work_mins := v_work_mins - v_break_mins;

  -- Update attendance_days
  UPDATE public.attendance_days
  SET total_work_minutes = ROUND(v_work_mins),
      total_break_minutes = ROUND(v_break_mins)
  WHERE id = p_attendance_day_id;
END;
$$;

-- 6. ADMIN FORCE END SESSION
CREATE OR REPLACE FUNCTION public.admin_force_end_session(p_employee_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_work_session_id UUID;
  v_attendance_day_id UUID;
  v_session_type public.session_type;
BEGIN
  -- Verify caller is admin
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 1. Find active session
  SELECT id, attendance_day_id, session_type INTO v_work_session_id, v_attendance_day_id, v_session_type
  FROM public.work_sessions
  WHERE employee_id = p_employee_id AND status IN ('working', 'on_break')
  LIMIT 1;

  IF v_work_session_id IS NULL THEN
    RAISE EXCEPTION 'No active session found for this employee.';
  END IF;

  -- 2. If on break, implicitly end the break first
  UPDATE public.session_breaks
  SET ended_at = NOW()
  WHERE work_session_id = v_work_session_id AND ended_at IS NULL;

  -- 3. End work session
  UPDATE public.work_sessions
  SET status = 'ended', ended_at = NOW()
  WHERE id = v_work_session_id;

  -- 4. Log immutable event (Admin Override)
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, timestamp)
  VALUES (p_employee_id, v_attendance_day_id, 'session_ended', v_session_type, NOW());
  
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, timestamp)
  VALUES (p_employee_id, v_attendance_day_id, 'day_ended', NOW());

  -- 5. Update totals
  PERFORM public.rpc_update_day_totals(v_attendance_day_id);

  RETURN jsonb_build_object('success', true, 'work_session_id', v_work_session_id);
END;
$$;

-- 7. ADMIN FORCE START SESSION
CREATE OR REPLACE FUNCTION public.admin_force_start_session(p_employee_id UUID, p_session_type public.session_type)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_attendance_day_id UUID;
  v_work_session_id UUID;
  v_current_date DATE;
BEGIN
  -- Verify caller is admin
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  v_current_date := CURRENT_DATE;

  -- 1. Get or create today's attendance_day
  SELECT id INTO v_attendance_day_id
  FROM public.attendance_days
  WHERE employee_id = p_employee_id AND date = v_current_date;

  IF v_attendance_day_id IS NULL THEN
    INSERT INTO public.attendance_days (employee_id, date, status)
    VALUES (p_employee_id, v_current_date, 'present')
    RETURNING id INTO v_attendance_day_id;
  END IF;

  -- 2. Check if there is already an active session
  IF EXISTS (
    SELECT 1 FROM public.work_sessions 
    WHERE employee_id = p_employee_id AND status IN ('working', 'on_break')
  ) THEN
    RAISE EXCEPTION 'An active session already exists for this employee.';
  END IF;

  -- 3. Create work_session
  INSERT INTO public.work_sessions (attendance_day_id, employee_id, session_type, status, started_at, start_latitude, start_longitude)
  VALUES (v_attendance_day_id, p_employee_id, p_session_type, 'working', NOW(), NULL, NULL)
  RETURNING id INTO v_work_session_id;

  -- 4. Log immutable event
  INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, timestamp)
  VALUES (p_employee_id, v_attendance_day_id, 'session_started', p_session_type, NOW());

  RETURN jsonb_build_object('success', true, 'work_session_id', v_work_session_id, 'attendance_day_id', v_attendance_day_id);
END;
$$;
