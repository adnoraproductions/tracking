import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../models/attendance_models.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(SupabaseService.client);
});

/// Repository for attendance sessions and events
class AttendanceRepository {
  AttendanceRepository(this._client);
  final SupabaseClient _client;

  /// Get or create today's attendance session for a user
  Future<AttendanceSession?> getOrCreateTodaySession(String userId) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Try to get existing session
      final existing = await _client
          .from(AppConstants.tableAttendanceSessions)
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        return AttendanceSession.fromJson(existing);
      }

      // Create new session
      final data = {
        'user_id': userId,
        'date': dateStr,
        'status': 'active',
        'total_seconds': 0,
        'break_seconds': 0,
      };

      final response = await _client
          .from(AppConstants.tableAttendanceSessions)
          .insert(data)
          .select()
          .single();

      return AttendanceSession.fromJson(response);
    } catch (e) {
      debugPrint('AttendanceRepository.getOrCreateTodaySession error: $e');
      return null;
    }
  }

  /// Log a WiFi connect/disconnect event
  Future<AttendanceEvent?> logEvent({
    required String sessionId,
    required String userId,
    required String eventType,
    String? wifiSsid,
    String? wifiBssid,
  }) async {
    try {
      final data = {
        'session_id': sessionId,
        'user_id': userId,
        'event_type': eventType,
        'wifi_ssid': wifiSsid,
        'wifi_bssid': wifiBssid,
      };

      final response = await _client
          .from(AppConstants.tableAttendanceEvents)
          .insert(data)
          .select()
          .single();

      return AttendanceEvent.fromJson(response);
    } catch (e) {
      debugPrint('AttendanceRepository.logEvent error: $e');
      return null;
    }
  }

  /// Update session time (sync accumulated seconds)
  Future<void> updateSessionTime({
    required String sessionId,
    required int totalSeconds,
    int breakSeconds = 0,
  }) async {
    try {
      await _client
          .from(AppConstants.tableAttendanceSessions)
          .update({
            'total_seconds': totalSeconds,
            'break_seconds': breakSeconds,
          })
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('AttendanceRepository.updateSessionTime error: $e');
    }
  }

  /// Mark first clock-in time
  Future<void> markClockIn(String sessionId) async {
    try {
      await _client
          .from(AppConstants.tableAttendanceSessions)
          .update({
            'first_clock_in': DateTime.now().toIso8601String(),
            'status': 'active',
          })
          .eq('id', sessionId)
          .filter('first_clock_in', 'is', null); // Only set if not already set
    } catch (e) {
      debugPrint('AttendanceRepository.markClockIn error: $e');
    }
  }

  /// Finalize session (end of day)
  Future<void> finalizeSession(String sessionId) async {
    try {
      await _client
          .from(AppConstants.tableAttendanceSessions)
          .update({
            'last_clock_out': DateTime.now().toIso8601String(),
            'status': 'completed',
          })
          .eq('id', sessionId);
    } catch (e) {
      debugPrint('AttendanceRepository.finalizeSession error: $e');
    }
  }

  /// Get session history for a user
  Future<List<AttendanceSession>> getSessionHistory({
    required String userId,
    int limit = 30,
  }) async {
    try {
      final response = await _client
          .from(AppConstants.tableAttendanceSessions)
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => AttendanceSession.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('AttendanceRepository.getSessionHistory error: $e');
      return [];
    }
  }

  /// Get events for a session
  Future<List<AttendanceEvent>> getSessionEvents(String sessionId) async {
    try {
      final response = await _client
          .from(AppConstants.tableAttendanceEvents)
          .select()
          .eq('session_id', sessionId)
          .order('timestamp', ascending: true);

      return (response as List)
          .map((e) => AttendanceEvent.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('AttendanceRepository.getSessionEvents error: $e');
      return [];
    }
  }
}
