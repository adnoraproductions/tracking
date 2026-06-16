import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_models.dart';
import '../repositories/attendance_repository.dart';
import '../../../core/services/attendance_engine.dart';

/// Provider for today's active session
final todaySessionProvider = FutureProvider.family<AttendanceSession?, String>((ref, userId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getOrCreateTodaySession(userId);
});

/// Provider for session history
final sessionHistoryProvider = FutureProvider.family<List<AttendanceSession>, String>((ref, userId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getSessionHistory(userId: userId);
});

/// Provider for events of a specific session
final sessionEventsProvider = FutureProvider.family<List<AttendanceEvent>, String>((ref, sessionId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getSessionEvents(sessionId);
});

/// Exposes the live elapsed duration from the engine
final liveTimerProvider = Provider<Duration>((ref) {
  final state = ref.watch(attendanceEngineProvider);
  return state.elapsed;
});
