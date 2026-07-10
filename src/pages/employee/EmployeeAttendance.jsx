import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { Loader2, ChevronLeft, ChevronRight, RefreshCw, CalendarDays } from 'lucide-react';
import { format, differenceInSeconds } from 'date-fns';
import CalendarModal from '../../components/CalendarModal';
import './Employee.css';

export default function EmployeeAttendance() {
  const { profile } = useAuth();
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [events, setEvents] = useState([]);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [showCalendar, setShowCalendar] = useState(false);
  
  const isToday = format(selectedDate, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd');

  const fetchLogs = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const targetDateStr = format(selectedDate, 'yyyy-MM-dd');

      const { data: days, error: dayErr } = await supabase
        .from('attendance_days')
        .select('id')
        .eq('employee_id', profile.id)
        .eq('date', targetDateStr);
        
      if (dayErr) throw dayErr;
      
      let dayId = days && days.length > 0 ? days[0].id : null;
      let fetchedEvents = [];

      if (dayId) {
        const { data: evts, error: evtErr } = await supabase
          .from('attendance_events')
          .select('*')
          .eq('attendance_day_id', dayId)
          .order('timestamp', { ascending: false });
          
        if (evtErr) throw evtErr;
        fetchedEvents = evts || [];
      }

      setEvents(fetchedEvents);
    } catch (err) {
      console.error(err);
      setError('Failed to fetch attendance logs.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (profile) {
      fetchLogs();
    }
  }, [profile, selectedDate]);

  const renderLog = () => {
    if (events.length === 0) {
      return (
        <div style={{ textAlign: 'center', padding: '32px', color: 'var(--emp-text-muted)' }}>
          <div style={{ backgroundColor: '#e5e7eb', width: '48px', height: '48px', borderRadius: '8px', display: 'flex', justifyContent: 'center', alignItems: 'center', margin: '0 auto 16px auto' }}>
            <CalendarDays size={24} color="#9ca3af" />
          </div>
          <p>No activity logged for this date.</p>
        </div>
      );
    }

    return events.map((evt, idx) => {
      const timeStr = format(new Date(evt.timestamp), 'hh:mm:ss a');
      const isIn = evt.event_type === 'session_started' || evt.event_type === 'break_in';
      const isOut = evt.event_type === 'session_ended' || evt.event_type === 'break_out' || evt.event_type === 'day_ended';
      
      let durationStr = 'Active now';
      if (idx > 0) {
        const nextEvt = events[idx - 1]; 
        const diffSecs = differenceInSeconds(new Date(nextEvt.timestamp), new Date(evt.timestamp));
        const hrs = Math.floor(diffSecs / 3600);
        const mins = Math.floor((diffSecs % 3600) / 60);
        const secs = diffSecs % 60;
        durationStr = isIn ? `Worked ${hrs}h ${mins}m ${secs}s` : `Away for ${hrs}h ${mins}m ${secs}s`;
      }

      let badgeText = 'SYS';
      if (evt.event_type === 'break_out') {
         badgeText = 'BREAK';
      } else if (evt.event_type === 'break_in') {
         badgeText = 'BACK';
      } else if (evt.event_type === 'session_started') {
         badgeText = evt.session_type ? evt.session_type.toUpperCase() : 'IN';
      } else if (evt.event_type === 'session_ended' || evt.event_type === 'day_ended') {
         badgeText = 'OUT';
      }

      return (
        <div key={evt.id} className={`emp-log-row ${isIn ? 'in' : isOut ? 'out' : ''}`}>
          <div className={`emp-log-tag ${isIn ? 'in' : isOut ? 'out' : ''}`}>
            {badgeText}
          </div>
          <div className="emp-log-details">
            <h4>{timeStr}</h4>
            <p>{durationStr}</p>
          </div>
        </div>
      );
    });
  };

  return (
    <>
      <div className="emp-header-card" style={{ marginBottom: '16px', padding: '16px', borderRadius: 'var(--emp-radius-lg)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
         <h2 style={{ margin: 0, fontSize: '18px' }}>Attendance Log</h2>
         <RefreshCw className="emp-icon-btn" size={20} onClick={fetchLogs} style={{ color: 'white', cursor: 'pointer' }} />
      </div>

      <div className="emp-date-scroller" style={{ marginBottom: '16px' }}>
        <ChevronLeft 
          className="emp-icon-btn" 
          size={20} 
          onClick={() => {
            const prev = new Date(selectedDate.getTime() - 86400000);
            setSelectedDate(prev);
          }} 
        />
        
        <span 
          className="emp-date-text" 
          onClick={() => setShowCalendar(true)}
          style={{ cursor: 'pointer' }}
        >
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

      {error && (
        <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', fontSize: '14px', marginBottom: '16px' }}>
          {error}
        </div>
      )}

      {loading ? (
        <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><div className="skeuo-loader"></div></div>
      ) : (
        <div className="emp-log-card" style={{ padding: '20px' }}>
          {renderLog()}
        </div>
      )}
    </>
  );
}
