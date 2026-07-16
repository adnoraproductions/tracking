CREATE OR REPLACE FUNCTION public.admin_force_toggle_break(p_employee_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $BODY
DECLARE
  v_is_admin BOOLEAN;
  v_work_session_id UUID;
  v_attendance_day_id UUID;
  v_session_type public.session_type;
  v_status text;
  v_break_id UUID;
BEGIN
  SELECT (role = 'admin') INTO v_is_admin FROM public.profiles WHERE id = auth.uid();
  IF NOT v_is_admin THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT id, attendance_day_id, session_type, status 
  INTO v_work_session_id, v_attendance_day_id, v_session_type, v_status
  FROM public.work_sessions
  WHERE employee_id = p_employee_id AND status IN ('working', 'on_break') LIMIT 1;

  IF v_work_session_id IS NULL THEN RAISE EXCEPTION 'No active session'; END IF;

  IF v_status = 'working' THEN
    INSERT INTO public.session_breaks (work_session_id, started_at) VALUES (v_work_session_id, NOW()) RETURNING id INTO v_break_id;
    UPDATE public.work_sessions SET status = 'on_break' WHERE id = v_work_session_id;
    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, timestamp) VALUES (p_employee_id, v_attendance_day_id, 'break_out', v_session_type, NOW());
    RETURN jsonb_build_object('success', true, 'action', 'break_out');
  ELSIF v_status = 'on_break' THEN
    UPDATE public.session_breaks SET ended_at = NOW() WHERE work_session_id = v_work_session_id AND ended_at IS NULL;
    UPDATE public.work_sessions SET status = 'working' WHERE id = v_work_session_id;
    INSERT INTO public.attendance_events (employee_id, attendance_day_id, event_type, session_type, timestamp) VALUES (p_employee_id, v_attendance_day_id, 'break_in', v_session_type, NOW());
    PERFORM public.rpc_update_day_totals(v_attendance_day_id);
    RETURN jsonb_build_object('success', true, 'action', 'break_in');
  END IF;
END;
$BODY;
