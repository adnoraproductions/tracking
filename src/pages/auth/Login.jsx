import React, { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { Mail, Lock, Eye, EyeOff, ArrowRight, Clock3, Trophy, CalendarDays, AlertCircle } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './Login.css';

function friendlyLoginError(err) {
  const msg = err?.message || '';
  if (/invalid login credentials/i.test(msg)) return 'That email or password is incorrect. Please try again.';
  if (/email not confirmed/i.test(msg)) return 'This account has not been activated yet. Please contact your admin.';
  if (/failed to fetch|network/i.test(msg)) return 'No internet connection. Check your network and try again.';
  return msg || 'Could not sign in. Please try again.';
}

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const { signIn, user, role, loading: authLoading } = useAuth();

  // Already signed in → go to the right home screen
  if (!authLoading && user) {
    return <Navigate to={role === 'admin' ? '/admin' : '/employee'} replace />;
  }

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await signIn(email.trim(), password);
      // AuthContext updates and the redirect above takes over
    } catch (err) {
      console.error('Login error:', err);
      setError(friendlyLoginError(err));
      setLoading(false);
    }
  };

  return (
    <div className="login">
      {/* Brand panel */}
      <aside className="login-brand">
        <span className="brand-mark login-logo" role="img" aria-label="Adnora Productions" />

        <div className="login-tagline">
          <p>
            Ideas That <span>Connect.</span>
          </p>
          <p>
            Designs That <span>Inspire.</span>
          </p>
          <p>
            Results That <span>Matter.</span>
          </p>
        </div>

        <ul className="login-features">
          <li>
            <span><Clock3 size={16} /></span>
            Check in from office, home or the field
          </li>
          <li>
            <span><Trophy size={16} /></span>
            Log daily work and track your incentives
          </li>
          <li>
            <span><CalendarDays size={16} /></span>
            Apply for leave in a few taps
          </li>
        </ul>

        <div className="login-copy">© {new Date().getFullYear()} Adnora Productions</div>
      </aside>

      {/* Form */}
      <main className="login-main">
        <div className="login-card">
          <div className="login-eyebrow">Adnora Teamwork</div>
          <h1>Welcome back</h1>
          <p className="login-sub">Sign in with your work email to continue.</p>

          {error && (
            <div className="login-error" role="alert">
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="login-form" noValidate={false}>
            <label className="login-field">
              <span className="login-label">Email</span>
              <span className="login-input">
                <Mail size={18} />
                <input
                  type="email"
                  required
                  autoComplete="email"
                  inputMode="email"
                  autoCapitalize="none"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@adnoraproductions.in"
                />
              </span>
            </label>

            <label className="login-field">
              <span className="login-label">Password</span>
              <span className="login-input">
                <Lock size={18} />
                <input
                  type={showPassword ? 'text' : 'password'}
                  required
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your password"
                />
                <button
                  type="button"
                  className="login-eye"
                  onClick={() => setShowPassword((v) => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </span>
            </label>

            <button type="submit" className="login-submit" disabled={loading || !email || !password}>
              {loading ? (
                <span className="spinner sm" />
              ) : (
                <>
                  Sign in <ArrowRight size={18} />
                </>
              )}
            </button>
          </form>

          <p className="login-help">
            Forgot your password? Ask your admin to reset it from the Employees page.
          </p>
        </div>
      </main>
    </div>
  );
}
