enum ReportType { daily, weekly, monthly, employee, project }
enum ExportFormat { csv, excel, pdf }

class ReportConfig {
  const ReportConfig({
    required this.type,
    this.startDate,
    this.endDate,
    this.targetId,
    this.data = const [],
  });

  factory ReportConfig.fromJson(Map<String, dynamic> json) {
    return ReportConfig(
      type: ReportType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReportType.daily,
      ),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      targetId: json['targetId'],
      data: List<Map<String, dynamic>>.from(json['data'] ?? []),
    );
  }

  final ReportType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? targetId;
  final List<Map<String, dynamic>> data;

  ReportConfig copyWith({
    ReportType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? targetId,
    List<Map<String, dynamic>>? data,
  }) {
    return ReportConfig(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetId: targetId ?? this.targetId,
      data: data ?? this.data,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'targetId': targetId,
      'data': data,
    };
  }
}
