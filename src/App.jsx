import React, { lazy } from 'react';
import { HashRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ProtectedRoute } from './components/layout/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';
import { ToastProvider, ConfirmProvider } from './components/ui';
import { USER_ROLES } from './types';

// Auth
import Login from './pages/auth/Login';
// Employee
import EmployeeDashboard from './pages/employee/EmployeeDashboard';
import EmployeeAttendance from './pages/employee/EmployeeAttendance';
import EmployeeSettings from './pages/employee/EmployeeSettings';
import MyTasks from './pages/tasks/MyTasks';
import MyLeaves from './pages/leaves/MyLeaves';
// Manager + admin screens are loaded on demand to keep the phone bundle small
const Approvals = lazy(() => import('./pages/manage/Approvals'));
const Performance = lazy(() => import('./pages/manage/Performance'));
const AdminDashboard = lazy(() => import('./pages/admin/AdminDashboard'));
const AdminAttendance = lazy(() => import('./pages/admin/AdminAttendance'));
const EmployeeManager = lazy(() => import('./pages/admin/EmployeeManager'));
const OfficeSettings = lazy(() => import('./pages/admin/OfficeSettings'));
const Finance = lazy(() => import('./pages/finance/Finance'));

import './pages/employee/Employee.css';
import './pages/admin/Admin.css';

function RootRedirect() {
  const { user, role, loading } = useAuth();
  if (loading) return null;
  if (!user) return <Navigate to="/login" replace />;
  return <Navigate to={role === USER_ROLES.ADMIN ? '/admin' : '/employee'} replace />;
}

function RoleGate({ roles }) {
  const { role } = useAuth();
  if (!roles.includes(role)) return <Navigate to={role === USER_ROLES.ADMIN ? '/admin' : '/employee'} replace />;
  return <Outlet />;
}

const ALL_ROLES = [USER_ROLES.EMPLOYEE, USER_ROLES.MANAGER, USER_ROLES.ADMIN];

export default function App() {
  return (
    <AuthProvider>
      <ToastProvider>
        <ConfirmProvider>
        <HashRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/" element={<RootRedirect />} />

            <Route element={<ProtectedRoute allowedRoles={ALL_ROLES} />}>
              <Route element={<AppLayout />}>
                {/* Everyone */}
                <Route path="/employee/settings" element={<EmployeeSettings />} />

                {/* Employees + project managers (admins don't clock in, take leave or log tasks) */}
                <Route element={<RoleGate roles={[USER_ROLES.EMPLOYEE, USER_ROLES.MANAGER]} />}>
                  <Route path="/employee" element={<EmployeeDashboard />} />
                  <Route path="/employee/tasks" element={<MyTasks />} />
                  <Route path="/employee/leaves" element={<MyLeaves />} />
                  <Route path="/employee/attendance" element={<EmployeeAttendance />} />
                </Route>

                {/* Project managers + admins */}
                <Route element={<RoleGate roles={[USER_ROLES.MANAGER, USER_ROLES.ADMIN]} />}>
                  <Route path="/manage/approvals" element={<Approvals />} />
                  <Route path="/manage/performance" element={<Performance />} />
                </Route>

                {/* Admins only */}
                <Route element={<RoleGate roles={[USER_ROLES.ADMIN]} />}>
                  <Route path="/admin" element={<AdminDashboard />} />
                  <Route path="/admin/attendance" element={<AdminAttendance />} />
                  <Route path="/admin/employees" element={<EmployeeManager />} />
                  <Route path="/admin/office" element={<OfficeSettings />} />
                  <Route path="/admin/finance" element={<Finance />} />
                </Route>
              </Route>
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </HashRouter>
        </ConfirmProvider>
      </ToastProvider>
    </AuthProvider>
  );
}
