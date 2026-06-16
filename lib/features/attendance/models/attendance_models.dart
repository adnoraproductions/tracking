/// Attendance session — one per employee per day
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.userId,
    required this.date,
    this.firstClockIn,
    this.lastClockOut,
    this.totalSeconds = 0,
    this.breakSeconds = 0,
    this.status = 'active',
    this.createdAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      firstClockIn: json['first_clock_in'] != null
          ? DateTime.parse(json['first_clock_in'])
          : null,
      lastClockOut: json['last_clock_out'] != null
          ? DateTime.parse(json['last_clock_out'])
          : null,
      totalSeconds: json['total_seconds'] ?? 0,
      breakSeconds: json['break_seconds'] ?? 0,
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  final String id;
  final String userId;
  final DateTime date;
  final DateTime? firstClockIn;
  final DateTime? lastClockOut;
  final int totalSeconds;
  final int breakSeconds;
  final String status; // 'active', 'completed', 'absent'
  final DateTime? createdAt;

  Duration get totalDuration => Duration(seconds: totalSeconds);
  Duration get breakDuration => Duration(seconds: breakSeconds);
  Duration get productiveDuration => Duration(seconds: totalSeconds - breakSeconds);

  bool get isActive => status == 'active';

  AttendanceSession copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? firstClockIn,
    DateTime? lastClockOut,
    int? totalSeconds,
    int? breakSeconds,
    String? status,
    DateTime? createdAt,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      firstClockIn: firstClockIn ?? this.firstClockIn,
      lastClockOut: lastClockOut ?? this.lastClockOut,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      breakSeconds: breakSeconds ?? this.breakSeconds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'first_clock_in': firstClockIn?.toIso8601String(),
      'last_clock_out': lastClockOut?.toIso8601String(),
      'total_seconds': totalSeconds,
      'break_seconds': breakSeconds,
      'status': status,
    };
  }
}

/// Granular attendance event (WiFi connect/disconnect log)
class AttendanceEvent {
  const AttendanceEvent({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.eventType,
    this.wifiSsid,
    this.wifiBssid,
    required this.timestamp,
  });

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    return AttendanceEvent(
      id: json['id'],
      sessionId: json['session_id'],
      userId: json['user_id'],
      eventType: json['event_type'],
      wifiSsid: json['wifi_ssid'],
      wifiBssid: json['wifi_bssid'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  final String id;
  final String sessionId;
  final String userId;
  final String eventType; // 'wifi_connect', 'wifi_disconnect', 'manual_clock_in', 'manual_clock_out'
  final String? wifiSsid;
  final String? wifiBssid;
  final DateTime timestamp;


  Map<String, dynamic> toInsertJson() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'event_type': eventType,
      'wifi_ssid': wifiSsid,
      'wifi_bssid': wifiBssid,
    };
  }
}
