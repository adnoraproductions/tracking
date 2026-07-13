import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useGeolocation } from '../../hooks/useGeolocation';
import { Loader2, ChevronLeft, ChevronRight, Clock, RefreshCw, MapPin, Home, Briefcase, Calendar } from 'lucide-react';
import { format, differenceInSeconds, isToday } from 'date-fns';
import CalendarModal from '../../components/CalendarModal';

export default function EmployeeDashboard() {
  const { profile } = useAuth();
  const { getLocationAndValidate } = useGeolocation();
  
  const [loading, setLoading] = useState(true);
  const [initialLoad, setInitialLoad] = useState(true);
  const [error, setError] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [deviceValid, setDeviceValid] = useState(true);
  
  const [sessionState, setSessionState] = useState({
    activeSession: null,
    events: [],
    sessions: [],
    todayDayId: null,
    todayTotalWorkMinutes: 0
  });

  const [selectedDate, setSelectedDate] = useState(new Date());
  const [showCalendar, setShowCalendar] = useState(false);
  const [liveTimer, setLiveTimer] = useState(0);
  const [workTargetHours, setWorkTargetHours] = useState(8); // default to 8
  
  // Forgot Checkout Flow State
  const [showForgotCheckoutModal, setShowForgotCheckoutModal] = useState(false);
  const [forgotCheckoutData, setForgotCheckoutData] = useState(null);
  const [forgotReason, setForgotReason] = useState('');
  const [forgotLoading, setForgotLoading] = useState(false);

  // Forgot Check In Flow State
  const [showForgotCheckInModal, setShowForgotCheckInModal] = useState(false);
  const [forgotCheckInData, setForgotCheckInData] = useState(null);
  const [forgotCheckInReason, setForgotCheckInReason] = useState('');
  const [forgotCheckInLoading, setForgotCheckInLoading] = useState(false);
  
  const isToday = format(selectedDate, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd');

  // Fetch data
  const fetchData = async () => {
    try {
      setLoading(true);
      
      const targetDateStr = format(selectedDate, 'yyyy-MM-dd');
      
      // 0. Get office settings (global work target)
      const { data: settings, error: settingsErr } = await supabase
        .from('office_settings')
        .select('work_target_hours')
        .limit(1)
        .single();
      
      if (!settingsErr && settings) {
        setWorkTargetHours(settings.work_target_hours || 8);
      }

      // 0.5 Device Binding Check
      let localDeviceId = null;
      const generateId = () => (crypto.randomUUID ? crypto.randomUUID() : 'fallback-' + Math.random().toString(36).substring(2, 15));
      
      try {
        localDeviceId = localStorage.getItem('device_id');
        if (!localDeviceId) {
          localDeviceId = generateId();
          localStorage.setItem('device_id', localDeviceId);
        }
      } catch (err) {
        console.warn('localStorage is blocked by browser settings:', err);
        // Provide a temporary random id so the app doesn't crash
        localDeviceId = generateId();
      }

      let isDeviceValid = true;
      const deviceBindingEnabled = profile.is_device_binding_enabled ?? false;

      if (deviceBindingEnabled) {
        if (!profile.registered_device_id) {
          // Auto-bind on first login
          const { error: bindErr } = await supabase
            .from('profiles')
            .update({ registered_device_id: localDeviceId })
            .eq('id', profile.id);
          if (bindErr) console.error("Could not bind device", bindErr);
        } else if (profile.registered_device_id !== localDeviceId) {
          isDeviceValid = false;
        }
      }
      setDeviceValid(isDeviceValid);

      // 1. Get today's attendance_day
      const { data: days, error: dayErr } = await supabase
        .from('attendance_days')
        .select('id, total_work_minutes')
        .eq('employee_id', profile.id)
        .eq('date', targetDateStr);
        
      if (dayErr) throw dayErr;
      
      let dayId = null;
      let totalMins = 0;
      if (days && days.length > 0) {
        dayId = days[0].id;
        totalMins = days[0].total_work_minutes || 0;
      }
      
      // 2. Get all work_sessions for today (with breaks) for accurate second-level timer
      let sessions = [];
      let activeSession = null;
      if (dayId) {
        const { data: sessData, error: sessErr } = await supabase
          .from('work_sessions')
          .select('*, session_breaks(*)')
          .eq('attendance_day_id', dayId);
          
        if (sessErr) throw sessErr;
        sessions = sessData || [];
        activeSession = sessions.find(s => s.status === 'working' || s.status === 'on_break') || null;
      } else if (isToday(selectedDate)) {
        // Only look for a dangling active session (e.g. checked in yesterday but still working) if we are viewing "Today"
        const { data: sessData, error: sessErr } = await supabase
          .from('work_sessions')
          .select('*, session_breaks(*)')
          .eq('employee_id', profile.id)
          .in('status', ['working', 'on_break']);
        if (!sessErr && sessData && sessData.length > 0) {
          activeSession = sessData[0];
          sessions = sessData;
        }
      }

      // 3. Get all events for today (to build log)
      let events = [];
      if (dayId) {
        const { data: evts, error: evtErr } = await supabase
          .from('attendance_events')
          .select('*')
          .eq('attendance_day_id', dayId)
          .order('timestamp', { ascending: false });
          
        if (evtErr) throw evtErr;
        events = evts || [];
      }

      setSessionState({
        activeSession,
        events,
        sessions,
        todayDayId: dayId,
        todayTotalWorkMinutes: totalMins
      });

    } catch (err) {
      console.error(err);
      setError(err.message);
    } finally {
      setLoading(false);
      setInitialLoad(false);
    }
  };

  useEffect(() => {
    if (profile) fetchData();

    // Register global hooks for Flutter Android Widget
    window.triggerWidgetPunch = (type) => {
      if (type === 'break_toggle') {
        const currentStatus = sessionState.activeSession?.status;
        if (currentStatus === 'working') handleAction('break_out');
        else if (currentStatus === 'on_break') handleAction('break_in');
      } else {
        handleAction(type);
      }
    };

    return () => {
      delete window.triggerWidgetPunch;
    };
  }, [profile, selectedDate]);

  const handleForgotCheckoutSubmit = async (e) => {
    e.preventDefault();
    if (!forgotReason) { alert("Please provide a reason."); return; }
    
    setForgotLoading(true);
    try {
      // 1. Check out normally
      const { data, error } = await supabase.rpc('rpc_end_day', {
        p_lat: null, // Don't save location for office checkouts to save space
        p_lng: null
      });
      if (error) throw error;
      
      // 2. Submit correction
      const { error: correctionErr } = await supabase
        .from('attendance_corrections')
        .insert({
          employee_id: profile.id,
          attendance_day_id: sessionState.todayDayId,
          work_session_id: sessionState.activeSession.id,
          status: 'pending',
          reason: `Forgot to checkout: ${forgotReason}` + (forgotCheckoutData.distance ? ` (Distance: ${Math.round(forgotCheckoutData.distance)}m)` : '')
        });
        
      if (correctionErr) console.error("Failed to save correction:", correctionErr);
      
      setShowForgotCheckoutModal(false);
      setForgotReason('');
      await fetchData();
    } catch (err) {
      console.error(err);
      alert('Failed to check out: ' + err.message);
    } finally {
      setForgotLoading(false);
    }
  };

  const handleForgotCheckInSubmit = async (e) => {
    e.preventDefault();
    if (!forgotCheckInReason) { alert("Please provide a reason."); return; }
    
    setForgotCheckInLoading(true);
    try {
      // 1. Check in normally, pass actual location for admin reference
      const { data, error } = await supabase.rpc('rpc_start_session', {
        p_session_type: 'office',
        p_lat: forgotCheckInData.geo.lat,
        p_lng: forgotCheckInData.geo.lng
      });
      if (error) throw error;
      if (data && data.success === false) throw new Error(data.message);
      
      const workSessionId = data.work_session_id;
      const dayId = data.attendance_day_id;
      
      // 2. Submit correction
      const { error: correctionErr } = await supabase
        .from('attendance_corrections')
        .insert({
          employee_id: profile.id,
          attendance_day_id: dayId,
          work_session_id: workSessionId,
          status: 'pending',
          reason: `Forgot to Check In (Office): ${forgotCheckInReason}` + (forgotCheckInData.distance ? ` (Distance: ${Math.round(forgotCheckInData.distance)}m)` : '')
        });
        
      if (correctionErr) console.error("Failed to save correction:", correctionErr);
      
      setShowForgotCheckInModal(false);
      setForgotCheckInReason('');
      await fetchData();
    } catch (err) {
      console.error(err);
      alert('Failed to check in: ' + err.message);
    } finally {
      setForgotCheckInLoading(false);
    }
  };

  // Handle actions
  const handleAction = async (actionType) => {
    setActionLoading(actionType);
    setError(null);
    try {
      let geo = { lat: 0, lng: 0 };
      let rpcSessionType = null;
      
      // Request location based on action
      if (actionType.startsWith('start_')) {
         rpcSessionType = actionType.replace('start_', '');
         
         if (rpcSessionType === 'office') {
            try {
               const { location, validation } = await getLocationAndValidate('office');
               geo = { lat: location.latitude, lng: location.longitude };
               
               if (validation && !validation.isWithin) {
                  setForgotCheckInData({ geo, distance: validation.distance });
                  setShowForgotCheckInModal(true);
                  setActionLoading(false);
                  return; // Stop standard flow
               }
            } catch (geoErr) {
               setForgotCheckInData({ geo: { lat: null, lng: null }, distance: null, error: geoErr.message });
               setShowForgotCheckInModal(true);
               setActionLoading(false);
               return; // Stop standard flow
            }
         } else {
            try {
               const { location } = await getLocationAndValidate(rpcSessionType); 
               geo = { lat: location.latitude, lng: location.longitude };
            } catch (geoErr) {
               console.warn("Location fetch failed, proceeding anyway for WFH/Field:", geoErr);
               geo = { lat: null, lng: null };
            }
         }
      } else if (actionType === 'end' && sessionState.activeSession?.session_type === 'office') {
         // Require location and validation for end of office session
         try {
           const { location, validation } = await getLocationAndValidate('office');
           geo = { lat: location.latitude, lng: location.longitude };
           
           if (validation && !validation.isWithin) {
              setForgotCheckoutData({ geo, distance: validation.distance });
              setShowForgotCheckoutModal(true);
              setActionLoading(false);
              return; // Stop the standard checkout flow
           }
         } catch (geoErr) {
            // Location fetch failed (timeout or no permission)
            setForgotCheckoutData({ geo: { lat: 0, lng: 0 }, distance: null, error: geoErr.message });
            setShowForgotCheckoutModal(true);
            setActionLoading(false);
            return;
         }
      } else {
         // Generic location for other actions
         // If location fails or times out, we don't want to trap the user and prevent them from checking out.
         try {
           const pos = await new Promise((resolve, reject) => {
              navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 8000, enableHighAccuracy: false });
           });
           geo = { lat: pos.coords.latitude, lng: pos.coords.longitude };
         } catch (geoErr) {
           console.warn("Location fetch failed, proceeding anyway to not block checkout:", geoErr);
           geo = { lat: null, lng: null };
         }
      }

      const rpcName = 
        actionType.startsWith('start_') ? 'rpc_start_session' :
        actionType === 'break_out' ? 'rpc_toggle_break' :
        actionType === 'break_in' ? 'rpc_toggle_break' :
        actionType === 'end' ? 'rpc_end_day' : null;

      const isOfficeSession = rpcSessionType === 'office' || sessionState.activeSession?.session_type === 'office';

      const args = actionType.startsWith('start_') 
        ? { p_session_type: rpcSessionType, p_lat: isOfficeSession ? null : geo.lat, p_lng: isOfficeSession ? null : geo.lng, p_local_date: format(new Date(), 'yyyy-MM-dd') }
        : { p_lat: isOfficeSession ? null : geo.lat, p_lng: isOfficeSession ? null : geo.lng };

      const { data, error } = await supabase.rpc(rpcName, args);
      
      if (error) throw error;
      if (data && data.success === false) throw new Error(data.message);

      await fetchData();
    } catch (err) {
      console.error(err);
      setError(err.message);
    } finally {
      setActionLoading(false);
    }
  };

  let statusText = 'Checked Out';
  let badgeColorClass = 'offline'; // 'offline', 'active', 'break'
  if (sessionState.activeSession) {
    if (sessionState.activeSession.status === 'working') {
      statusText = 'Working';
      badgeColorClass = 'active';
    } else if (sessionState.activeSession.status === 'on_break') {
      statusText = 'On Break';
      badgeColorClass = 'break';
    }
  }

  // Get First In / Last Out
  let firstIn = '-';
  let lastOut = '-';
  if (sessionState.events.length > 0) {
    const starts = sessionState.events.filter(e => e.event_type === 'session_started');
    if (starts.length > 0) {
      firstIn = format(new Date(starts[starts.length - 1].timestamp), 'hh:mm:ss a');
    }
    const ends = sessionState.events.filter(e => e.event_type === 'day_ended' || e.event_type === 'session_ended');
    if (ends.length > 0) {
      lastOut = format(new Date(ends[0].timestamp), 'hh:mm:ss a');
    }
  }

  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(interval);
  }, []);

  const formatTimer = (totalSeconds) => {
    const h = Math.floor(totalSeconds / 3600).toString().padStart(2, '0');
    const m = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, '0');
    const s = (totalSeconds % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  };

  // Calculate total accurate worked seconds
  let totalWorkedSeconds = 0;
  if (sessionState.sessions) {
    sessionState.sessions.forEach(s => {
      const end = s.ended_at ? new Date(s.ended_at) : now;
      let sessionSecs = differenceInSeconds(end, new Date(s.started_at));
      
      if (s.session_breaks && s.session_breaks.length > 0) {
        s.session_breaks.forEach(b => {
          const bEnd = b.ended_at ? new Date(b.ended_at) : now;
          sessionSecs -= differenceInSeconds(bEnd, new Date(b.started_at));
        });
      }
      
      if (sessionSecs > 0) {
        totalWorkedSeconds += sessionSecs;
      }
    });
  }

  // If viewing a past day, use exactly the static sessions data
  if (!isToday && sessionState.sessions.length === 0) {
    totalWorkedSeconds = sessionState.todayTotalWorkMinutes * 60;
  }

  const targetSeconds = workTargetHours * 3600;
  const targetComplete = totalWorkedSeconds >= targetSeconds;
  
  let targetMessage = '';
  if (targetComplete) {
    targetMessage = '✓ Target hours complete';
  } else {
    const remaining = targetSeconds - totalWorkedSeconds;
    const rH = Math.floor(remaining / 3600);
    const rM = Math.floor((remaining % 3600) / 60);
    targetMessage = `${rH}h ${rM}m remaining to hit target`;
  }

  // Sync state to native Android Widget
  useEffect(() => {
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('updateWidgetState', {
        status: sessionState.activeSession ? sessionState.activeSession.status : 'offline',
        workedSeconds: Math.floor(totalWorkedSeconds),
        targetMessage: targetMessage,
        firstIn: firstIn,
        lastOut: lastOut
      });
    }
  }, [sessionState.activeSession, totalWorkedSeconds, targetMessage, firstIn, lastOut]);

  if (initialLoad) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><div className="skeuo-loader"></div></div>;
  }

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  };

  return (
    <>
      {/* Header Card */}
      <div className="emp-header-card">
        <div className="emp-header-top">
          <span className="emp-greeting">{getGreeting()}, {profile?.full_name?.split(' ')[0]}</span>
          <div className={`emp-status-badge ${badgeColorClass}`}>
            {statusText === 'Working' && <span style={{width: '6px', height: '6px', backgroundColor: 'white', borderRadius: '50%'}}></span>}
            {statusText}
          </div>
        </div>

        <div className="emp-profile-row">
          <div className="emp-avatar">
            <span style={{ fontSize: '24px' }}>{profile?.full_name?.charAt(0)}</span>
          </div>
          <div className="emp-name-box">
            <h2>Employee</h2>
            <p>ID: {profile?.employee_code || '---'}</p>
          </div>
        </div>
      </div>

      {/* Date Scroller */}
      <div className="emp-date-scroller">
        <ChevronLeft className="emp-icon-btn" size={20} onClick={() => setSelectedDate(d => new Date(d.getTime() - 86400000))} style={{ cursor: 'pointer' }} />
        
        <span 
          className="emp-date-text" 
          onClick={() => setShowCalendar(true)}
          style={{ cursor: 'pointer', position: 'relative', display: 'flex', alignItems: 'center', gap: '8px' }}
          title="Choose a date"
        >
          {loading && !initialLoad && <div className="skeuo-loader sm"></div>}
          {isToday ? 'Today · ' : ''}{format(selectedDate, 'EEE, dd MMM')}
        </span>

        <CalendarModal 
          isOpen={showCalendar} 
          onClose={() => setShowCalendar(false)} 
          selectedDate={selectedDate} 
          onSelectDate={setSelectedDate} 
        />

        <ChevronRight 
          className="emp-icon-btn" 
          size={20} 
          onClick={() => {
            const next = new Date(selectedDate.getTime() + 86400000);
            if (format(next, 'yyyy-MM-dd') <= format(new Date(), 'yyyy-MM-dd')) {
              setSelectedDate(next);
            }
          }}
          style={{ cursor: isToday ? 'not-allowed' : 'pointer', opacity: isToday ? 0.3 : 1 }} 
        />
      </div>


      {/* Desktop Grid Wrapper */}
      <div className="emp-content-grid">
        {/* Left Column */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {/* Metrics Row */}
          <div className="emp-metrics-row">
            {/* Left Timer */}
            <div className="emp-timer-card">
              <div style={{ backgroundColor: 'rgba(255,255,255,0.1)', width: '32px', height: '32px', borderRadius: '8px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                <Clock size={16} />
              </div>
              <span className="emp-timer-label">Total Worked</span>
              <span className="emp-timer-value">{formatTimer(totalWorkedSeconds)}</span>
              <span className={`emp-timer-target ${targetComplete ? 'complete' : ''}`}>
                {targetMessage}
              </span>
            </div>

            {/* Right Info */}
            <div className="emp-info-card">
              <div className="emp-badge-gray">{statusText}</div>
              
              <div className="emp-time-block">
                <div className="emp-time-label">First In</div>
                <div className="emp-time-val">
                  <span style={{ color: '#10b981' }}>●</span> {firstIn}
                </div>
              </div>
              
              <div style={{ borderTop: '1px solid #f3f4f6', margin: '8px 0 12px 0' }}></div>

              <div className="emp-time-block">
                <div className="emp-time-label">Last Out</div>
                <div className="emp-time-val">
                  <span style={{ color: '#ef4444' }}>×</span> {lastOut}
                </div>
              </div>
            </div>
          </div>
          {/* Action Buttons (Only show if viewing Today) */}
          {isToday && (
            deviceValid ? (
              <div className="emp-action-grid">
                {!sessionState.activeSession ? (
                  <>
                    <button className="emp-btn-square" onClick={() => handleAction('start_office')} disabled={actionLoading}>
                      <div style={{ backgroundColor: '#d1fae5', padding: '8px', borderRadius: '50%', color: 'var(--emp-primary)' }}>
                        {actionLoading === 'start_office' ? <div className="skeuo-loader sm"></div> : <Briefcase size={20} />}
                      </div>
                      Office
                    </button>
                    <button className="emp-btn-square" onClick={() => handleAction('start_wfh')} disabled={actionLoading}>
                      <div style={{ backgroundColor: '#e0e7ff', padding: '8px', borderRadius: '50%', color: '#4f46e5' }}>
                        {actionLoading === 'start_wfh' ? <div className="skeuo-loader sm"></div> : <Home size={20} />}
                      </div>
                      WFH
                    </button>
                    <button className="emp-btn-square" onClick={() => handleAction('start_field_work')} disabled={actionLoading}>
                      <div style={{ backgroundColor: '#fef3c7', padding: '8px', borderRadius: '50%', color: '#d97706' }}>
                        {actionLoading === 'start_field_work' ? <div className="skeuo-loader sm"></div> : <MapPin size={20} />}
                      </div>
                      Field
                    </button>
                  </>
                ) : (
                  <>
                    <button className="emp-btn-square danger" onClick={() => handleAction('end')} disabled={actionLoading}>
                       <div style={{ backgroundColor: '#fef2f2', padding: '8px', borderRadius: '50%', color: 'var(--emp-danger)' }}>
                         {actionLoading === 'end' ? <div className="skeuo-loader sm"></div> : <Clock size={20} />}
                       </div>
                       Check Out
                    </button>
                    <button className={`emp-btn-square ${sessionState.activeSession.status === 'on_break' ? 'active' : ''}`} onClick={() => handleAction(sessionState.activeSession.status === 'on_break' ? 'break_in' : 'break_out')} disabled={actionLoading}>
                       <div style={{ backgroundColor: sessionState.activeSession.status === 'on_break' ? 'rgba(255,255,255,0.2)' : '#fef3c7', padding: '8px', borderRadius: '50%', color: sessionState.activeSession.status === 'on_break' ? 'white' : '#f59e0b' }}>
                         {(actionLoading === 'break_in' || actionLoading === 'break_out') ? <div className="skeuo-loader sm"></div> : <Clock size={20} />}
                       </div>
                       {sessionState.activeSession.status === 'on_break' ? 'Resume Work' : 'Take Break'}
                    </button>
                  </>
                )}
              </div>
            ) : (
              <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '16px', borderRadius: '12px', fontSize: '14px', textAlign: 'center', border: '1px solid #fca5a5' }}>
                <p style={{ fontWeight: 'bold', margin: '0 0 8px 0' }}>Unauthorized Device</p>
                This account is bound to another device. You cannot clock in from this phone.
              </div>
            )
          )}

          {error && (
            <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', fontSize: '14px' }}>
              {error}
            </div>
          )}
        </div>
      </div>

      {/* Forgot Checkout Modal */}
      {showForgotCheckoutModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: '#fff', borderRadius: '24px', width: '100%', maxWidth: '400px', padding: '24px'
          }}>
            <h3 style={{ marginTop: 0, color: 'var(--emp-text-dark)' }}>Forgot to Check Out?</h3>
            <p style={{ color: 'var(--emp-text-muted)', fontSize: '14px', marginBottom: '20px' }}>
              You are outside the office. Please provide a reason to complete your checkout.
            </p>
            <textarea
              style={{ width: '100%', padding: '12px', border: '1px solid var(--emp-border)', borderRadius: '12px', marginBottom: '16px', minHeight: '80px', fontFamily: 'inherit' }}
              placeholder="e.g., Left at 5 PM but forgot to click"
              value={forgotReason}
              onChange={(e) => setForgotReason(e.target.value)}
            />
            <div style={{ display: 'flex', gap: '12px' }}>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: '1px solid var(--emp-border)', backgroundColor: '#fff', fontWeight: 'bold' }}
                onClick={() => setShowForgotCheckoutModal(false)}
                disabled={forgotLoading}
              >
                Cancel
              </button>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: 'none', backgroundColor: 'var(--emp-primary)', color: 'white', fontWeight: 'bold', display: 'flex', justifyContent: 'center' }}
                onClick={handleForgotCheckoutSubmit}
                disabled={forgotLoading || !forgotReason}
              >
                {forgotLoading ? <div className="skeuo-loader sm"></div> : 'Submit & Check Out'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Forgot Check-In Modal */}
      {showForgotCheckInModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: '#fff', borderRadius: '24px', width: '100%', maxWidth: '400px', padding: '24px'
          }}>
            <h3 style={{ marginTop: 0, color: 'var(--emp-text-dark)' }}>Check In Override</h3>
            <p style={{ color: 'var(--emp-text-muted)', fontSize: '14px', marginBottom: '20px' }}>
              Your device reports you are outside the office (or GPS failed). Please provide a reason to force check in.
            </p>
            <textarea
              style={{ width: '100%', padding: '12px', border: '1px solid var(--emp-border)', borderRadius: '12px', marginBottom: '16px', minHeight: '80px', fontFamily: 'inherit' }}
              placeholder="e.g., I am in the office but GPS is inaccurate"
              value={forgotCheckInReason}
              onChange={(e) => setForgotCheckInReason(e.target.value)}
            />
            <div style={{ display: 'flex', gap: '12px' }}>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: '1px solid var(--emp-border)', backgroundColor: '#fff', fontWeight: 'bold' }}
                onClick={() => setShowForgotCheckInModal(false)}
                disabled={forgotCheckInLoading}
              >
                Cancel
              </button>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: 'none', backgroundColor: 'var(--emp-primary)', color: 'white', fontWeight: 'bold', display: 'flex', justifyContent: 'center' }}
                onClick={handleForgotCheckInSubmit}
                disabled={forgotCheckInLoading || !forgotCheckInReason}
              >
                {forgotCheckInLoading ? <div className="skeuo-loader sm"></div> : 'Submit & Check In'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
