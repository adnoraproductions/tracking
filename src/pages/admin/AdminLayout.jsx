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
      {/* Force override for mobile layout in case of CSS cache */}
      <style>{`
        @media (max-width: 768px) {
          .admin-sidebar { position: relative !important; top: auto !important; height: auto !important; z-index: 100 !important; }
          .admin-main { margin-top: 0 !important; padding-bottom: 100px !important; }
          .admin-page-header { flex-direction: column !important; align-items: flex-start !important; gap: 16px !important; }
          
          /* Floating Pill Nav Bar - 100% Opaque */
          .admin-nav {
            position: fixed !important;
            bottom: 24px !important;
            left: 24px !important;
            right: 24px !important;
            border-radius: 32px !important;
            max-width: 480px !important;
            margin: 0 auto !important;
            padding: 8px 12px !important;
            background-color: #ffffff !important;
            border: 1px solid #e5e7eb !important;
            box-shadow: 0 8px 32px rgba(0,0,0,0.12) !important;
            z-index: 100 !important;
            backdrop-filter: none !important;
            -webkit-backdrop-filter: none !important;
          }
          
          .admin-nav-item.active {
            background-color: #f3f4f6 !important;
            box-shadow: none !important;
            border: 1px solid transparent !important;
          }
        }
      `}</style>

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
        
        {/* Foolproof spacer for mobile nav bar to ensure scrollability */}
        <div className="mobile-nav-spacer" style={{ height: '120px', width: '100%', display: 'block' }}></div>
      </main>
    </div>
  );
}
