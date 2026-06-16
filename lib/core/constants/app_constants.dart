/// ADNORA OS App-level Constants
abstract final class AppConstants {
  // ─── App Info ───────────────────────────────────────────
  static const String appName = 'ADNORA OS';
  static const String appTagline = 'Creative Operations Platform';
  static const String appVersion = '1.0.0';
  static const String orgName = 'Adnora Productions';

  // ─── Supabase ───────────────────────────────────────────
  static const String supabaseUrl = 'https://fbzkjncodfgftszexift.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZiemtqbmNvZGZnZnRzemV4aWZ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1MjIzMTAsImV4cCI6MjA5NzA5ODMxMH0.GnvWSIqhwcWV9qOFZRxRRajoc6aj4EETtAXVjgnhoP0';

  // ─── Roles ──────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleEmployee = 'employee';

  // ─── Pagination ─────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ─── Storage Buckets ────────────────────────────────────
  static const String bucketAvatars = 'avatars';
  static const String bucketDrive = 'drive-files';
  static const String bucketProjects = 'project-assets';

  // ─── Table Names ────────────────────────────────────────
  static const String tableUsers = 'users';
  static const String tableProfiles = 'profiles';
  static const String tableAttendanceSessions = 'attendance_sessions';
  static const String tableAttendanceEvents = 'attendance_events';
  static const String tableProjects = 'projects';
  static const String tableClients = 'clients';
  static const String tableTasks = 'tasks';
  static const String tableTaskChecklists = 'task_checklists';
  static const String tableProjectNotes = 'project_notes';
  static const String tableNotifications = 'notifications';
  static const String tableDriveFiles = 'drive_files';
  static const String tableLeaveRequests = 'leave_requests';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableSettings = 'settings';
  static const String tableDepartments = 'departments';
  static const String tableWifiConfig = 'wifi_config';

  // ─── Date Formats ───────────────────────────────────────
  static const String dateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
}
