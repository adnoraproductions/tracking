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
        <img src="/logo.svg" alt="Adnora Logo" style={{ height: '32px', transform: 'scale(3.5)', transformOrigin: 'left center' }} />
        
        {role === 'admin' && (
          <button 
            onClick={() => navigate('/admin')}
            style={{ 
              display: 'flex', alignItems: 'center', gap: '6px', 
              backgroundColor: '#e2e6eb', border: '1px solid rgba(0,0,0,0.1)', padding: '6px 12px', 
              borderRadius: '999px', fontSize: '12px', fontWeight: 'bold', color: '#4b5563',
              boxShadow: 'inset 2px 2px 4px rgba(255,255,255,0.8), 2px 2px 5px rgba(0,0,0,0.1)',
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
