/// Attendance session model (daily clock-in/out session)
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.userId,
    required this.date,
    required this.clockIn,
    this.clockOut,
    required this.status,
    this.totalMinutes,
    this.bssid,
    this.isAutoCheckout = false,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      clockIn: DateTime.parse(json['clock_in'] as String),
      clockOut: json['clock_out'] != null ? DateTime.parse(json['clock_out'] as String) : null,
      status: json['status'] as String,
      totalMinutes: json['total_minutes'] as int?,
      bssid: json['bssid'] as String?,
      isAutoCheckout: json['is_auto_checkout'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  final String id;
  final String userId;
  final DateTime date;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String status;
  final int? totalMinutes;
  final String? bssid;
  final bool isAutoCheckout;
  final DateTime? createdAt;
  final DateTime? updatedAt;


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'clock_in': clockIn.toIso8601String(),
      'clock_out': clockOut?.toIso8601String(),
      'status': status,
      'total_minutes': totalMinutes,
      'bssid': bssid,
      'is_auto_checkout': isAutoCheckout,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AttendanceSession copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? clockIn,
    DateTime? clockOut,
    String? status,
    int? totalMinutes,
    String? bssid,
    bool? isAutoCheckout,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      status: status ?? this.status,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      bssid: bssid ?? this.bssid,
      isAutoCheckout: isAutoCheckout ?? this.isAutoCheckout,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AttendanceSession(id: $id, status: $status, date: $date)';
}
