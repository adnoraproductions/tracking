/// Attendance log entry (clock in/out events within a session)
class AttendanceLog {
  const AttendanceLog({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.action,
    required this.timestamp,
    this.bssid,
    this.metadata,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      bssid: json['bssid'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  final String id;
  final String sessionId;
  final String userId;
  final String action; // e.g., 'CLOCK_IN', 'CLOCK_OUT', 'AUTO_CLOCK_OUT', 'WIFI_DISCONNECT'
  final DateTime timestamp;
  final String? bssid;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'bssid': bssid,
      'metadata': metadata,
    };
  }

  AttendanceLog copyWith({
    String? id,
    String? sessionId,
    String? userId,
    String? action,
    DateTime? timestamp,
    String? bssid,
    Map<String, dynamic>? metadata,
  }) {
    return AttendanceLog(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      bssid: bssid ?? this.bssid,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceLog &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AttendanceLog(id: $id, action: $action, timestamp: $timestamp)';
}
