import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useGeolocation } from '../../hooks/useGeolocation';
import { Loader2, ChevronLeft, ChevronRight, Clock, RefreshCw, MapPin, Home, Briefcase, Calendar } from 'lucide-react';
import { format, differenceInSeconds } from 'date-fns';
import CalendarModal from '../../components/CalendarModal';

export default function EmployeeDashboard() {
  const { profile } = useAuth();
  const { getLocationAndValidate } = useGeolocation();
  
  const [loading, setLoading] = useState(true);
  const [initialLoad, setInitialLoad] = useState(true);
  const [error, setError] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  
  const [sessionState, setSessionState] = useState({
    activeSession: null,
    events: [],
    todayDayId: null,
    todayTotalWorkMinutes: 0
  });

  const [selectedDate, setSelectedDate] = useState(new Date());
  const [showCalendar, setShowCalendar] = useState(false);
  const [liveTimer, setLiveTimer] = useState(0);
  const [workTargetHours, setWorkTargetHours] = useState(8); // default to 8
  
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
      
      // 2. Get active work_session (if any)
      const { data: sessions, error: sessErr } = await supabase
        .from('work_sessions')
        .select('*')
        .eq('employee_id', profile.id)
        .in('status', ['working', 'on_break']);
        
      if (sessErr) throw sessErr;
      
      const activeSession = sessions && sessions.length > 0 ? sessions[0] : null;

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
  }, [profile, selectedDate]);

  // Handle actions
  const handleAction = async (actionType) => {
    setActionLoading(true);
    setError(null);
    try {
      let geo = { lat: 0, lng: 0 };
      let rpcSessionType = null;
      
      // Request location based on action
      if (actionType.startsWith('start_')) {
         rpcSessionType = actionType.replace('start_', '');
         const { location, validation } = await getLocationAndValidate(rpcSessionType); 
         
         if (rpcSessionType === 'office' && validation && !validation.isWithin) {
            throw new Error(`You are too far from the office to clock in! You are ${Math.round(validation.distance)} meters away.`);
         }
         
         geo = { lat: location.latitude, lng: location.longitude };
      } else {
         // Generic location for other actions
         const pos = await new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 10000 });
         });
         geo = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      }

      const rpcName = 
        actionType.startsWith('start_') ? 'rpc_start_session' :
        actionType === 'break_out' ? 'rpc_toggle_break' :
        actionType === 'break_in' ? 'rpc_toggle_break' :
        actionType === 'end' ? 'rpc_end_day' : null;

      const args = actionType.startsWith('start_') 
        ? { p_session_type: rpcSessionType, p_lat: geo.lat, p_lng: geo.lng }
        : { p_lat: geo.lat, p_lng: geo.lng };

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

  // Calculate live timer (very basic implementation for UI purposes)
  useEffect(() => {
    let interval;
    if (sessionState.activeSession && sessionState.activeSession.status === 'working') {
      interval = setInterval(() => {
        const start = new Date(sessionState.activeSession.started_at);
        const diff = differenceInSeconds(new Date(), start);
        setLiveTimer(diff);
      }, 1000);
    } else {
      setLiveTimer(0);
    }
    return () => clearInterval(interval);
  }, [sessionState.activeSession]);

  const formatTimer = (totalSeconds) => {
    const h = Math.floor(totalSeconds / 3600).toString().padStart(2, '0');
    const m = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, '0');
    const s = (totalSeconds % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  };

  // Target calculation
  const totalWorkedSeconds = (sessionState.todayTotalWorkMinutes * 60) + (isToday ? liveTimer : 0);
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

  if (initialLoad) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><Loader2 className="spinner" size={32} /></div>;
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
          {loading && !initialLoad && <Loader2 className="spinner" size={14} style={{ color: 'var(--emp-primary)' }} />}
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
            <div className="emp-action-grid">
              {!sessionState.activeSession ? (
                <>
                  <button className="emp-btn-square" onClick={() => handleAction('start_office')} disabled={actionLoading}>
                    <div style={{ backgroundColor: '#d1fae5', padding: '8px', borderRadius: '50%', color: 'var(--emp-primary)' }}><Briefcase size={20} /></div>
                    Office
                  </button>
                  <button className="emp-btn-square" onClick={() => handleAction('start_wfh')} disabled={actionLoading}>
                    <div style={{ backgroundColor: '#e0e7ff', padding: '8px', borderRadius: '50%', color: '#4f46e5' }}><Home size={20} /></div>
                    WFH
                  </button>
                  <button className="emp-btn-square" onClick={() => handleAction('start_field_work')} disabled={actionLoading}>
                    <div style={{ backgroundColor: '#fef3c7', padding: '8px', borderRadius: '50%', color: '#d97706' }}><MapPin size={20} /></div>
                    Field
                  </button>
                </>
              ) : (
                <>
                  <button className="emp-btn-square danger" onClick={() => handleAction('end')} disabled={actionLoading}>
                     <div style={{ backgroundColor: '#fef2f2', padding: '8px', borderRadius: '50%', color: 'var(--emp-danger)' }}><Clock size={20} /></div>
                     Check Out
                  </button>
                  <button className={`emp-btn-square ${sessionState.activeSession.status === 'on_break' ? 'active' : ''}`} onClick={() => handleAction(sessionState.activeSession.status === 'on_break' ? 'break_in' : 'break_out')} disabled={actionLoading}>
                     <div style={{ backgroundColor: sessionState.activeSession.status === 'on_break' ? 'rgba(255,255,255,0.2)' : '#fef3c7', padding: '8px', borderRadius: '50%', color: sessionState.activeSession.status === 'on_break' ? 'white' : '#f59e0b' }}><Clock size={20} /></div>
                     {sessionState.activeSession.status === 'on_break' ? 'Resume Work' : 'Take Break'}
                  </button>
                </>
              )}
            </div>
          )}

          {error && (
            <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', fontSize: '14px' }}>
              {error}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
