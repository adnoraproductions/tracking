import React from 'react';
import { Outlet, NavLink } from 'react-router-dom';
import { LayoutDashboard, Settings, ListTodo } from 'lucide-react';
import PageTransition from '../../components/PageTransition';
import './Employee.css';

export default function EmployeeLayout() {
  return (
    <div className="emp-layout">
      {/* Top Header */}
      <header className="emp-top-header">
        <h2><span style={{color: 'var(--emp-primary)'}}>•</span> Adnora</h2>
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
