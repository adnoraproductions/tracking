import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_config.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(Supabase.instance.client);
});

class ReportsRepository {
  ReportsRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Map<String, dynamic>>> fetchReportData(ReportConfig config) async {
    // In a real production scenario, this relies on Postgres Views or RPC functions
    // For demonstration, we map the config to a generalized query
    
    switch (config.type) {
      case ReportType.daily:
      case ReportType.weekly:
      case ReportType.monthly:
        return _fetchTimeBasedReport(config);
      case ReportType.employee:
        return _fetchEmployeeReport(config.targetId!);
      case ReportType.project:
        return _fetchProjectReport(config.targetId!);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTimeBasedReport(ReportConfig config) async {
    // Queries attendance, tasks, or projects within config.startDate and config.endDate
    final start = config.startDate?.toIso8601String();
    final end = config.endDate?.toIso8601String();

    final response = await _supabase
        .from('attendance_sessions')
        .select('user_id, date, status, total_minutes, profiles!fk_attendance_sessions_profile(full_name)')
        .gte('date', start!)
        .lte('date', end!)
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchEmployeeReport(String employeeId) async {
    // Join tasks and attendance for an employee
    final tasks = await _supabase
        .from('tasks')
        .select('title, status, priority, due_date')
        .eq('assignee_id', employeeId);
        
    return List<Map<String, dynamic>>.from(tasks);
  }

  Future<List<Map<String, dynamic>>> _fetchProjectReport(String projectId) async {
    // Fetch project progress, team, and delivery status
    final project = await _supabase
        .from('projects')
        .select('name, status, progress, clients(name)')
        .eq('id', projectId)
        .single();
        
    return [project];
  }
}
