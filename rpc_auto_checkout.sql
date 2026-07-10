-- ==============================================================================
-- ADNORA AUTO-CHECKOUT & ADMIN REVIEW RPCs
-- Run this in your Supabase SQL Editor
-- ==============================================================================

-- 1. Enable pg_cron (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Function to automatically check out forgotten sessions
CREATE OR REPLACE FUNCTION public.rpc_auto_checkout_forgotten()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
BEGIN
  -- Find all active sessions that started on a date earlier than CURRENT_DATE
  FOR v_rec IN 
    SELECT ws.id as work_session_id, ws.employee_id, ws.attendance_day_id, ws.session_type, ad.date
    FROM public.work_sessions ws
    JOIN public.attendance_days ad ON ws.attendance_day_id = ad.id
    WHERE ws.status IN ('working', 'on_break')
      AND ad.date < CURRENT_DATE
  LOOP
    -- 1. End break if on break
    UPDATE public.session_breaks
    SET ended_at = NOW()
    WHERE work_session_id = v_rec.work_session_id AND ended_at IS NULL;

    -- 2. End work session
    UPDATE public.work_sessions
    SET status = 'ended', ended_at = NOW()
    WHERE id = v_rec.work_session_id;

    -- 3. Log events
    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, timestamp)
    VALUES (v_rec.employee_id, v_rec.attendance_day_id, 'session_ended', v_rec.session_type, NOW());

    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, timestamp)
    VALUES (v_rec.employee_id, v_rec.attendance_day_id, 'day_ended', NOW());

    -- 4. Update day totals
    PERFORM public.rpc_update_day_totals(v_rec.attendance_day_id);
    
    -- 5. Flag for admin review
    INSERT INTO public.attendance_corrections (employee_id, attendance_day_id, work_session_id, status, reason)
    VALUES (v_rec.employee_id, v_rec.attendance_day_id, v_rec.work_session_id, 'pending', 'SYSTEM AUTO-CHECKOUT: Employee forgot to check out. Admin, please verify actual exit time.');

  END LOOP;
END;
$$;

-- 3. Schedule the Cron Job to run at 6:00 AM IST (00:30 UTC)
-- This requires pg_cron to be active. It will run every day.
SELECT cron.schedule('auto-checkout-6am-ist', '30 0 * * *', 'SELECT public.rpc_auto_checkout_forgotten();');

-- 4. Function for Admin to fix the exit time
CREATE OR REPLACE FUNCTION public.rpc_admin_fix_exit_time(
  p_correction_id UUID,
  p_work_session_id UUID,
  p_new_exit_time TIMESTAMP WITH TIME ZONE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_attendance_day_id UUID;
  v_employee_id UUID;
  v_started_at TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Verify caller is admin
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
  IF NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 1. Find the session and ensure the new exit time is valid
  SELECT attendance_day_id, employee_id, started_at 
  INTO v_attendance_day_id, v_employee_id, v_started_at
  FROM public.work_sessions
  WHERE id = p_work_session_id;

  IF v_attendance_day_id IS NULL THEN
    RAISE EXCEPTION 'Work session not found.';
  END IF;

  IF p_new_exit_time <= v_started_at THEN
    RAISE EXCEPTION 'Exit time cannot be earlier than start time.';
  END IF;

  -- 2. Update the session's end time
  UPDATE public.work_sessions
  SET ended_at = p_new_exit_time
  WHERE id = p_work_session_id;

  -- If they were on a break when auto-closed, we must ensure the break doesn't end AFTER the new exit time
  UPDATE public.session_breaks
  SET ended_at = p_new_exit_time
  WHERE work_session_id = p_work_session_id AND ended_at > p_new_exit_time;

  -- 3. Update the event logs to reflect the true exit time
  UPDATE public.attendance_events
  SET timestamp = p_new_exit_time
  WHERE attendance_day_id = v_attendance_day_id AND event_type IN ('session_ended', 'day_ended');

  -- 4. Recalculate totals
  PERFORM public.rpc_update_day_totals(v_attendance_day_id);

  -- 5. Mark the correction as resolved
  IF p_correction_id IS NOT NULL THEN
    UPDATE public.attendance_corrections
    SET status = 'resolved'
    WHERE id = p_correction_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
