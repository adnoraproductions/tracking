import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase/client';
import { createClient } from '@supabase/supabase-js';
import { Loader2, Edit2, X, Plus, UserPlus, Trash2, Power } from 'lucide-react';

// Create a secondary client specifically for signing up users so it doesn't overwrite the admin's session
const adminAuthClient = createClient(
  import.meta.env.VITE_SUPABASE_URL || 'PLACEHOLDER_URL',
  import.meta.env.VITE_SUPABASE_ANON_KEY || 'PLACEHOLDER_ANON_KEY',
  { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }
);

export default function EmployeeManager() {
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({ full_name: '', employee_code: '', role: 'employee', designation: '', joined_date: '', new_password: '' });

  // Add Employee Modal State
  const [showAddModal, setShowAddModal] = useState(false);
  const [addLoading, setAddLoading] = useState(false);
  const [addForm, setAddForm] = useState({
    email: '',
    password: '',
    full_name: '',
    employee_code: '',
    designation: ''
  });

  useEffect(() => {
    fetchEmployees();
  }, []);

  const fetchEmployees = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      setEmployees(data);
    } catch (err) {
      console.error(err);
      setError('Failed to load employees');
    } finally {
      setLoading(false);
    }
  };

  const handleEditClick = (emp) => {
    setEditingId(emp.id);
    setEditForm({ 
      full_name: emp.full_name || '', 
      employee_code: emp.employee_code || '', 
      role: emp.role || 'employee',
      designation: emp.designation || '',
      joined_date: emp.joined_date || emp.created_at.split('T')[0],
      new_password: ''
    });
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: editForm.full_name,
          employee_code: editForm.employee_code || null,
          role: editForm.role,
          designation: editForm.designation || null,
          joined_date: editForm.joined_date || null
        })
        .eq('id', editingId);
        
      if (error) throw error;
      
      // If a new password was provided, attempt to update it via RPC
      if (editForm.new_password && editForm.new_password.length >= 6) {
        const { error: rpcError } = await supabase.rpc('admin_update_user_password', {
          user_id: editingId,
          new_password: editForm.new_password
        });
        
        if (rpcError) {
          console.error("Password update failed", rpcError);
          alert('Profile updated, but password change failed! Make sure you have run the required SQL function in your Supabase dashboard.');
        } else {
          alert('Profile and password updated successfully!');
        }
      }
      
      setEditingId(null);
      await fetchEmployees();
    } catch (err) {
      console.error(err);
      alert('Failed to update employee: ' + err.message);
    }
  };

  const handleToggleStatus = async (emp) => {
    try {
      const newStatus = emp.status === 'inactive' ? 'active' : 'inactive';
      const { error } = await supabase
        .from('profiles')
        .update({ status: newStatus })
        .eq('id', emp.id);
        
      if (error) throw error;
      await fetchEmployees();
    } catch (err) {
      console.error(err);
      alert('Failed to update status: ' + err.message);
    }
  };

  const handleDeleteEmployee = async (emp) => {
    if (!window.confirm(`Are you sure you want to completely delete ${emp.full_name}? This action cannot be undone.`)) {
      return;
    }
    try {
      const { error } = await supabase
        .from('profiles')
        .delete()
        .eq('id', emp.id);
        
      if (error) throw error;
      await fetchEmployees();
    } catch (err) {
      console.error(err);
      alert('Failed to delete employee: ' + err.message);
    }
  };

  const handleAddEmployee = async (e) => {
    e.preventDefault();
    if (!addForm.email || !addForm.password || !addForm.full_name) {
      alert("Email, Password, and Full Name are required.");
      return;
    }

    try {
      setAddLoading(true);

      // 1. Create the user in Supabase Auth
      const { data, error: signUpError } = await adminAuthClient.auth.signUp({
        email: addForm.email,
        password: addForm.password,
        options: {
          data: {
            full_name: addForm.full_name,
            role: 'employee'
          }
        }
      });

      if (signUpError) throw signUpError;
      if (!data.user) throw new Error("Failed to create user record");

      // 2. The database trigger handle_new_user() will automatically create the profile.
      // We just need to update it with the extra metadata (code, designation).
      
      // Wait a tiny bit for the trigger to finish
      await new Promise(r => setTimeout(r, 500));

      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          employee_code: addForm.employee_code || null,
          designation: addForm.designation || null
        })
        .eq('id', data.user.id);

      if (profileError) console.error("Could not update profile metadata", profileError);

      setShowAddModal(false);
      setAddForm({ email: '', password: '', full_name: '', employee_code: '', designation: '' });
      await fetchEmployees();

    } catch (err) {
      console.error(err);
      alert('Failed to add employee: ' + err.message);
    } finally {
      setAddLoading(false);
    }
  };

  if (loading) {
    return <div style={{display: 'flex', justifyContent: 'center', padding: '40px'}}><Loader2 className="spinner" size={32} /></div>;
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Employee Directory</h1>
        <p>Manage your workforce, update roles, and view employee profiles.</p>
      </div>

      {error && (
        <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
          {error}
        </div>
      )}

      <div className="admin-card">
        <div className="admin-table-header">
          <div className="admin-table-header-title">
            <h2>All Employees</h2>
            <span className="admin-badge gray">{employees.length} total</span>
          </div>
          <button className="admin-btn primary add-btn" onClick={() => setShowAddModal(true)}>
            <Plus size={18} />
            <span>Add Employee</span>
          </button>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Emp Code</th>
                <th>Designation</th>
                <th>Status</th>
                <th>Role</th>
                <th>Joined</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {employees.map(emp => (
                <tr key={emp.id}>
                  {editingId === emp.id ? (
                    <>
                      <td data-label="Name">
                        <input 
                          className="admin-input"
                          value={editForm.full_name} 
                          onChange={e => setEditForm({...editForm, full_name: e.target.value})} 
                          placeholder="Full Name"
                          style={{ width: '100%', padding: '8px', border: '1px solid var(--admin-border)', borderRadius: '8px' }}
                          onKeyDown={e => e.key === 'Enter' && handleSaveEdit(e)}
                          required
                        />
                      </td>
                      <td data-label="Emp Code">
                        <input 
                          className="admin-input"
                          value={editForm.employee_code} 
                          onChange={e => setEditForm({...editForm, employee_code: e.target.value})} 
                          placeholder="Emp Code"
                          style={{ width: '100%', padding: '8px', border: '1px solid var(--admin-border)', borderRadius: '8px' }}
                          onKeyDown={e => e.key === 'Enter' && handleSaveEdit(e)}
                        />
                      </td>
                      <td data-label="Designation">
                        <input 
                          className="admin-input"
                          value={editForm.designation} 
                          onChange={e => setEditForm({...editForm, designation: e.target.value})} 
                          placeholder="Designation"
                          style={{ width: '100%', padding: '8px', border: '1px solid var(--admin-border)', borderRadius: '8px' }}
                          onKeyDown={e => e.key === 'Enter' && handleSaveEdit(e)}
                        />
                      </td>
                      <td data-label="Password">
                        <input 
                          className="admin-input"
                          type="password"
                          value={editForm.new_password} 
                          onChange={e => setEditForm({...editForm, new_password: e.target.value})} 
                          placeholder="New Password"
                          style={{ width: '100%', padding: '8px', border: '1px solid var(--admin-border)', borderRadius: '8px' }}
                          onKeyDown={e => e.key === 'Enter' && handleSaveEdit(e)}
                        />
                      </td>
                      <td data-label="Role">
                        <div style={{ display: 'flex', backgroundColor: '#f3f4f6', borderRadius: '8px', padding: '4px' }}>
                          <button 
                            onClick={() => setEditForm({...editForm, role: 'employee'})}
                            style={{ flex: 1, padding: '6px', borderRadius: '6px', border: 'none', backgroundColor: editForm.role === 'employee' ? 'white' : 'transparent', color: editForm.role === 'employee' ? 'var(--admin-text-dark)' : 'var(--admin-text-muted)', fontWeight: editForm.role === 'employee' ? '600' : '500', boxShadow: editForm.role === 'employee' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none', cursor: 'pointer', transition: 'all 0.2s', fontSize: '13px' }}
                          >
                            Employee
                          </button>
                          <button 
                            onClick={() => setEditForm({...editForm, role: 'admin'})}
                            style={{ flex: 1, padding: '6px', borderRadius: '6px', border: 'none', backgroundColor: editForm.role === 'admin' ? 'white' : 'transparent', color: editForm.role === 'admin' ? 'var(--admin-text-dark)' : 'var(--admin-text-muted)', fontWeight: editForm.role === 'admin' ? '600' : '500', boxShadow: editForm.role === 'admin' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none', cursor: 'pointer', transition: 'all 0.2s', fontSize: '13px' }}
                          >
                            Admin
                          </button>
                        </div>
                      </td>
                      <td data-label="Joined">
                        <input 
                          className="admin-input"
                          type="date"
                          value={editForm.joined_date} 
                          onChange={e => setEditForm({...editForm, joined_date: e.target.value})} 
                          style={{ width: '100%', padding: '8px', border: '1px solid var(--admin-border)', borderRadius: '8px' }}
                          onKeyDown={e => e.key === 'Enter' && handleSaveEdit(e)}
                        />
                      </td>
                      <td data-label="Actions" style={{ textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                          <button type="button" onClick={handleSaveEdit} className="admin-btn primary" style={{ padding: '8px 16px' }}>Save</button>
                          <button type="button" onClick={() => setEditingId(null)} className="admin-btn secondary" style={{ padding: '8px', border: 'none' }}>
                            <X size={16} />
                          </button>
                        </div>
                      </td>
                    </>
                  ) : (
                    <>
                      <td data-label="Name">
                        <div style={{ fontWeight: '600' }}>{emp.full_name || 'Unknown'}</div>
                        <div style={{ fontSize: '12px', color: 'var(--admin-text-muted)' }}>{emp.id.split('-')[0]}</div>
                      </td>
                      <td data-label="Emp Code">{emp.employee_code || '-'}</td>
                      <td data-label="Designation">{emp.designation || '-'}</td>
                      <td data-label="Status">
                        <span className={`admin-badge ${emp.status === 'inactive' ? 'gray' : 'green'}`}>
                          {emp.status || 'active'}
                        </span>
                      </td>
                      <td data-label="Role">
                        <span className={`admin-badge ${emp.role === 'admin' ? 'red' : 'gray'}`}>
                          {emp.role || 'employee'}
                        </span>
                      </td>
                      <td data-label="Joined">{emp.joined_date ? new Date(emp.joined_date).toLocaleDateString() : new Date(emp.created_at).toLocaleDateString()}</td>
                      <td data-label="Actions" style={{ textAlign: 'right' }}>
                        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '4px' }}>
                          <button 
                            onClick={() => handleToggleStatus(emp)}
                            className="admin-btn secondary"
                            title={emp.status === 'inactive' ? "Activate Account" : "Deactivate Account"}
                            style={{ padding: '6px', border: 'none', color: emp.status === 'inactive' ? '#16a34a' : '#ea580c' }}
                          >
                            <Power size={16} />
                          </button>
                          <button 
                            onClick={() => handleEditClick(emp)}
                            className="admin-btn secondary"
                            title="Edit Employee"
                            style={{ padding: '6px', border: 'none', color: 'var(--admin-primary)' }}
                          >
                            <Edit2 size={16} />
                          </button>
                          <button 
                            onClick={() => handleDeleteEmployee(emp)}
                            className="admin-btn secondary"
                            title="Delete Employee"
                            style={{ padding: '6px', border: 'none', color: '#ef4444' }}
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Employee Modal */}
      {showAddModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '20px'
        }}>
          <div style={{
            backgroundColor: 'var(--admin-card-bg)', borderRadius: '24px',
            width: '100%', maxWidth: '500px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)'
          }}>
            <div style={{ padding: '24px', borderBottom: '1px solid var(--admin-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ margin: 0, fontSize: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <UserPlus size={20} color="var(--admin-primary)" />
                Add New Employee
              </h2>
              <button onClick={() => setShowAddModal(false)} style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
                <X size={24} color="var(--admin-text-muted)" />
              </button>
            </div>
            
            <form onSubmit={handleAddEmployee} style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Email Address *
                  <input type="email" required value={addForm.email} onChange={(e) => setAddForm({...addForm, email: e.target.value})} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)' }} />
                </label>

                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Password *
                  <input type="password" required minLength={6} value={addForm.password} onChange={(e) => setAddForm({...addForm, password: e.target.value})} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)' }} />
                </label>
              </div>

              <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                Full Name *
                <input type="text" required value={addForm.full_name} onChange={(e) => setAddForm({...addForm, full_name: e.target.value})} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)' }} />
              </label>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Employee Code
                  <input type="text" placeholder="e.g. AD001" value={addForm.employee_code} onChange={(e) => setAddForm({...addForm, employee_code: e.target.value})} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)' }} />
                </label>

                <label style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '14px', fontWeight: '500' }}>
                  Designation
                  <input type="text" placeholder="e.g. Developer" value={addForm.designation} onChange={(e) => setAddForm({...addForm, designation: e.target.value})} style={{ width: '100%', boxSizing: 'border-box', padding: '10px', borderRadius: '8px', border: '1px solid var(--admin-border)' }} />
                </label>
              </div>

              <div style={{ marginTop: '16px', display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
                <button type="button" className="admin-btn secondary" onClick={() => setShowAddModal(false)}>Cancel</button>
                <button type="submit" className="admin-btn primary" disabled={addLoading}>
                  {addLoading ? <Loader2 className="spinner" size={16} /> : 'Create Employee'}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}
    </div>
  );
}
