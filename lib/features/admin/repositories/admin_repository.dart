import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/user_profile.dart';
import '../models/wifi_config.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(SupabaseService.client);
});

/// Repository for all admin operations: employee CRUD, WiFi config, attendance overview
class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  // ─── Employee Management ────────────────────────────────

  /// Get all employees (profiles with role = 'employee')
  Future<List<UserProfile>> getEmployees() async {
    try {
      final response = await _client
          .from(AppConstants.tableProfiles)
          .select()
          .eq('role', 'employee')
          .order('full_name', ascending: true);

      return (response as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      debugPrint('AdminRepository.getEmployees error: $e');
      return [];
    }
  }

  /// Create a new employee account (Supabase auth + profile row)
  /// Uses auth.signUp + session restore instead of admin API (which needs service_role key)
  Future<UserProfile?> createEmployee({
    required String email,
    required String password,
    required String fullName,
    String? department,
    String? designation,
    String? phone,
  }) async {
    try {
      // Create a temporary client so signUp doesn't affect the admin's active session
      final tempClient = SupabaseClient(
        AppConstants.supabaseUrl,
        AppConstants.supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      // Sign up the new employee
      final authResponse = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      // Clean up the temporary client's resources
      tempClient.dispose();

      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Failed to create auth user');

      // 4. Update the profile with additional fields
      final now = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        'email': email,
        'full_name': fullName,
        'role': 'employee',
        'department': department,
        'designation': designation,
        'phone': phone,
        'is_active': true,
        'onboarding_complete': true,
        'updated_at': now,
      };

      final response = await _client
          .from(AppConstants.tableProfiles)
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('AdminRepository.createEmployee error: $e');
      return null;
    }
  }

  /// Update employee profile
  Future<UserProfile?> updateEmployee({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from(AppConstants.tableProfiles)
          .update(updates)
          .eq('id', userId)
          .select()
          .single();
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('AdminRepository.updateEmployee error: $e');
      return null;
    }
  }

  /// Deactivate an employee
  Future<bool> deactivateEmployee(String userId) async {
    try {
      await _client
          .from(AppConstants.tableProfiles)
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('AdminRepository.deactivateEmployee error: $e');
      return false;
    }
  }

  // ─── WiFi Configuration ─────────────────────────────────

  /// Get all configured WiFi networks
  Future<List<WifiConfig>> getWifiConfigs() async {
    try {
      final response = await _client
          .from(AppConstants.tableWifiConfig)
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((e) => WifiConfig.fromJson(e)).toList();
    } catch (e) {
      debugPrint('AdminRepository.getWifiConfigs error: $e');
      return [];
    }
  }

  /// Add a new WiFi network configuration
  Future<WifiConfig?> addWifiConfig({
    required String ssid,
    String? bssid,
    String label = 'Office',
    required String createdBy,
  }) async {
    try {
      final data = {
        'ssid': ssid,
        'bssid': bssid,
        'label': label,
        'is_active': true,
        'created_by': createdBy,
      };

      final response = await _client
          .from(AppConstants.tableWifiConfig)
          .insert(data)
          .select()
          .single();

      return WifiConfig.fromJson(response);
    } catch (e) {
      debugPrint('AdminRepository.addWifiConfig error: $e');
      return null;
    }
  }

  /// Toggle WiFi config active/inactive
  Future<bool> toggleWifiConfig(String configId, bool isActive) async {
    try {
      await _client
          .from(AppConstants.tableWifiConfig)
          .update({'is_active': isActive})
          .eq('id', configId);
      return true;
    } catch (e) {
      debugPrint('AdminRepository.toggleWifiConfig error: $e');
      return false;
    }
  }

  /// Delete a WiFi configuration
  Future<bool> deleteWifiConfig(String configId) async {
    try {
      await _client
          .from(AppConstants.tableWifiConfig)
          .delete()
          .eq('id', configId);
      return true;
    } catch (e) {
      debugPrint('AdminRepository.deleteWifiConfig error: $e');
      return false;
    }
  }

  // ─── Attendance Overview (Admin) ─────────────────────────

  /// Get all attendance sessions for a specific date
  Future<List<Map<String, dynamic>>> getAllAttendanceForDate(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _client
          .from(AppConstants.tableAttendanceSessions)
          .select('*, profiles!fk_attendance_sessions_profile!inner(full_name, email, avatar_url, department)')
          .eq('date', dateStr)
          .order('first_clock_in', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('AdminRepository.getAllAttendanceForDate error: $e');
      return [];
    }
  }

  /// Get employee count summary
  Future<Map<String, int>> getEmployeeSummary() async {
    try {
      final employees = await getEmployees();
      final active = employees.where((e) => e.isActive).length;
      final inactive = employees.where((e) => !e.isActive).length;
      return {
        'total': employees.length,
        'active': active,
        'inactive': inactive,
      };
    } catch (e) {
      return {'total': 0, 'active': 0, 'inactive': 0};
    }
  }
}
