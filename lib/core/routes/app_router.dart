import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/employee_home_screen.dart';
import '../../features/leave/screens/requests_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/shell/employee_shell.dart';
import '../../features/shell/admin_shell.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_employee_mgmt_screen.dart';
import '../../features/admin/screens/admin_wifi_config_screen.dart';
import '../../features/admin/screens/admin_attendance_overview_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/enums/enums.dart';

import '../../features/projects/screens/projects_screen.dart';
import '../../features/projects/screens/project_detail_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/clients/screens/clients_screen.dart';
import '../../features/clients/screens/client_detail_screen.dart';
import '../../features/drive/screens/drive_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/team/screens/employees_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/journal/screens/journal_screen.dart';

/// ADNORA OS Route Paths
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String attendance = '/attendance';
  static const String projects = '/projects';
  static const String projectDetail = '/projects/:id';
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String clients = '/clients';
  static const String clientDetail = '/clients/:id';
  static const String drive = '/drive';
  static const String leave = '/leave';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String team = '/team';
  static const String auditLog = '/audit-log';
  static const String reports = '/reports';
  static const String adminWifiConfig = '/admin/wifi-config';
  static const String adminEmployees = '/admin/employees';
  static const String adminAttendance = '/admin/attendance';
  static const String journal = '/journal';
}

/// GoRouter provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authRepo = ref.read(authRepositoryProvider);
      final isAuthenticated = authRepo.isAuthenticated;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.onboarding;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // If on splash, let it handle its own redirect
      if (isSplash) return null;

      // If not authenticated and not on auth route, redirect to login
      if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;

      // If authenticated and on auth route, redirect to dashboard
      if (isAuthenticated && isAuthRoute) return AppRoutes.dashboard;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const _PlaceholderPage(title: 'Register'),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ─── Shell: App Layout ───────────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final roleAsync = ref.watch(userRoleProvider);
              return roleAsync.when(
                data: (role) {
                  if (role == UserRole.admin) {
                    return AdminShell(child: child);
                  }
                  return EmployeeShell(child: child);
                },
                loading: () => const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => EmployeeShell(child: child),
              );
            },
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => _buildPage(
              state,
              Consumer(
                builder: (context, ref, _) {
                  final roleAsync = ref.watch(userRoleProvider);
                  return roleAsync.maybeWhen(
                    data: (role) {
                      if (role == UserRole.admin) {
                        return const AdminDashboardScreen();
                      }
                      return const EmployeeHomeScreen();
                    },
                    orElse: () => const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            pageBuilder: (context, state) => _buildPage(
              state,
              Consumer(
                builder: (context, ref, _) {
                  final roleAsync = ref.watch(userRoleProvider);
                  return roleAsync.maybeWhen(
                    data: (role) {
                      if (role == UserRole.admin) {
                        return const AdminAttendanceOverviewScreen();
                      }
                      return const AttendanceScreen();
                    },
                    orElse: () => const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminWifiConfig,
            pageBuilder: (context, state) => _buildPage(
              state,
              const AdminWifiConfigScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminEmployees,
            pageBuilder: (context, state) => _buildPage(
              state,
              const AdminEmployeeMgmtScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminAttendance,
            pageBuilder: (context, state) => _buildPage(
              state,
              const AdminAttendanceOverviewScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.projects,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ProjectsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _buildPage(
                  state,
                  ProjectDetailScreen(projectId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.tasks,
            pageBuilder: (context, state) => _buildPage(
              state,
              const TasksScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _buildPage(
                  state,
                  TaskDetailScreen(taskId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.clients,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ClientsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _buildPage(
                  state,
                  ClientDetailScreen(clientId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.drive,
            pageBuilder: (context, state) => _buildPage(
              state,
              const DriveScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.leave,
            pageBuilder: (context, state) => _buildPage(
              state,
              const RequestsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) => _buildPage(
              state,
              const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => _buildPage(
              state,
              const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.team,
            pageBuilder: (context, state) => _buildPage(
              state,
              Consumer(
                builder: (context, ref, _) {
                  final roleAsync = ref.watch(userRoleProvider);
                  return roleAsync.maybeWhen(
                    data: (role) {
                      if (role == UserRole.admin) {
                        return const AdminEmployeeMgmtScreen();
                      }
                      return const EmployeesScreen();
                    },
                    orElse: () => const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.auditLog,
            pageBuilder: (context, state) => _buildPage(
              state,
              const _PlaceholderPage(title: 'Audit Log'), // Still missing
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.journal,
            pageBuilder: (context, state) => _buildPage(
              state,
              const JournalScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Custom page transition — fade + slide
CustomTransitionPage<void> _buildPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

/// Temporary placeholder until feature pages are built
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
