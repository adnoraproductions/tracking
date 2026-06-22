import React from 'react';
import { Outlet, NavLink } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { LayoutDashboard, Users, MapPin, LogOut, CalendarClock } from 'lucide-react';
import PageTransition from '../../components/PageTransition';
import './Admin.css';

export default function AdminLayout() {
  const { signOut } = useAuth();

  return (
    <div className="admin-layout">
      {/* Sidebar Navigation */}
      <aside className="admin-sidebar">
        <div className="admin-sidebar-header">
          <h2><span style={{color: 'var(--admin-primary)'}}>•</span> Adnora</h2>
          <button onClick={signOut} className="admin-mobile-logout" title="Sign Out">
            <LogOut size={20} />
          </button>
        </div>
        
        <nav className="admin-nav">
          <NavLink 
            to="/admin" 
            end
            className={({ isActive }) => `admin-nav-item ${isActive ? 'active' : ''}`}
          >
            <LayoutDashboard size={20} />
            Dashboard
          </NavLink>
          
          <NavLink 
            to="/admin/attendance" 
            className={({ isActive }) => `admin-nav-item ${isActive ? 'active' : ''}`}
          >
            <CalendarClock size={20} />
            Attendance Logs
          </NavLink>

          <NavLink 
            to="/admin/employees" 
            className={({ isActive }) => `admin-nav-item ${isActive ? 'active' : ''}`}
          >
            <Users size={20} />
            Employees
          </NavLink>

          <NavLink 
            to="/admin/office" 
            className={({ isActive }) => `admin-nav-item ${isActive ? 'active' : ''}`}
          >
            <MapPin size={20} />
            Office Settings
          </NavLink>
        </nav>

        <div className="admin-sidebar-footer">
          <button onClick={signOut} className="admin-logout-btn">
            <LogOut size={20} />
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="admin-main">
        <PageTransition>
          <Outlet />
        </PageTransition>
      </main>
    </div>
  );
}
