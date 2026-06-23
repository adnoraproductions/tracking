import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase/client';
import { Loader2, Download, Search, ChevronLeft, ChevronRight, ChevronDown, ChevronUp, MapPin, X } from 'lucide-react';
import { format, differenceInSeconds } from 'date-fns';
import CalendarModal from '../../components/CalendarModal';

export default function AdminAttendance() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [expandedRows, setExpandedRows] = useState({});
  const [showCalendar, setShowCalendar] = useState(false);
  
  const isToday = format(selectedDate, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd');

  useEffect(() => {
    fetchLogs();
  }, [selectedDate]);

  const fetchLogs = async () => {
    try {
      setLoading(true);
      const targetDateStr = format(selectedDate, 'yyyy-MM-dd');

      const { data, error } = await supabase
        .from('attendance_days')
        .select(`
          id,
          date,
          status,
          total_work_minutes,
          total_break_minutes,
          profiles (
            full_name,
            employee_code
          ),
          work_sessions (
            started_at,
            ended_at
          ),
          attendance_events (
            id,
            event_type,
            session_type,
            timestamp
          )
        `)
        .eq('date', targetDateStr);

      if (error) throw error;
      setLogs(data || []);
    } catch (err) {
      console.error(err);
      setError('Failed to load attendance logs');
    } finally {
      setLoading(false);
    }
  };

  const formatDuration = (minutes) => {
    if (!minutes) return '0h 0m';
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return `${h}h ${m}m`;
  };

  const filteredLogs = logs.filter(log => {
    const term = searchTerm.toLowerCase();
    const nameMatch = log.profiles?.full_name?.toLowerCase().includes(term);
    const codeMatch = log.profiles?.employee_code?.toLowerCase().includes(term);
    const dateMatch = log.date.includes(term);
    return nameMatch || codeMatch || dateMatch;
  });

  const exportToCSV = () => {
    if (filteredLogs.length === 0) return;

    const headers = ['Date', 'Employee Name', 'Employee Code', 'Status', 'First In', 'Last Out', 'Total Worked', 'Total Break'];
    
    const csvRows = [
      headers.join(','),
      ...filteredLogs.map(log => {
        const date = format(new Date(log.date), 'dd MMM yyyy');
        const name = log.profiles?.full_name || 'Unknown';
        const code = log.profiles?.employee_code || '-';
        const status = log.status.toUpperCase();
        
        let firstInStr = '-';
        let lastOutStr = '-';
        let calculatedWorkMins = log.total_work_minutes || 0;

        if (log.work_sessions && log.work_sessions.length > 0) {
          const sortedSessions = [...log.work_sessions].sort((a, b) => new Date(a.started_at) - new Date(b.started_at));
          firstInStr = format(new Date(sortedSessions[0].started_at), 'hh:mm a');
          
          const lastSession = sortedSessions[sortedSessions.length - 1];
          if (lastSession.ended_at) {
            lastOutStr = format(new Date(lastSession.ended_at), 'hh:mm a');
          } else {
            lastOutStr = 'Working...';
          }

          if (calculatedWorkMins === 0) {
            let rawMins = 0;
            sortedSessions.forEach(ws => {
               const end = ws.ended_at ? new Date(ws.ended_at) : new Date();
               const start = new Date(ws.started_at);
               rawMins += (end - start) / 60000;
            });
            calculatedWorkMins = Math.floor(rawMins);
          }
        }

        const totalWorked = formatDuration(calculatedWorkMins);
        const totalBreak = formatDuration(log.total_break_minutes);

        return `"${date}","${name}","${code}","${status}","${firstInStr}","${lastOutStr}","${totalWorked}","${totalBreak}"`;
      })
    ];

    const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);
    link.setAttribute("href", url);
    link.setAttribute("download", `attendance_logs_${format(new Date(), 'yyyyMMdd')}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><Loader2 className="spinner" size={32} /></div>;
  }

  return (
    <div>
      <div className="admin-page-header">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <h1>Daily Attendance Logs</h1>
            <p>View employee attendance records for a specific day.</p>
          </div>
          <button className="admin-btn secondary" onClick={exportToCSV}>
            <Download size={16} />
            Export CSV
          </button>
        </div>
      </div>

      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        gap: '24px', 
        marginBottom: '24px',
        backgroundColor: 'var(--admin-card-bg)',
        padding: '16px',
        borderRadius: 'var(--admin-radius-lg)',
        border: '1px solid var(--admin-border)'
      }}>
        <button 
          style={{ background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
          onClick={() => setSelectedDate(new Date(selectedDate.getTime() - 86400000))} 
        >
          <ChevronLeft size={20} color="var(--admin-text-dark)" />
        </button>
        
        <span 
          onClick={() => setShowCalendar(true)}
          style={{ cursor: 'pointer', position: 'relative', fontWeight: '600', color: 'var(--admin-text-dark)' }}
          title="Choose a date"
        >
          {isToday ? 'Today · ' : ''}{format(selectedDate, 'EEE, dd MMM')}
        </span>

        <CalendarModal 
          isOpen={showCalendar} 
          onClose={() => setShowCalendar(false)} 
          selectedDate={selectedDate} 
          onSelectDate={setSelectedDate} 
        />

        <button 
          style={{ background: 'transparent', border: 'none', cursor: isToday ? 'not-allowed' : 'pointer', opacity: isToday ? 0.3 : 1, display: 'flex', alignItems: 'center' }}
          onClick={() => {
            const next = new Date(selectedDate.getTime() + 86400000);
            if (format(next, 'yyyy-MM-dd') <= format(new Date(), 'yyyy-MM-dd')) {
              setSelectedDate(next);
            }
          }}
        >
          <ChevronRight size={20} color="var(--admin-text-dark)" />
        </button>
      </div>

      {error && (
        <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
          {error}
        </div>
      )}

      <div className="admin-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <h2>Attendance History</h2>
          
          <div style={{ position: 'relative', width: '300px' }}>
            <Search size={16} style={{ position: 'absolute', left: '12px', top: '14px', color: 'var(--admin-text-muted)' }} />
            <input 
              type="text" 
              placeholder="Search by name, ID, or YYYY-MM-DD..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '12px 16px 12px 36px', border: '1px solid var(--admin-border)', borderRadius: '12px', outline: 'none' }}
            />
          </div>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th style={{ width: '40px' }}></th>
                <th>Employee</th>
                <th>Status</th>
                <th>First In</th>
                <th>Last Out</th>
                <th>Total Worked</th>
                <th>Total Break</th>
              </tr>
            </thead>
            <tbody>
              {filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '40px', color: 'var(--admin-text-muted)' }}>
                    No records found matching your search.
                  </td>
                </tr>
              ) : (
                filteredLogs.map(log => {
                  let firstInStr = '-';
                  let lastOutStr = '-';
                  
                  let calculatedWorkMins = log.total_work_minutes || 0;

                  if (log.work_sessions && log.work_sessions.length > 0) {
                    // Sort sessions by started_at
                    const sortedSessions = [...log.work_sessions].sort((a, b) => new Date(a.started_at) - new Date(b.started_at));
                    
                    firstInStr = format(new Date(sortedSessions[0].started_at), 'hh:mm a');
                    
                    // For last out, check if the last session has an ended_at
                    const lastSession = sortedSessions[sortedSessions.length - 1];
                    if (lastSession.ended_at) {
                      lastOutStr = format(new Date(lastSession.ended_at), 'hh:mm a');
                    } else {
                      lastOutStr = 'Working...';
                    }

                    // Fallback calculation for corrupted old 0 records
                    if (calculatedWorkMins === 0) {
                      let rawMins = 0;
                      sortedSessions.forEach(ws => {
                         const end = ws.ended_at ? new Date(ws.ended_at) : new Date();
                         const start = new Date(ws.started_at);
                         rawMins += (end - start) / 60000;
                      });
                      calculatedWorkMins = Math.floor(rawMins);
                    }
                  }

                  const isExpanded = !!expandedRows[log.id];
                  const toggleRow = () => {
                    setExpandedRows(prev => ({ ...prev, [log.id]: !prev[log.id] }));
                  };

                  return (
                    <React.Fragment key={log.id}>
                      <tr onClick={toggleRow} style={{ cursor: 'pointer', backgroundColor: isExpanded ? '#f9fafb' : 'transparent' }}>
                        <td style={{ textAlign: 'center', color: 'var(--admin-text-muted)' }}>
                          {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
                        </td>
                        <td data-label="Employee">
                          <div style={{ fontWeight: '600' }}>{log.profiles?.full_name || 'Unknown'}</div>
                          <div style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>{log.profiles?.employee_code || '-'}</div>
                        </td>
                        <td data-label="Status">
                          <span className={`admin-badge ${log.status === 'present' ? 'green' : log.status === 'absent' ? 'red' : 'gray'}`}>
                            {log.status.toUpperCase()}
                          </span>
                        </td>
                        <td data-label="First In" style={{ color: 'var(--admin-text-dark)' }}>{firstInStr}</td>
                        <td data-label="Last Out" style={{ color: 'var(--admin-text-dark)' }}>{lastOutStr}</td>
                        <td data-label="Total Worked" style={{ fontWeight: '600', color: 'var(--admin-primary)' }}>
                          {formatDuration(calculatedWorkMins)}
                        </td>
                        <td data-label="Total Break" style={{ color: 'var(--admin-text-muted)' }}>
                          {formatDuration(log.total_break_minutes)}
                        </td>
                      </tr>
                      {isExpanded && log.attendance_events && log.attendance_events.length > 0 && (
                        <tr>
                          <td colSpan="7" style={{ padding: '0', backgroundColor: '#f9fafb' }}>
                            <div style={{ padding: '24px', position: 'relative', borderTop: '1px solid var(--admin-border)', borderBottom: '2px solid var(--admin-border)' }}>
                              <button 
                                onClick={(e) => { e.stopPropagation(); toggleRow(); }} 
                                style={{ position: 'absolute', top: '16px', right: '16px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--admin-text-muted)', padding: '4px' }}
                                title="Close Details"
                              >
                                <X size={20} />
                              </button>
                              <h4 style={{ margin: '0 0 16px 0', fontSize: '14px', color: 'var(--admin-text-dark)' }}>Detailed Timeline Log</h4>
                              <div style={{ display: 'flex', flexDirection: 'column' }}>
                              {log.attendance_events
                                  .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
                                  .map((evt, idx, arr) => {
                                    const timeStr = format(new Date(evt.timestamp), 'hh:mm:ss a');
                                    const isIn = evt.event_type === 'session_started' || evt.event_type === 'break_in';
                                    const isOut = evt.event_type === 'session_ended' || evt.event_type === 'break_out' || evt.event_type === 'day_ended';
                                    
                                    let durationStr = 'Active now';
                                    if (idx > 0) {
                                      const nextEvt = arr[idx - 1]; 
                                      const diffSecs = differenceInSeconds(new Date(nextEvt.timestamp), new Date(evt.timestamp));
                                      const hrs = Math.floor(diffSecs / 3600);
                                      const mins = Math.floor((diffSecs % 3600) / 60);
                                      const secs = diffSecs % 60;
                                      durationStr = isIn 
                                        ? `Worked ${hrs}h ${mins}m ${secs}s` 
                                        : `Away for ${hrs}h ${mins}m ${secs}s`;
                                    }

                                    let badgeText = 'SYS';
                                    if (evt.event_type === 'break_out') badgeText = 'BREAK';
                                    else if (evt.event_type === 'break_in') badgeText = 'BACK';
                                    else if (evt.event_type === 'session_started') badgeText = evt.session_type ? evt.session_type.toUpperCase() : 'IN';
                                    else if (evt.event_type === 'session_ended' || evt.event_type === 'day_ended') badgeText = 'OUT';

                                    return (
                                      <div key={evt.id} style={{ display: 'flex', alignItems: 'flex-start', marginBottom: '16px', position: 'relative' }}>
                                        {/* Vertical line connector */}
                                        {idx < arr.length - 1 && (
                                          <div style={{ position: 'absolute', top: '24px', bottom: '-16px', left: '42px', width: '2px', backgroundColor: 'var(--admin-border)', zIndex: 0 }}></div>
                                        )}
                                        
                                        <div style={{ 
                                          backgroundColor: isIn ? '#10b981' : isOut ? '#ef4444' : '#6b7280', 
                                          color: 'white', fontSize: '11px', fontWeight: '700', padding: '4px 0', 
                                          borderRadius: '4px', width: '84px', textAlign: 'center', marginRight: '16px', zIndex: 1 
                                        }}>
                                          {badgeText}
                                        </div>
                                        <div>
                                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                                            <h4 style={{ margin: 0, fontSize: '14px', color: 'var(--admin-text-dark)' }}>{timeStr}</h4>
                                            {evt.latitude && evt.longitude && (
                                              <a 
                                                href={`https://www.google.com/maps/search/?api=1&query=${evt.latitude},${evt.longitude}`} 
                                                target="_blank" 
                                                rel="noopener noreferrer"
                                                title="View on Google Maps"
                                                style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '11px', color: 'var(--admin-primary)', textDecoration: 'none', backgroundColor: '#e0e7ff', padding: '2px 6px', borderRadius: '4px' }}
                                              >
                                                <MapPin size={12} /> Map
                                              </a>
                                            )}
                                          </div>
                                          <p style={{ margin: 0, fontSize: '12px', color: 'var(--admin-text-muted)' }}>{durationStr}</p>
                                        </div>
                                      </div>
                                    );
                                  })
                                }
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
