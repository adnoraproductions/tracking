import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_config.dart';
import '../repositories/reports_repository.dart';
import '../services/export_service.dart';

// Provides the ExportService
final exportServiceProvider = Provider((ref) => ExportService());

// Global state for what report is currently being configured
final reportConfigProvider = StateProvider<ReportConfig>((ref) {
  final now = DateTime.now();
  return ReportConfig(
    type: ReportType.daily,
    startDate: DateTime(now.year, now.month, now.day),
    endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
});

// Asynchronously fetches the data preview based on the current config
final reportPreviewProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final config = ref.watch(reportConfigProvider);
  final repo = ref.watch(reportsRepositoryProvider);
  
  if (config.type == ReportType.employee || config.type == ReportType.project) {
    if (config.targetId == null) return [];
  }
  
  return repo.fetchReportData(config);
});

// A UI State for managing the export progress spinner
final isExportingProvider = StateProvider<bool>((ref) => false);
