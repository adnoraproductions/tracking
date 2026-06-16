import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../repositories/admin_repository.dart';

// Provider for today's attendance
final todayAttendanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllAttendanceForDate(DateTime.now());
});

class AdminAttendanceOverviewScreen extends ConsumerWidget {
  const AdminAttendanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.lg,
        left: AppSpacing.pagePaddingH,
        right: AppSpacing.pagePaddingH,
        bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('ATTENDANCE', style: AppTypography.caption.copyWith(
            color: context.colors.cyan, letterSpacing: 2, fontWeight: FontWeight.w700,
          )).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 4),
          Text('Live Overview', style: AppTypography.displaySmall)
              .animate(delay: 100.ms).fadeIn().slideX(begin: -0.03),

          const SizedBox(height: AppSpacing.md),
          Text(
            'Monitor employee attendance for today.',
            style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary, height: 1.5),
          ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: AppSpacing.xxl),

          // Attendance List
          attendanceAsync.when(
            data: (sessions) {
              if (sessions.isEmpty) {
                return _EmptyState().animate(delay: 300.ms).fadeIn();
              }
              return Column(
                children: sessions.asMap().entries.map((e) {
                  final i = e.key;
                  final session = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AttendanceCard(session: session)
                        .animate(delay: Duration(milliseconds: 300 + i * 60))
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: 0.03),
                  );
                }).toList(),
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: CircularProgressIndicator(color: context.colors.brand),
              ),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final profile = session['profiles'];
    final status = session['status'] as String;
    final firstClockIn = session['first_clock_in'] != null ? DateTime.parse(session['first_clock_in']) : null;
    final totalSeconds = session['total_seconds'] as int? ?? 0;
    
    final h = (totalSeconds ~/ 3600).toString();
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');

    StatusPreset preset = StatusPreset.inactive;
    if (status == 'active') {
      preset = StatusPreset.active;
    } else if (status == 'completed') {
      preset = StatusPreset.completed;
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: 16,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [context.colors.brand.withValues(alpha: 0.3), context.colors.cyan.withValues(alpha: 0.1)],
              ),
              border: Border.all(color: context.colors.brand.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                profile['full_name']?.isNotEmpty == true ? profile['full_name'][0].toUpperCase() : '?',
                style: AppTypography.titleMedium.copyWith(color: context.colors.brand),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile['full_name'] ?? 'Unknown', style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(
                  firstClockIn != null 
                    ? 'In at ${firstClockIn.hour}:${firstClockIn.minute.toString().padLeft(2, '0')}'
                    : 'Not clocked in',
                  style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${h}h ${m}m', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              StatusPill(
                label: status.toUpperCase(),
                preset: preset,
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 56, color: context.colors.textDisabled),
            const SizedBox(height: AppSpacing.lg),
            Text('No attendance records', style: AppTypography.titleMedium.copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            Text('No one has connected to the office WiFi today.',
                style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
