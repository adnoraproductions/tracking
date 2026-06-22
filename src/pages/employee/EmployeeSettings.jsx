import React, { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { LogOut } from 'lucide-react';

export default function EmployeeSettings() {
  const { profile, signOut } = useAuth();
  const [status, setStatus] = useState('Checked Out');

  // Format date correctly if available
  const joinedDate = profile?.joined_date 
    ? new Date(profile.joined_date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
    : profile?.created_at 
      ? new Date(profile.created_at).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
      : 'Unknown';

  const getInitials = (name) => {
    if (!name) return 'U';
    return name.charAt(0).toUpperCase();
  };

  useEffect(() => {
    const fetchStatus = async () => {
      if (!profile) return;
      try {
        const { data, error } = await supabase
          .from('work_sessions')
          .select('status')
          .eq('employee_id', profile.id)
          .in('status', ['working', 'on_break'])
          .maybeSingle();

        if (error) throw error;
        
        if (data && data.status === 'working') setStatus('Working');
        else if (data && data.status === 'on_break') setStatus('On Break');
        else setStatus('Checked Out');
      } catch (err) {
        console.error("Failed to fetch status:", err);
      }
    };
    fetchStatus();
  }, [profile]);

  const getStatusStyles = () => {
    if (status === 'Working') return { backgroundColor: '#d1fae5', color: '#059669' };
    if (status === 'On Break') return { backgroundColor: '#fef3c7', color: '#d97706' };
    return { backgroundColor: '#f3f4f6', color: '#6b7280' };
  };

  return (
    <>
      <div className="emp-settings-header">
        <h1>Settings</h1>
        <p>Account & preferences</p>
      </div>

      {/* Profile Card */}
      <div className="emp-settings-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div style={{ width: '56px', height: '56px', borderRadius: '50%', backgroundColor: 'var(--emp-primary)', color: 'white', display: 'flex', justifyContent: 'center', alignItems: 'center', fontSize: '24px', fontWeight: 'bold' }}>
              {getInitials(profile?.full_name)}
            </div>
            <div>
              <h2 style={{ margin: '0 0 4px 0', fontSize: '18px', color: 'var(--emp-text-dark)' }}>{profile?.full_name || 'Employee'}</h2>
              <p style={{ margin: 0, color: 'var(--emp-text-muted)', fontSize: '14px' }}>{profile?.designation || 'Employee'}</p>
            </div>
          </div>
          <div className="emp-status-badge" style={getStatusStyles()}>
            {status}
          </div>
        </div>

        <div className="emp-settings-row">
          <span className="emp-settings-label">Employee ID</span>
          <span className="emp-settings-value">{profile?.employee_code || '-'}</span>
        </div>
        <div className="emp-settings-row">
          <span className="emp-settings-label">Designation</span>
          <span className="emp-settings-value">{profile?.designation || 'Not set'}</span>
        </div>
        <div className="emp-settings-row">
          <span className="emp-settings-label">Joined</span>
          <span className="emp-settings-value">{joinedDate}</span>
        </div>
      </div>

      {/* Sign Out Card */}
      <div className="emp-settings-card" style={{ backgroundColor: '#fef2f2', border: '1px solid #fecaca', cursor: 'pointer' }} onClick={signOut}>
        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
          <div style={{ color: 'var(--emp-danger)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <LogOut size={24} />
          </div>
          <div>
            <h3 style={{ margin: '0 0 4px 0', fontSize: '16px', color: 'var(--emp-danger)' }}>Sign Out</h3>
            <p style={{ margin: 0, color: 'var(--emp-text-muted)', fontSize: '13px' }}>Switch to a different employee</p>
          </div>
        </div>
      </div>
    </>
  );
}
