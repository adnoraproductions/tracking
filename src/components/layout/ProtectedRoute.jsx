import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';

export function ProtectedRoute({ allowedRoles = [] }) {
  const { user, role, loading } = useAuth();

  if (loading) {
    return (
      <div className="app-shell">
        <div className="mobile-container" style={{ display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          <p style={{ color: 'var(--text-secondary)' }}>Loading...</p>
        </div>
      </div>
    );
  }

  // Not authenticated
  if (!user) {
    return <Navigate to="/login" replace />;
  }

  // Authenticated but wrong role
  if (allowedRoles.length > 0 && !allowedRoles.includes(role)) {
    // Redirect to their default dashboard
    if (role === 'admin') return <Navigate to="/admin" replace />;
    return <Navigate to="/employee" replace />;
  }

  return <Outlet />;
}
