import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase/client';
import { Loader2, Download, Search, ChevronLeft, ChevronRight, ChevronDown, ChevronUp, MapPin, X, Edit2 } from 'lucide-react';
import { format, differenceInSeconds } from 'date-fns';
import CalendarModal from '../../components/CalendarModal';
import ExcelJS from 'exceljs';
import { saveAs } from 'file-saver';

export default function AdminAttendance() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [expandedRowId, setExpandedRowId] = useState(null);
  const [showCalendar, setShowCalendar] = useState(false);
  const [editLog, setEditLog] = useState(null);
  const [editSessions, setEditSessions] = useState([]);
  const [isSavingEdit, setIsSavingEdit] = useState(false);
  
  // CSV Export Modal State
  const [showExportModal, setShowExportModal] = useState(false);
  const [exportMonth, setExportMonth] = useState(new Date().getMonth() + 1);
  const [exportYear, setExportYear] = useState(new Date().getFullYear());
  const [isExporting, setIsExporting] = useState(false);
  
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
          employee_id,
          date,
          status,
          total_work_minutes,
          total_break_minutes,
          profiles (
            full_name,
            employee_code
          ),
          work_sessions (
            id,
            started_at,
            ended_at
          ),
          attendance_events (
            id,
            event_type,
            session_type,
            timestamp,
            latitude,
            longitude
          ),
          attendance_corrections (
            id,
            reason,
            status,
            created_at
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


  const handleEditLogClick = (log, e) => {
    e.stopPropagation();
    setEditLog(log);
    const sessions = (log.work_sessions || []).map(ws => ({
      id: ws.id,
      started_at: ws.started_at ? format(new Date(ws.started_at), "yyyy-MM-dd'T'HH:mm") : '',
      ended_at: ws.ended_at ? format(new Date(ws.ended_at), "yyyy-MM-dd'T'HH:mm") : '',
      original_started_at: ws.started_at,
      original_ended_at: ws.ended_at
    }));
    setEditSessions(sessions);
  };

  const handleSessionChange = (id, field, value) => {
    setEditSessions(prev => prev.map(s => s.id === id ? { ...s, [field]: value } : s));
  };

  const handleSaveEdit = async () => {
    setIsSavingEdit(true);
    try {
      for (const session of editSessions) {
        const oldSession = editLog.work_sessions.find(ws => ws.id === session.id);
        if (!oldSession) continue;

        let updates = {};
        if (session.started_at && new Date(session.started_at).toISOString() !== new Date(oldSession.started_at).toISOString()) {
          updates.started_at = new Date(session.started_at).toISOString();
          
          await supabase.from('attendance_events')
            .update({ timestamp: updates.started_at })
            .eq('attendance_day_id', editLog.id)
            .eq('event_type', 'session_started')
            .eq('timestamp', oldSession.started_at);
        }

        if (session.ended_at && oldSession.ended_at && new Date(session.ended_at).toISOString() !== new Date(oldSession.ended_at).toISOString()) {
          updates.ended_at = new Date(session.ended_at).toISOString();
          
          await supabase.from('attendance_events')
            .update({ timestamp: updates.ended_at })
            .eq('attendance_day_id', editLog.id)
            .eq('event_type', 'session_ended')
            .eq('timestamp', oldSession.ended_at);
        }

        if (Object.keys(updates).length > 0) {
          await supabase.from('work_sessions')
            .update(updates)
            .eq('id', session.id);
        }
      }

      await supabase.rpc('rpc_update_day_totals', { p_attendance_day_id: editLog.id });
      
      await supabase.from('attendance_corrections').insert({
        employee_id: editLog.employee_id,
        attendance_day_id: editLog.id,
        status: 'resolved',
        reason: 'Admin Manual Edit'
      });
      
      setEditLog(null);
      await fetchLogs();
    } catch (err) {
      console.error(err);
      alert('Failed to save edits: ' + err.message);
    } finally {
      setIsSavingEdit(false);
    }
  };

  const generateMonthlyExcel = async () => {
    try {
      setIsExporting(true);
      
      const startDate = new Date(exportYear, exportMonth - 1, 1);
      const endDate = new Date(exportYear, exportMonth, 0);
      const daysInMonth = endDate.getDate();
      
      const startDateStr = format(startDate, 'yyyy-MM-dd');
      const endDateStr = format(endDate, 'yyyy-MM-dd');

      // 1. Fetch all active profiles excluding admins
      const { data: profilesData, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, employee_code, status, role')
        .eq('status', 'active')
        .neq('role', 'admin');
      
      if (profilesError) throw profilesError;

      // 2. Fetch attendance_days for the month with nested work_sessions
      const { data: attendanceData, error: attendanceError } = await supabase
        .from('attendance_days')
        .select(`
          employee_id, date, status, total_work_minutes, total_break_minutes,
          work_sessions ( started_at, ended_at )
        `)
        .gte('date', startDateStr)
        .lte('date', endDateStr);

      if (attendanceError) throw attendanceError;

      // 3. Create Excel Workbook
      const workbook = new ExcelJS.Workbook();
      const sheet = workbook.addWorksheet('Monthly Attendance');

      const daysHeaders = Array.from({ length: daysInMonth }, (_, i) => i + 1);
      
      // Define Columns
      const columns = [
        { header: 'Employee Code', key: 'code', width: 16 },
        { header: 'Employee Name', key: 'name', width: 25 },
        ...daysHeaders.map(d => ({ header: String(d), key: `day_${d}`, width: 14 })),
        { header: 'Total Days Present', key: 'present', width: 20 },
        { header: 'Total Days Absent', key: 'absent', width: 20 },
        { header: 'Total Work Time', key: 'work_time', width: 20 },
        { header: 'Total Break Time', key: 'break_time', width: 20 }
      ];
      
      sheet.columns = columns;

      // Format Header Row
      const headerRow = sheet.getRow(1);
      headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      headerRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF1F2937' } // Dark gray/blue
      };
      headerRow.alignment = { vertical: 'middle', horizontal: 'center' };
      headerRow.height = 30;

      // Freeze first 2 columns and header row
      sheet.views = [
        { state: 'frozen', xSplit: 2, ySplit: 1 }
      ];

      const formatDurationMins = (totalMins) => {
        if (!totalMins) return '0h 0m';
        const h = Math.floor(totalMins / 60);
        const m = Math.floor(totalMins % 60);
        return `${h}h ${m}m`;
      };

      // Populate Rows
      profilesData.forEach((emp, index) => {
        const empLogs = attendanceData.filter(log => log.employee_id === emp.id);
        
        let presentCount = 0;
        let absentCount = 0;
        let totalWork = 0;
        let totalBreak = 0;

        const rowData = {
          code: emp.employee_code || '-',
          name: emp.full_name || 'Unknown',
        };

        daysHeaders.forEach(dayNum => {
          const dateObj = new Date(exportYear, exportMonth - 1, dayNum);
          const isSunday = dateObj.getDay() === 0;
          const dayStr = format(dateObj, 'yyyy-MM-dd');
          const log = empLogs.find(l => l.date === dayStr);
          const cellKey = `day_${dayNum}`;
          
          if (!log) {
            rowData[cellKey] = isSunday ? 'SUNDAY' : '-';
          } else {
            let cellContent = [];
            if (isSunday) cellContent.push("SUNDAY");

            if (log.status === 'absent') {
              absentCount++;
              cellContent.push("Absent");
              rowData[cellKey] = cellContent.join('\n');
            } else {
              presentCount++;
              totalWork += (log.total_work_minutes || 0);
              totalBreak += (log.total_break_minutes || 0);
              
              const sessions = log.work_sessions || [];
              if (sessions.length > 0) {
                const starts = sessions.map(s => new Date(s.started_at).getTime());
                const ends = sessions.filter(s => s.ended_at).map(s => new Date(s.ended_at).getTime());
                
                const firstIn = new Date(Math.min(...starts));
                cellContent.push(`In: ${format(firstIn, 'hh:mm a')}`);
                
                if (ends.length > 0) {
                  const lastOut = new Date(Math.max(...ends));
                  cellContent.push(`Out: ${format(lastOut, 'hh:mm a')}`);
                } else {
                  cellContent.push(`Out: --`);
                }
              }

              cellContent.push(`W: ${formatDurationMins(log.total_work_minutes || 0)}`);
              cellContent.push(`B: ${formatDurationMins(log.total_break_minutes || 0)}`);
              
              rowData[cellKey] = cellContent.join('\n');
            }
          }
        });

        rowData.present = presentCount;
        rowData.absent = absentCount;
        rowData.work_time = formatDurationMins(totalWork);
        rowData.break_time = formatDurationMins(totalBreak);

        const newRow = sheet.addRow(rowData);
        newRow.height = 70; // Make height taller for multi-line
        
        // Apply alignment and conditional formatting to cells
        newRow.eachCell({ includeEmpty: true }, (cell, colNumber) => {
          cell.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
          cell.border = {
            top: { style: 'thin', color: { argb: 'FFEEEEEE' } },
            left: { style: 'thin', color: { argb: 'FFEEEEEE' } },
            bottom: { style: 'thin', color: { argb: 'FFEEEEEE' } },
            right: { style: 'thin', color: { argb: 'FFEEEEEE' } }
          };

          // Stripe alternating rows (columns 1 and 2 mostly)
          if (index % 2 === 0) {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF9FAFB' } };
          } else {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFFFFF' } };
          }

          // If it's a day column (3 to 3+daysInMonth-1)
          if (colNumber > 2 && colNumber <= 2 + daysInMonth) {
            const val = cell.value;
            if (val === 'SUNDAY') {
              cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEE2E2' } }; // Light red
              cell.font = { color: { argb: 'FFEF4444' }, bold: true };
            } else if (val && val.includes('SUNDAY')) {
              // Worked on Sunday
              cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEE2E2' } };
            } else if (val === 'Absent' || (val && val.includes('Absent'))) {
               cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEE2E2' } }; 
               cell.font = { color: { argb: 'FFEF4444' }, bold: true };
            }
          }
        });
      });

      // Write and save
      const buffer = await workbook.xlsx.writeBuffer();
      const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      saveAs(blob, `monthly_attendance_summary_${exportYear}_${exportMonth.toString().padStart(2, '0')}.xlsx`);
      
      setShowExportModal(false);
    } catch (err) {
      console.error(err);
      setError('Failed to generate monthly Excel');
    } finally {
      setIsExporting(false);
    }
  };

  if (loading) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><Loader2 className="spinner" size={32} /></div>;
  }

  return (
    <div>
      <div className="admin-page-header">
        <div>
          <h1>Daily Attendance Logs</h1>
          <p>View employee attendance records for a specific day.</p>
        </div>
        <button className="admin-btn secondary" onClick={() => setShowExportModal(true)} style={{ marginTop: '16px' }}>
          <Download size={16} />
          Export Excel
        </button>
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
        <div className="admin-table-header" style={{ display: 'flex', flexWrap: 'wrap', gap: '16px', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <h2 style={{ margin: 0 }}>Attendance History</h2>
          
          <div style={{ position: 'relative', flex: '1', minWidth: '200px', maxWidth: '300px' }}>
            <Search size={16} style={{ position: 'absolute', left: '12px', top: '14px', color: 'var(--admin-text-muted)' }} />
            <input 
              type="text" 
              placeholder="Search by name, ID, or Date..."
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
                  let calculatedBreakMins = log.total_break_minutes || 0;

                  if (log.work_sessions && log.work_sessions.length > 0) {
                    const sortedSessions = [...log.work_sessions].sort((a, b) => new Date(a.started_at) - new Date(b.started_at));
                    firstInStr = format(new Date(sortedSessions[0].started_at), 'hh:mm a');
                    
                    const lastSession = sortedSessions[sortedSessions.length - 1];
                    if (lastSession.ended_at) {
                      lastOutStr = format(new Date(lastSession.ended_at), 'hh:mm a');
                    } else {
                      lastOutStr = 'Working...';
                      
                      // Calculate live durations for active session
                      const sortedEvents = [...(log.attendance_events || [])].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
                      const latestEvent = sortedEvents[0];
                      
                      const isCurrentlyOnBreak = latestEvent && latestEvent.event_type === 'break_out';
                      const activeEndTime = isCurrentlyOnBreak ? new Date(latestEvent.timestamp) : new Date();
                      
                      const activeGrossMins = (activeEndTime - new Date(lastSession.started_at)) / 60000;
                      calculatedWorkMins += activeGrossMins;
                      
                      if (isCurrentlyOnBreak) {
                        calculatedBreakMins += (new Date() - new Date(latestEvent.timestamp)) / 60000;
                      }
                    }

                    // Fallback for completely corrupted old records
                    if (calculatedWorkMins < 0 && !lastSession.ended_at) {
                       // Do nothing, the live calculation above fixed it
                    } else if (calculatedWorkMins === 0 && lastSession.ended_at) {
                      let rawMins = 0;
                      sortedSessions.forEach(ws => {
                         const end = ws.ended_at ? new Date(ws.ended_at) : new Date();
                         const start = new Date(ws.started_at);
                         rawMins += (end - start) / 60000;
                      });
                      calculatedWorkMins = Math.floor(rawMins);
                    }
                  }
                  
                  calculatedWorkMins = Math.max(0, Math.floor(calculatedWorkMins));
                  calculatedBreakMins = Math.max(0, Math.floor(calculatedBreakMins));

                  const isExpanded = expandedRowId === log.id;
                  const handleToggle = (e) => {
                    e.stopPropagation();
                    if (isExpanded) {
                      setExpandedRowId(null);
                    } else {
                      setExpandedRowId(log.id);
                    }
                  };

                  return (
                    <React.Fragment key={log.id}>
                      <tr onClick={handleToggle} style={{ cursor: 'pointer', backgroundColor: isExpanded ? '#f9fafb' : 'transparent', position: 'relative', zIndex: 50 }}>
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
                          {formatDuration(calculatedBreakMins)}
                        </td>
                      </tr>
                      {isExpanded && log.attendance_events && log.attendance_events.length > 0 && (
                        <tr style={{ padding: 0, border: 'none', backgroundColor: 'transparent' }}>
                          <td colSpan="7" style={{ padding: '0', backgroundColor: 'transparent' }}>
                            <div style={{ padding: '24px', backgroundColor: '#f9fafb', borderRadius: 'var(--admin-radius-lg)', border: '1px solid var(--admin-border)' }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', margin: '0 0 16px 0' }}>
                                <h4 style={{ margin: 0, fontSize: '14px', color: 'var(--admin-text-dark)' }}>Detailed Timeline Log</h4>
                                <button
                                  onClick={(e) => handleEditLogClick(log, e)}
                                  className="admin-btn secondary"
                                  style={{ padding: '6px 12px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                                >
                                  <Edit2 size={14} /> Edit Times
                                </button>
                              </div>
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
                                      <div key={evt.id} style={{ display: 'flex', alignItems: 'flex-start', marginBottom: '24px', position: 'relative' }}>
                                        {/* Timeline Left Column (Line + Dot) */}
                                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginRight: '16px', marginTop: '4px', width: '12px' }}>
                                          <div style={{ width: '10px', height: '10px', borderRadius: '50%', backgroundColor: isIn ? '#10b981' : isOut ? '#ef4444' : '#6b7280', zIndex: 2, position: 'relative', boxShadow: `0 0 0 3px ${isIn ? '#d1fae5' : isOut ? '#fee2e2' : '#f3f4f6'}` }}></div>
                                          {idx < arr.length - 1 && (
                                            <div style={{ position: 'absolute', top: '14px', bottom: '-24px', left: '5px', width: '2px', backgroundColor: '#e5e7eb', zIndex: 1 }}></div>
                                          )}
                                        </div>
                                        
                                        {/* Timeline Content */}
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                          <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: '8px', marginBottom: '6px' }}>
                                            <h4 style={{ margin: 0, fontSize: '14px', color: 'var(--admin-text-dark)', fontWeight: '600' }}>{timeStr}</h4>
                                            
                                            <span style={{ 
                                              backgroundColor: isIn ? '#d1fae5' : isOut ? '#fee2e2' : '#f3f4f6', 
                                              color: isIn ? '#059669' : isOut ? '#dc2626' : '#4b5563', 
                                              fontSize: '10px', fontWeight: '700', padding: '2px 8px', 
                                              borderRadius: '999px', letterSpacing: '0.5px'
                                            }}>
                                              {badgeText}
                                            </span>

                                            {evt.latitude && evt.longitude && (
                                              <a 
                                                href={`https://www.google.com/maps/search/?api=1&query=${evt.latitude},${evt.longitude}`} 
                                                target="_blank" 
                                                rel="noopener noreferrer"
                                                title="View on Google Maps"
                                                style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', fontSize: '11px', color: 'var(--admin-primary)', textDecoration: 'none', backgroundColor: '#eef2ff', padding: '2px 8px', borderRadius: '999px', fontWeight: '500' }}
                                              >
                                                <MapPin size={10} /> Map
                                              </a>
                                            )}
                                          </div>
                                          <p style={{ margin: 0, fontSize: '13px', color: 'var(--admin-text-muted)', lineHeight: '1.4' }}>{durationStr}</p>
                                        </div>
                                      </div>
                                    );
                                  })
                                }
                              </div>
                              
                              {/* Display all override requests for this day below the timeline */}
                              {log.attendance_corrections && log.attendance_corrections.length > 0 && (
                                <div style={{ marginTop: '24px', paddingTop: '16px', borderTop: '1px dashed var(--admin-border)' }}>
                                  <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--admin-text-dark)' }}>Override & Admin Actions for this Day</h4>
                                  {log.attendance_corrections.map(c => (
                                    <div key={c.id} style={{ marginBottom: '8px', padding: '10px 12px', backgroundColor: '#fff7ed', borderLeft: '3px solid #f97316', borderRadius: '4px', fontSize: '12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <strong style={{ color: '#c2410c' }}>{c.reason.startsWith('Admin Force') ? 'Admin Action' : 'Employee Request'}</strong>
                                        <span style={{ color: '#ea580c', fontSize: '11px' }}>{format(new Date(c.created_at), 'hh:mm a')}</span>
                                      </div>
                                      <span style={{ color: '#9a3412' }}>{c.reason}</span>
                                    </div>
                                  ))}
                                </div>
                              )}
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
      {showExportModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: 'var(--admin-card-bg)', borderRadius: '24px',
            width: '100%', maxWidth: '450px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)'
          }}>
            <div style={{ padding: '24px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ margin: 0, fontSize: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Download size={20} color="var(--admin-primary)" />
                Export Monthly Excel
              </h2>
              <button onClick={() => setShowExportModal(false)} style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
                <X size={24} color="var(--admin-text-muted)" />
              </button>
            </div>
            
            <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <p style={{ margin: 0, fontSize: '14px', color: 'var(--admin-text-muted)' }}>
                Download a styled Excel spreadsheet of employee attendance totals for a specific month.
              </p>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Month
                  <select value={exportMonth} onChange={e => setExportMonth(parseInt(e.target.value))} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)', outline: 'none' }}>
                    <option value={1}>January</option>
                    <option value={2}>February</option>
                    <option value={3}>March</option>
                    <option value={4}>April</option>
                    <option value={5}>May</option>
                    <option value={6}>June</option>
                    <option value={7}>July</option>
                    <option value={8}>August</option>
                    <option value={9}>September</option>
                    <option value={10}>October</option>
                    <option value={11}>November</option>
                    <option value={12}>December</option>
                  </select>
                </label>

                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Year
                  <select value={exportYear} onChange={e => setExportYear(parseInt(e.target.value))} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)', outline: 'none' }}>
                    <option value={new Date().getFullYear()}>{new Date().getFullYear()}</option>
                    <option value={new Date().getFullYear() - 1}>{new Date().getFullYear() - 1}</option>
                    <option value={new Date().getFullYear() - 2}>{new Date().getFullYear() - 2}</option>
                  </select>
                </label>
              </div>
            </div>

            <div style={{ padding: '16px 24px', borderTop: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
              <button 
                className="admin-btn secondary" 
                onClick={() => setShowExportModal(false)}
                disabled={isExporting}
              >
                Cancel
              </button>
              <button 
                className="admin-btn primary" 
                onClick={generateMonthlyExcel}
                disabled={isExporting}
              >
                {isExporting ? <Loader2 size={18} className="spinner" /> : <Download size={18} />}
                {isExporting ? 'Generating...' : 'Download Excel'}
              </button>
            </div>
          </div>
        </div>
      )}

      {editLog && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: 'var(--admin-card-bg)', borderRadius: '24px',
            width: '100%', maxWidth: '500px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)',
            maxHeight: '90vh', overflowY: 'auto'
          }}>
            <div style={{ padding: '24px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'sticky', top: 0, backgroundColor: 'var(--admin-card-bg)', zIndex: 10 }}>
              <h2 style={{ margin: 0, fontSize: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Edit2 size={20} color="var(--admin-primary)" />
                Edit Attendance Times
              </h2>
              <button onClick={() => setEditLog(null)} style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
                <X size={24} color="var(--admin-text-muted)" />
              </button>
            </div>
            
            <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              <div style={{ backgroundColor: '#f9fafb', padding: '12px 16px', borderRadius: '8px', border: '1px solid var(--admin-border)' }}>
                <strong style={{ display: 'block', marginBottom: '4px', color: 'var(--admin-text-dark)' }}>{editLog.profiles?.full_name}</strong>
                <span style={{ fontSize: '13px', color: 'var(--admin-text-muted)' }}>Date: {editLog.date}</span>
              </div>
              
              {editSessions.map((session, idx) => (
                <div key={session.id} style={{ display: 'flex', flexDirection: 'column', gap: '12px', paddingBottom: '20px', borderBottom: idx < editSessions.length - 1 ? '1px dashed var(--admin-border)' : 'none' }}>
                  <h5 style={{ margin: 0, fontSize: '14px', color: 'var(--admin-text-dark)' }}>Work Session {idx + 1}</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                    <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                      Punch In Time
                      <input 
                        type="datetime-local" 
                        value={session.started_at} 
                        onChange={(e) => handleSessionChange(session.id, 'started_at', e.target.value)}
                        style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)', outline: 'none' }}
                      />
                    </label>
                    <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                      Punch Out Time
                      <input 
                        type="datetime-local" 
                        value={session.ended_at} 
                        onChange={(e) => handleSessionChange(session.id, 'ended_at', e.target.value)}
                        style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)', outline: 'none' }}
                      />
                    </label>
                  </div>
                </div>
              ))}
              {editSessions.length === 0 && (
                <p style={{ color: 'var(--admin-text-muted)', fontSize: '14px', textAlign: 'center' }}>No work sessions recorded yet.</p>
              )}
            </div>

            <div style={{ padding: '16px 24px', borderTop: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'flex-end', gap: '12px', position: 'sticky', bottom: 0, backgroundColor: 'var(--admin-card-bg)', zIndex: 10 }}>
              <button 
                className="admin-btn secondary" 
                onClick={() => setEditLog(null)}
                disabled={isSavingEdit}
              >
                Cancel
              </button>
              <button 
                className="admin-btn primary" 
                onClick={handleSaveEdit}
                disabled={isSavingEdit || editSessions.length === 0}
              >
                {isSavingEdit ? <Loader2 size={18} className="spinner" /> : <Edit2 size={18} />}
                {isSavingEdit ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
