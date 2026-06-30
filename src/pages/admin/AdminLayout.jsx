import React from 'react';
import { Outlet, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { LayoutDashboard, Users, MapPin, LogOut, CalendarClock, UserCheck } from 'lucide-react';
import PageTransition from '../../components/PageTransition';
import './Admin.css';

export default function AdminLayout() {
  const { signOut } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="admin-layout">
      {/* Force override for mobile layout in case of CSS cache */}
      <style>{`
        .admin-header-portal-btn {
          display: flex;
          align-items: center;
          gap: 6px;
          background-color: #e2e6eb;
          border: 1px solid rgba(0,0,0,0.1);
          padding: 6px 12px;
          border-radius: 999px;
          font-size: 12px;
          font-weight: bold;
          color: #4b5563;
          box-shadow: inset 2px 2px 4px rgba(255,255,255,0.8), 2px 2px 5px rgba(0,0,0,0.1);
          cursor: pointer;
        }

        @media (max-width: 768px) {
          .admin-sidebar { position: relative !important; top: auto !important; height: auto !important; z-index: 100 !important; border-right: none !important; box-shadow: none !important; }
          .admin-main { margin-top: 60px !important; margin-left: 0 !important; padding: 20px !important; padding-bottom: 100px !important; }
          .admin-page-header { flex-direction: column !important; align-items: flex-start !important; gap: 16px !important; margin-bottom: 24px !important; }

          /* Consistent Mobile Top Header */
          .admin-sidebar-header {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            right: 0 !important;
            width: 100% !important;
            z-index: 100 !important;
            padding: 16px 20px !important;
            background-color: var(--skeuo-surface) !important;
            box-shadow: 0 4px 12px var(--skeuo-shadow-light) !important;
            border-bottom: 2px solid var(--skeuo-highlight) !important;
            box-sizing: border-box !important;
            display: flex !important;
            justify-content: space-between !important;
            align-items: center !important;
          }

          .admin-mobile-logout {
            display: flex !important;
            align-items: center !important;
            gap: 6px !important;
            background-color: #fef2f2 !important;
            border: 1px solid #fecaca !important;
            padding: 6px 12px !important;
            border-radius: 999px !important;
            font-size: 12px !important;
            font-weight: bold !important;
            color: var(--emp-danger) !important;
            box-shadow: inset 2px 2px 4px rgba(255,255,255,0.8), 2px 2px 5px rgba(239, 68, 68, 0.2) !important;
            cursor: pointer !important;
          }
          
          /* Hide desktop footer on mobile */
          .admin-sidebar-footer {
            display: none !important;
          }
          
          /* Floating Pill Nav Bar - Skeuomorphic */
          .admin-nav {
            position: fixed !important;
            bottom: 24px !important;
            left: 24px !important;
            right: 24px !important;
            border-radius: 32px !important;
            max-width: 480px !important;
            margin: 0 auto !important;
            padding: 8px 12px !important;
            background-color: var(--skeuo-surface) !important;
            border: 2px solid var(--skeuo-highlight) !important;
            box-shadow: var(--skeuo-outer) !important;
            z-index: 100 !important;
            backdrop-filter: none !important;
            -webkit-backdrop-filter: none !important;
            
            display: flex !important;
            flex-direction: row !important;
            justify-content: space-between !important;
          }
          
          .admin-nav-item {
            flex: 1 !important;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            gap: 4px !important;
            padding: 6px 2px !important;
            font-size: 10px !important;
            text-align: center !important;
            min-width: 0 !important;
            line-height: 1.2 !important;
          }
          
          .admin-nav-item.active {
            background-color: var(--skeuo-bg) !important;
            box-shadow: var(--skeuo-pressed) !important;
            border: 1px solid rgba(0,0,0,0.05) !important;
            transform: translateY(1px) !important;
          }
        }
      `}</style>

      {/* Sidebar Navigation */}
      <aside className="admin-sidebar">
        <div className="admin-sidebar-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <img src="/logo.svg" alt="Adnora Logo" style={{ height: '32px', transform: 'scale(3.5)', transformOrigin: 'left center' }} />
          <div style={{ display: 'flex', gap: '8px' }}>
            <button 
              onClick={() => navigate('/employee')}
              className="admin-header-portal-btn"
              title="My Attendance"
            >
              <UserCheck size={14} />
              <span>My Attendance</span>
            </button>
          </div>
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
