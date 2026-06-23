import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useNavigate, Navigate } from 'react-router-dom';
import { Fingerprint, Loader2 } from 'lucide-react';
import '../employee/Employee.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  const { signIn, user, role, loading: authLoading } = useAuth();
  const navigate = useNavigate();

  // If already logged in, redirect based on role
  if (!authLoading && user) {
    if (role === 'admin') return <Navigate to="/admin" replace />;
    return <Navigate to="/employee" replace />;
  }

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      await signIn(email, password);
      // AuthContext will automatically update and redirect will happen
    } catch (err) {
      console.error('Login error:', err);
      setError(err.message || 'Failed to sign in. Please check your credentials.');
      setLoading(false);
    }
  };

  return (
    <div className="login-container-white">
      <div className="login-card-white">
        <div className="login-icon-box">
          <Fingerprint size={32} />
        </div>
        
        <h1 className="login-title-dark">Office Time Tracker</h1>
        <p className="login-subtitle-dark">Sign in with your Email Address.</p>

        {error && (
          <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', padding: '12px', borderRadius: '8px', marginBottom: '24px', fontSize: '14px' }}>
            {error}
          </div>
        )}

        <form onSubmit={handleLogin}>
          <div style={{ backgroundColor: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: '16px', padding: '16px', marginBottom: '24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px', color: '#6b7280', fontSize: '12px', textTransform: 'uppercase', fontWeight: '600' }}>
              <span style={{width: '8px', height: '8px', backgroundColor: '#059669', borderRadius: '50%'}}></span>
              Employee Sign In
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '12px', color: '#9ca3af', marginBottom: '4px' }}>Email Address</label>
              <input 
                type="email" 
                required 
                value={email}
                onChange={e => setEmail(e.target.value)}
                style={{ width: '100%', border: 'none', backgroundColor: 'transparent', fontSize: '16px', color: '#111827', outline: 'none' }}
                placeholder="employee@adnora.com"
              />
            </div>

            <div style={{ borderTop: '1px solid #e5e7eb', margin: '0 -16px 16px -16px' }}></div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', color: '#9ca3af', marginBottom: '4px' }}>Password</label>
              <input 
                type="password" 
                required 
                value={password}
                onChange={e => setPassword(e.target.value)}
                style={{ width: '100%', border: 'none', backgroundColor: 'transparent', fontSize: '16px', color: '#111827', outline: 'none' }}
                placeholder="••••••••"
              />
            </div>
          </div>

          <button 
            type="submit" 
            disabled={loading}
            className="emp-btn-large primary"
          >
            {loading ? <Loader2 className="spinner" size={20} /> : 'Continue'}
          </button>
        </form>

        <div style={{ marginTop: '24px', display: 'flex', alignItems: 'center', gap: '8px', padding: '16px', backgroundColor: '#f0fdf4', border: '1px solid #d1fae5', borderRadius: '16px', color: '#059669', fontSize: '13px' }}>
          <div style={{ width: '20px', height: '20px', borderRadius: '50%', backgroundColor: '#059669', color: 'white', display: 'flex', justifyContent: 'center', alignItems: 'center', fontSize: '10px' }}>✓</div>
          Attendance syncs automatically after sign-in.
        </div>
      </div>
    </div>
  );
}
