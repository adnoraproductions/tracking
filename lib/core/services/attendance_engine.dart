import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/attendance/models/attendance_models.dart';
import '../../features/attendance/repositories/attendance_repository.dart';
import 'wifi_monitor_service.dart';

/// Attendance engine state
class AttendanceEngineState {
  const AttendanceEngineState({
    this.session,
    this.isTracking = false,
    this.isOnOfficeWifi = false,
    this.elapsedSeconds = 0,
    this.currentSsid,
  });

  final AttendanceSession? session;
  final bool isTracking;
  final bool isOnOfficeWifi;
  final int elapsedSeconds;
  final String? currentSsid;

  String get timerText {
    final h = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Duration get elapsed => Duration(seconds: elapsedSeconds);

  AttendanceEngineState copyWith({
    AttendanceSession? session,
    bool? isTracking,
    bool? isOnOfficeWifi,
    int? elapsedSeconds,
    String? currentSsid,
  }) {
    return AttendanceEngineState(
      session: session ?? this.session,
      isTracking: isTracking ?? this.isTracking,
      isOnOfficeWifi: isOnOfficeWifi ?? this.isOnOfficeWifi,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentSsid: currentSsid ?? this.currentSsid,
    );
  }
}

/// Provider for the attendance engine
final attendanceEngineProvider =
    StateNotifierProvider<AttendanceEngine, AttendanceEngineState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final wifiMonitor = ref.watch(wifiMonitorServiceProvider);
  final engine = AttendanceEngine(repo, wifiMonitor);
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Orchestrates WiFi-based attendance tracking
class AttendanceEngine extends StateNotifier<AttendanceEngineState> {
  AttendanceEngine(this._repo, this._wifiMonitor)
      : super(const AttendanceEngineState());

  final AttendanceRepository _repo;
  final WifiMonitorService _wifiMonitor;

  Timer? _tickTimer;
  Timer? _syncTimer;
  Timer? _gracePeriodTimer;
  StreamSubscription? _wifiSub;
  String? _userId;
  DateTime? _trackingStartedAt;

  /// Initialize the engine for a specific user
  Future<void> initialize(String userId) async {
    _userId = userId;

    // Get or create today's session
    final session = await _repo.getOrCreateTodaySession(userId);
    if (session == null) return;

    state = state.copyWith(
      session: session,
      elapsedSeconds: session.totalSeconds,
    );

    // Start listening to WiFi changes
    _wifiSub = _wifiMonitor.statusStream.listen(_onWifiStatusChanged);

    // Start WiFi monitoring
    await _wifiMonitor.startMonitoring();

    // Set up periodic sync to server (every 60 seconds)
    _syncTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _syncToServer(),
    );

    // Check for midnight reset
    _scheduleMidnightReset();
  }

  void _onWifiStatusChanged(WifiStatus status) {
    final wasOnOffice = state.isOnOfficeWifi;
    final isNowOnOffice = status.isConnectedToOffice;

    state = state.copyWith(
      isOnOfficeWifi: isNowOnOffice,
      currentSsid: status.currentSsid,
    );

    if (!wasOnOffice && isNowOnOffice) {
      // Just connected to office WiFi → start tracking
      _startTracking(status);
    } else if (wasOnOffice && !isNowOnOffice) {
      // Disconnected from office WiFi → pause tracking
      _pauseTracking();
    }
  }

  void _startTracking(WifiStatus status) {
    if (_gracePeriodTimer != null && _gracePeriodTimer!.isActive) {
      debugPrint('AttendanceEngine: Reconnected during grace period. Cancelling checkout.');
      _gracePeriodTimer!.cancel();
    }

    if (state.isTracking) return;

    debugPrint('AttendanceEngine: Starting tracking on ${status.currentSsid}');

    _trackingStartedAt = DateTime.now();
    final initialElapsedSeconds = state.elapsedSeconds;
    state = state.copyWith(isTracking: true);

    // Mark clock-in if this is the first connect today
    final session = state.session;
    if (session != null && session.firstClockIn == null) {
      _repo.markClockIn(session.id);
      state = state.copyWith(
        session: session.copyWith(firstClockIn: DateTime.now()),
      );
    }

    // Log WiFi connect event
    if (session != null) {
      _repo.logEvent(
        sessionId: session.id,
        userId: _userId!,
        eventType: 'wifi_connect',
        wifiSsid: status.currentSsid,
        wifiBssid: status.currentBssid,
      );
    }

    // Start tick timer (robust against backgrounding)
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isTracking && mounted && _trackingStartedAt != null) {
        final diff = DateTime.now().difference(_trackingStartedAt!).inSeconds;
        state = state.copyWith(elapsedSeconds: initialElapsedSeconds + diff);
      }
    });
  }

  void _pauseTracking() {
    if (!state.isTracking) return;

    debugPrint('AttendanceEngine: Disconnected. Starting 5-minute grace period...');
    
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      _executeCheckout();
    });
  }

  void _executeCheckout() {
    if (!state.isTracking) return;
    
    debugPrint('AttendanceEngine: Grace period expired. Executing checkout.');

    state = state.copyWith(isTracking: false);
    _tickTimer?.cancel();

    // Log WiFi disconnect event
    final session = state.session;
    if (session != null) {
      _repo.logEvent(
        sessionId: session.id,
        userId: _userId!,
        eventType: 'wifi_disconnect',
      );
    }

    // Sync accumulated time
    _syncToServer();
  }

  Future<void> _syncToServer() async {
    final session = state.session;
    if (session == null) return;

    await _repo.updateSessionTime(
      sessionId: session.id,
      totalSeconds: state.elapsedSeconds,
    );
  }

  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);

    Future.delayed(diff, () async {
      if (!mounted) return;

      // Finalize today's session
      final session = state.session;
      if (session != null) {
        await _syncToServer();
        await _repo.finalizeSession(session.id);
      }

      // Start fresh for new day
      if (_userId != null) {
        state = const AttendanceEngineState();
        await initialize(_userId!);
      }
    });
  }

  /// Manual clock-out (override)
  Future<void> manualClockOut() async {
    final session = state.session;
    if (session == null) return;

    _pauseTracking();
    await _syncToServer();
    await _repo.finalizeSession(session.id);

    state = state.copyWith(
      isTracking: false,
      session: session.copyWith(
        status: 'completed',
        lastClockOut: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    _gracePeriodTimer?.cancel();
    _wifiSub?.cancel();
    super.dispose();
  }
}
