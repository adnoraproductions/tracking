import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';

class AdminAttendanceScreen extends StatelessWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppSpacing.lg, left: hPad, right: hPad, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance Log', style: AppTypography.displaySmall).animate().fadeIn().slideX(begin: -0.03),
          const SizedBox(height: AppSpacing.xxl),
          
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _AttendanceRow(name: 'Aarav Kumar', inTime: '09:00 AM', status: 'Present', color: context.colors.success),
                const Divider(),
                _AttendanceRow(name: 'Priya Singh', inTime: '--:--', status: 'Absent', color: context.colors.error),
                const Divider(),
                _AttendanceRow(name: 'Rahul Verma', inTime: '09:15 AM', status: 'Late', color: context.colors.amber),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.name, required this.inTime, required this.status, required this.color});
  final String name;
  final String inTime;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: AppTypography.titleMedium),
          Text(inTime, style: AppTypography.bodyMedium),
          Text(status, style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
