import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase/client';
import { Loader2, Save } from 'lucide-react';

export default function OfficeSettings() {
  const [office, setOffice] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    fetchOffice();
  }, []);

  const fetchOffice = async () => {
    try {
      const { data, error } = await supabase
        .from('office_settings')
        .select('*')
        .eq('is_active', true)
        .single();
      
      if (error && error.code !== 'PGRST116') throw error;
      setOffice(data || { name: 'Main Office', latitude: '', longitude: '', radius: 100, work_target_hours: 8.0, is_active: true });
    } catch (err) {
      console.error(err);
      setError('Failed to load office settings');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(false);

    try {
      if (office.id) {
        const { error } = await supabase
          .from('office_settings')
          .update({
            name: office.name,
            latitude: parseFloat(office.latitude),
            longitude: parseFloat(office.longitude),
            radius: parseInt(office.radius, 10),
            work_target_hours: parseFloat(office.work_target_hours || 8.0)
          })
          .eq('id', office.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('office_settings')
          .insert([{
            name: office.name,
            latitude: parseFloat(office.latitude),
            longitude: parseFloat(office.longitude),
            radius: parseInt(office.radius, 10),
            work_target_hours: parseFloat(office.work_target_hours || 8.0),
            is_active: true
          }]);
        if (error) throw error;
        await fetchOffice(); // Get the generated ID
      }
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      console.error(err);
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><Loader2 className="spinner" size={32} /></div>;
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Office Settings</h1>
        <p>Configure the primary geofence location and global employee targets.</p>
      </div>

      <div className="admin-card" style={{ maxWidth: '600px' }}>
        <h2>Company Policies</h2>
        
        {error && (
          <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
            {error}
          </div>
        )}
        
        {success && (
          <div style={{ backgroundColor: '#f0fdf4', color: '#059669', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
            Settings saved successfully!
          </div>
        )}

        <form onSubmit={handleSave}>
          <div className="admin-form-group">
            <label>Office Name</label>
            <input 
              type="text" 
              required
              value={office.name} 
              onChange={e => setOffice({...office, name: e.target.value})} 
            />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div className="admin-form-group">
              <label>Latitude (Decimal Degrees)</label>
              <input 
                type="number" 
                step="any"
                required
                value={office.latitude} 
                onChange={e => setOffice({...office, latitude: e.target.value})} 
                placeholder="e.g. 10.0158"
              />
            </div>
            <div className="admin-form-group">
              <label>Longitude (Decimal Degrees)</label>
              <input 
                type="number" 
                step="any"
                required
                value={office.longitude} 
                onChange={e => setOffice({...office, longitude: e.target.value})} 
                placeholder="e.g. 76.2999"
              />
            </div>
          </div>

          <div className="admin-form-group">
            <label>Allowed Radius (Meters)</label>
            <input 
              type="number" 
              required
              min="10"
              value={office.radius} 
              onChange={e => setOffice({...office, radius: e.target.value})} 
            />
            <p style={{ fontSize: '12px', color: 'var(--admin-text-muted)', marginTop: '8px' }}>
              Employees must be within this many meters of the exact GPS coordinate to check in.
            </p>
          </div>
          
          <div style={{ borderTop: '1px solid var(--admin-border)', margin: '24px 0' }}></div>

          <div className="admin-form-group">
            <label>Global Work Target (Hours)</label>
            <input 
              type="number" 
              step="0.5"
              required
              min="1"
              max="24"
              value={office.work_target_hours || ''} 
              onChange={e => setOffice({...office, work_target_hours: e.target.value})} 
            />
            <p style={{ fontSize: '12px', color: 'var(--admin-text-muted)', marginTop: '8px' }}>
              The default daily work hours expected for all employees.
            </p>
          </div>

          <button type="submit" disabled={saving} className="admin-btn primary">
            {saving ? <Loader2 className="spinner" size={16} /> : <Save size={16} />}
            Save Settings
          </button>
        </form>
      </div>
    </div>
  );
}
