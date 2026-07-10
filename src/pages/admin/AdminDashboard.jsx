import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase/client';
import { Loader2, Users, Clock, AlertCircle, MapPin } from 'lucide-react';
import { format, differenceInMinutes } from 'date-fns';

export default function AdminDashboard() {
  const [activeSessions, setActiveSessions] = useState([]);
  const [pendingRequests, setPendingRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedCorrection, setSelectedCorrection] = useState(null);
  const [newExitTime, setNewExitTime] = useState('');
  const [resolving, setResolving] = useState(false);

  useEffect(() => {
    fetchLiveData();
    // In a real app, we would use Supabase Realtime subscriptions here
    const interval = setInterval(fetchLiveData, 30000); // Poll every 30s
    return () => clearInterval(interval);
  }, []);

  const fetchLiveData = async () => {
    try {
      const { data, error } = await supabase
        .from('work_sessions')
        .select(`
          id,
          status,
          started_at,
          session_type,
          start_latitude,
          start_longitude,
          profiles (
            id,
            full_name,
            employee_code
          )
        `)
        .in('status', ['working', 'on_break'])
        .order('started_at', { ascending: false });

      if (error) throw error;
      setActiveSessions(data || []);

      const { data: correctionsData, error: correctionsError } = await supabase
        .from('attendance_corrections')
        .select(`
          id,
          reason,
          created_at,
          work_session_id,
          profiles (
            full_name,
            employee_code
          )
        `)
        .eq('status', 'pending')
        .order('created_at', { ascending: false });

      if (correctionsError) {
        console.error("Failed to fetch corrections:", correctionsError);
        setPendingRequests([]);
      } else {
        setPendingRequests(correctionsData || []);
      }

    } catch (err) {
      console.error("Fatal error fetching live data:", err);
      setError('Failed to fetch live data');
    } finally {
      setLoading(false);
    }
  };

  const handleResolveRequest = async (id) => {
    try {
      const { error } = await supabase
        .from('attendance_corrections')
        .update({ status: 'resolved' })
        .eq('id', id);
      if (error) throw error;
      fetchLiveData();
    } catch (err) {
      console.error(err);
      alert('Failed to resolve request.');
    }
  };

  const handleFixExitTime = async () => {
    if (!newExitTime) return;
    setResolving(true);
    try {
      const exitTimestamp = new Date(newExitTime).toISOString();
      const { error } = await supabase.rpc('rpc_admin_fix_exit_time', {
        p_correction_id: selectedCorrection.id,
        p_work_session_id: selectedCorrection.work_session_id,
        p_new_exit_time: exitTimestamp
      });
      if (error) throw error;
      setSelectedCorrection(null);
      setNewExitTime('');
      fetchLiveData();
    } catch (err) {
      console.error(err);
      alert('Failed to fix exit time: ' + err.message);
    } finally {
      setResolving(false);
    }
  };

  if (loading) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><div className="skeuo-loader"></div></div>;
  }

  const workingCount = activeSessions.filter(s => s.status === 'working').length;
  const breakCount = activeSessions.filter(s => s.status === 'on_break').length;

  return (
    <div>
      {/* Skeuomorphic Header Card */}
      <div className="admin-header-card">
        <div>
          <h1>Live Workforce Monitor</h1>
          <p>Real-time overview of employees currently working or on break.</p>
        </div>
        
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', backgroundColor: 'rgba(255,255,255,0.1)', padding: '12px 24px', borderRadius: '16px', border: '1px solid rgba(255,255,255,0.1)' }}>
          <div style={{ color: '#10b981' }}>
            <Users size={28} />
          </div>
          <div>
            <div style={{ fontSize: '12px', color: '#9ca3af', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '600' }}>Total Active</div>
            <div style={{ fontSize: '32px', fontWeight: '700', color: 'white', lineHeight: '1', marginTop: '4px' }}>{activeSessions.length}</div>
          </div>
        </div>
      </div>

      {error && (
        <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
          {error}
        </div>
      )}

      {/* Skeuomorphic Metrics Row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px', marginBottom: '32px' }}>
        
        {/* Working - Dark LCD Style */}
        <div className="admin-timer-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
            <div style={{ backgroundColor: 'rgba(16,185,129,0.1)', width: '40px', height: '40px', borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
              <Clock size={20} />
            </div>
            <div style={{ padding: '6px 12px', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: '20px', fontSize: '12px', color: 'white', fontWeight: '600', border: '1px solid rgba(255,255,255,0.2)', whiteSpace: 'nowrap' }}>
              Active Now
            </div>
          </div>
          <div style={{ marginTop: 'auto', paddingTop: '24px' }}>
            <div style={{ fontSize: '12px', color: '#9ca3af', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '8px', fontWeight: '600' }}>Working</div>
            <div style={{ fontSize: '48px', fontWeight: '700', lineHeight: '1' }}>{workingCount}</div>
          </div>
        </div>

        {/* On Break - Light Skeuomorphic Style */}
        <div className="admin-info-card" style={{ justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
            <div style={{ backgroundColor: '#fef3c7', color: '#d97706', width: '40px', height: '40px', borderRadius: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', border: '1px solid #fde68a' }}>
              <AlertCircle size={20} />
            </div>
            <div style={{ padding: '6px 12px', backgroundColor: '#f3f4f6', borderRadius: '20px', fontSize: '12px', color: '#6b7280', fontWeight: '600', border: '1px solid #e5e7eb', whiteSpace: 'nowrap' }}>
              Paused
            </div>
          </div>
          <div style={{ marginTop: 'auto', paddingTop: '24px' }}>
            <div style={{ fontSize: '12px', color: 'var(--admin-text-muted)', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '8px', fontWeight: '600' }}>On Break</div>
            <div style={{ fontSize: '48px', fontWeight: '700', lineHeight: '1', color: 'var(--admin-text-dark)' }}>{breakCount}</div>
          </div>
        </div>

      </div>

      <div className="admin-card">
        <h2>Currently Checked In</h2>
        
        {activeSessions.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px', color: 'var(--admin-text-muted)' }}>
            <p>No employees are currently checked in.</p>
          </div>
        ) : (
          <div className="admin-table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Status</th>
                  <th>Location Type</th>
                  <th>Checked In At</th>
                  <th>Duration</th>
                </tr>
              </thead>
              <tbody>
                {activeSessions.map(session => {
                  const emp = session.profiles;
                  const mins = differenceInMinutes(new Date(), new Date(session.started_at));
                  const hours = Math.floor(mins / 60);
                  const remMins = mins % 60;
                  const durationStr = hours > 0 ? `${hours}h ${remMins}m` : `${remMins}m`;

                  return (
                    <tr key={session.id}>
                      <td data-label="Employee">
                        <div style={{ fontWeight: '600' }}>{emp?.full_name || 'Unknown'}</div>
                        <div style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>{emp?.employee_code || '-'}</div>
                      </td>
                      <td data-label="Status">
                        <span className={`admin-badge ${session.status === 'working' ? 'green' : 'gray'}`}>
                          {session.status === 'working' ? 'Working' : 'On Break'}
                        </span>
                      </td>
                      <td data-label="Location Type" style={{ textTransform: 'capitalize' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          {session.session_type === 'wfh' ? 'WFH' : session.session_type.replace('_', ' ')}
                          {session.session_type !== 'office' && session.start_latitude && session.start_longitude && (
                            <a 
                              href={`https://www.google.com/maps?q=${session.start_latitude},${session.start_longitude}`} 
                              target="_blank" 
                              rel="noopener noreferrer"
                              style={{ color: 'var(--admin-primary)', display: 'flex', alignItems: 'center' }}
                              title="View Location on Map"
                            >
                              <MapPin size={14} />
                            </a>
                          )}
                        </div>
                      </td>
                      <td data-label="Checked In At">{format(new Date(session.started_at), 'hh:mm a')}</td>
                      <td data-label="Duration" style={{ fontWeight: '600' }}>{durationStr}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Pending Requests Table */}
      <div className="admin-card">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '24px' }}>
          <AlertCircle color="#ea580c" />
          <h2 style={{ margin: 0 }}>Action Required: Missing Check-Outs & Overrides</h2>
        </div>
        
        {pendingRequests.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px', color: 'var(--admin-text-muted)' }}>
            <AlertCircle size={48} color="#cbd5e1" style={{ marginBottom: '16px', opacity: 0.5 }} />
            <p style={{ margin: 0 }}>No pending actions required.</p>
          </div>
        ) : (
          <div className="admin-table-container">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Request Reason</th>
                  <th>Submitted At</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {pendingRequests.map(req => (
                  <tr key={req.id}>
                    <td data-label="Employee">
                      <div style={{ fontWeight: '600' }}>{req.profiles?.full_name || 'Unknown'}</div>
                      <div style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>{req.profiles?.employee_code || '-'}</div>
                    </td>
                    <td data-label="Request Reason" style={{ maxWidth: '400px', whiteSpace: 'normal', lineHeight: '1.4' }}>
                      {req.reason}
                    </td>
                    <td data-label="Submitted At">
                      {format(new Date(req.created_at), 'MMM dd, yyyy hh:mm a')}
                    </td>
                    <td data-label="Actions" style={{ textAlign: 'right' }}>
                      {req.work_session_id ? (
                        <button 
                          onClick={() => setSelectedCorrection(req)}
                          className="admin-btn primary"
                          style={{ padding: '6px 12px', fontSize: '12px', backgroundColor: '#3b82f6' }}
                        >
                          Review & Fix Exit Time
                        </button>
                      ) : (
                        <button 
                          onClick={() => handleResolveRequest(req.id)}
                          className="admin-btn primary"
                          style={{ padding: '6px 12px', fontSize: '12px', backgroundColor: '#10b981' }}
                        >
                          Mark Resolved
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Set Exit Time Modal */}
      {selectedCorrection && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: '#fff', borderRadius: '24px', width: '100%', maxWidth: '400px', padding: '24px'
          }}>
            <h3 style={{ marginTop: 0, color: 'var(--admin-text-dark)' }}>Set True Exit Time</h3>
            <p style={{ color: 'var(--admin-text-muted)', fontSize: '14px', marginBottom: '20px' }}>
              Please enter the exact date and time {selectedCorrection.profiles?.full_name} left work. This will automatically update their session and recalculate total hours.
            </p>
            <input
              type="datetime-local"
              style={{ width: '100%', padding: '12px', border: '1px solid var(--admin-border)', borderRadius: '12px', marginBottom: '24px', fontFamily: 'inherit' }}
              value={newExitTime}
              onChange={(e) => setNewExitTime(e.target.value)}
            />
            <div style={{ display: 'flex', gap: '12px' }}>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: '1px solid var(--admin-border)', backgroundColor: '#fff', fontWeight: 'bold' }}
                onClick={() => { setSelectedCorrection(null); setNewExitTime(''); }}
                disabled={resolving}
              >
                Cancel
              </button>
              <button 
                style={{ flex: 1, padding: '12px', borderRadius: '12px', border: 'none', backgroundColor: '#3b82f6', color: 'white', fontWeight: 'bold', display: 'flex', justifyContent: 'center' }}
                onClick={handleFixExitTime}
                disabled={resolving || !newExitTime}
              >
                {resolving ? <div className="skeuo-loader sm"></div> : 'Save & Resolve'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
