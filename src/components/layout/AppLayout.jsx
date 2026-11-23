import React, { Suspense, useEffect, useMemo, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  Home,
  ClipboardList,
  CalendarDays,
  History,
  UserRound,
  CheckCheck,
  Trophy,
  LayoutDashboard,
  CalendarClock,
  Users,
  Wallet,
  MapPin,
  LogOut,
  Grid2x2,
} from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import PageTransition from '../PageTransition';
import { Avatar, Loading } from '../ui';

function buildNav(role) {
  const isManager = role === 'manager' || role === 'admin';
  const isAdmin = role === 'admin';
  const sections = [
    {
      label: 'My work',
      items: [
        { to: '/employee', end: true, label: 'Home', short: 'Home', icon: Home },
        { to: '/employee/tasks', label: 'Daily Tasks', short: 'Tasks', icon: ClipboardList },
        { to: '/employee/leaves', label: 'Leaves', short: 'Leaves', icon: CalendarDays },
        { to: '/employee/attendance', label: 'Attendance Log', short: 'Log', icon: History },
        { to: '/employee/settings', label: 'Profile', short: 'Profile', icon: UserRound },
      ],
    },
  ];
  if (isManager) {
    sections.push({
      label: 'Team',
      items: [
        { to: '/manage/approvals', label: 'Approvals', short: 'Approvals', icon: CheckCheck, badge: 'approvals' },
        { to: '/manage/performance', label: 'Performance', short: 'Performance', icon: Trophy },
      ],
    });
  }
  if (isAdmin) {
    sections.push({
      label: 'Admin',
      items: [
        { to: '/admin', end: true, label: 'Overview', short: 'Overview', icon: LayoutDashboard },
        { to: '/admin/attendance', label: 'Attendance', short: 'Attendance', icon: CalendarClock },
        { to: '/admin/employees', label: 'Employees', short: 'Employees', icon: Users },
        { to: '/admin/finance', label: 'Finance', short: 'Finance', icon: Wallet },
        { to: '/admin/office', label: 'Office Settings', short: 'Office', icon: MapPin },
      ],
    });
  }
  return sections;
}

export default function AppLayout() {
  const { profile, role, signOut } = useAuth();
  const location = useLocation();
  const [moreOpen, setMoreOpen] = useState(false);
  const [pending, setPending] = useState(0);
  const isManager = role === 'manager' || role === 'admin';

  const sections = useMemo(() => buildNav(role), [role]);
  const all = sections.flatMap((s) => s.items);

  // Mobile tab bar: 4 primary destinations + "More"
  const primary = isManager
    ? [all[0], all[1], all[2], all.find((i) => i.to === '/manage/approvals')]
    : [all[0], all[1], all[2], all[3]];
  const rest = all.filter((i) => !primary.includes(i));
  const moreActive = rest.some((i) => (i.end ? location.pathname === i.to : location.pathname.startsWith(i.to)));

  useEffect(() => {
    setMoreOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!isManager) return;
    let alive = true;
    (async () => {
      try {
        const [t, l] = await Promise.all([
          supabase.from('daily_tasks').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
          supabase.from('leave_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        ]);
        if (alive) setPending((t.count || 0) + (l.count || 0));
      } catch {
        /* tables may not exist yet */
      }
    })();
    return () => {
      alive = false;
    };
  }, [isManager, location.pathname]);

  const badgeFor = (item) => (item.badge === 'approvals' && pending > 0 ? pending : 0);

  return (
    <div className="shell">
      {/* Desktop sidebar */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <NavLink to="/employee" className="brand-chip"><span className="brand-mark" role="img" aria-label="Adnora" style={{ '--h': '26px' }} /></NavLink>
        </div>
        <nav className="sidebar-scroll">
          {sections.map((section) => (
            <div className="nav-section" key={section.label}>
              {sections.length > 1 && <div className="nav-section-label">{section.label}</div>}
              {section.items.map((item) => (
                <NavLink key={item.to} to={item.to} end={item.end} className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}>
                  <item.icon size={18} />
                  {item.label}
                  {badgeFor(item) > 0 && <span className="nav-count">{badgeFor(item)}</span>}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        <div className="sidebar-user">
          <Avatar name={profile?.full_name} />
          <div className="sidebar-user-info">
            <div className="sidebar-user-name">{profile?.full_name || 'User'}</div>
            <div className="sidebar-user-role">{role === 'manager' ? 'Project manager' : role}</div>
          </div>
          <button className="icon-btn" onClick={signOut} title="Sign out" aria-label="Sign out">
            <LogOut size={16} />
          </button>
        </div>
      </aside>

      {/* Mobile top bar */}
      <header className="topbar">
        <NavLink to="/employee" className="brand-chip"><span className="brand-mark" role="img" aria-label="Adnora" style={{ '--h': '18px' }} /></NavLink>
        <NavLink to="/employee/settings" aria-label="Profile" style={{ textDecoration: 'none' }}>
          <Avatar name={profile?.full_name} size="sm" />
        </NavLink>
      </header>

      <main className="main">
        <div className="main-inner">
          <PageTransition>
            <Suspense fallback={<Loading />}>
              <Outlet />
            </Suspense>
          </PageTransition>
        </div>
      </main>

      {/* Mobile tab bar */}
      <nav className="tabbar">
        {primary.map((item) => (
          <NavLink key={item.to} to={item.to} end={item.end} className={({ isActive }) => `tab-link ${isActive ? 'active' : ''}`}>
            <span className="tab-icon">
              <item.icon size={20} />
            </span>
            {item.short}
            {badgeFor(item) > 0 && <span className="tab-dot" />}
          </NavLink>
        ))}
        <button type="button" className={`tab-link ${moreActive || moreOpen ? 'active' : ''}`} onClick={() => setMoreOpen(true)}>
          <span className="tab-icon">
            <Grid2x2 size={20} />
          </span>
          More
        </button>
      </nav>

      {moreOpen && (
        <>
          <div className="sheet-backdrop" onClick={() => setMoreOpen(false)} />
          <div className="sheet" role="dialog" aria-label="More">
            <div className="sheet-handle" />
            <div className="row" style={{ padding: '0 4px 14px' }}>
              <Avatar name={profile?.full_name} />
              <div>
                <div className="strong">{profile?.full_name}</div>
                <div className="xs muted" style={{ textTransform: 'capitalize' }}>
                  {role === 'manager' ? 'Project manager' : role}
                </div>
              </div>
            </div>
            <div className="sheet-grid">
              {rest.map((item) => (
                <NavLink key={item.to} to={item.to} end={item.end} className={({ isActive }) => `sheet-item ${isActive ? 'active' : ''}`}>
                  <item.icon size={20} />
                  {item.short}
                </NavLink>
              ))}
              <button type="button" className="sheet-item danger" onClick={signOut}>
                <LogOut size={20} />
                Sign out
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
