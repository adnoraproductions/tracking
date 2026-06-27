import React from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { LayoutDashboard, Settings, ListTodo, Shield } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import PageTransition from '../../components/PageTransition';
import './Employee.css';

export default function EmployeeLayout() {
  const { role } = useAuth();
  const navigate = useNavigate();
  return (
    <div className="emp-layout">
      {/* Top Header */}
      <header className="emp-top-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2 style={{ margin: 0 }}><span style={{color: 'var(--emp-primary)'}}>•</span> Adnora</h2>
        
        {role === 'admin' && (
          <button 
            onClick={() => navigate('/admin')}
            style={{ 
              display: 'flex', alignItems: 'center', gap: '6px', 
              backgroundColor: '#f3f4f6', border: 'none', padding: '6px 12px', 
              borderRadius: '999px', fontSize: '12px', fontWeight: 'bold', color: '#4b5563',
              cursor: 'pointer'
            }}
          >
            <Shield size={14} />
            Admin Portal
          </button>
        )}
      </header>

      {/* Main Content Area (Rendered child routes) */}
      <div className="emp-content">
        <PageTransition className="emp-content-inner">
          <Outlet />
        </PageTransition>
      </div>

      {/* Bottom Navigation Bar */}
      <nav className="emp-bottom-nav">
        <NavLink 
          to="/employee" 
          end 
          className={({ isActive }) => `emp-nav-item ${isActive ? 'active' : ''}`}
        >
          <LayoutDashboard size={24} />
          <span>Dashboard</span>
        </NavLink>

        <NavLink 
          to="/employee/attendance" 
          className={({ isActive }) => `emp-nav-item ${isActive ? 'active' : ''}`}
        >
          <ListTodo size={24} />
          <span>Logs</span>
        </NavLink>
        
        <NavLink 
          to="/employee/settings" 
          className={({ isActive }) => `emp-nav-item ${isActive ? 'active' : ''}`}
        >
          <Settings size={24} />
          <span>Settings</span>
        </NavLink>
      </nav>
    </div>
  );
}
