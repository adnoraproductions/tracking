import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/animated_stat_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../admin/repositories/admin_repository.dart';

// Provider for employee summary
final employeeSummaryProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getEmployeeSummary();
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;
    final colors = context.colors;

    final summaryAsync = ref.watch(employeeSummaryProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: topPadding + AppSpacing.xl, left: hPad, right: hPad, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── iOS-style Large Title Header ─────────────────
          Text(
            dateStr,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              letterSpacing: 0.2,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 4),
          Text(
            'Dashboard',
            style: AppTypography.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, end: 0),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Overview Stats ───────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : constraints.maxWidth > 500 ? 2 : 2;
            return summaryAsync.when(
              data: (summary) => GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: constraints.maxWidth > 500 ? 1.4 : 1.3,
                children: [
                  AnimatedStatCard(
                    label: 'Total Employees',
                    value: summary['total']?.toDouble() ?? 0,
                    icon: Icons.people_outline,
                    trend: 2.0,
                    trendLabel: 'vs last month',
                  ),
                  AnimatedStatCard(
                    label: 'Active',
                    value: summary['active']?.toDouble() ?? 0,
                    icon: Icons.check_circle_outline,
                    iconColor: colors.success,
                  ),
                  AnimatedStatCard(
                    label: 'Inactive',
                    value: summary['inactive']?.toDouble() ?? 0,
                    icon: Icons.pause_circle_outline,
                    iconColor: colors.amber,
                  ),
                  AnimatedStatCard(
                    label: 'System Health',
                    value: 100,
                    suffix: '%',
                    icon: Icons.monitor_heart_outlined,
                    iconColor: colors.cyan,
                  ),
                ],
              ),
              loading: () => Center(child: CircularProgressIndicator(color: colors.brand)),
              error: (e, _) => Text('Error: $e'),
            );
          }),

          const SizedBox(height: AppSpacing.xxl),

          // ─── Live Attendance Panel ────────────────────────
          const SectionHeader(title: 'Live Attendance', overline: 'TODAY'),
          GlassCard(
            hasEntranceAnimation: true,
            animationDelay: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: colors.success.withValues(alpha: 0.4), blurRadius: 6),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.3, duration: 1200.ms),
                    const SizedBox(width: AppSpacing.md),
                    Text('Monitoring Office WiFi', style: AppTypography.titleMedium.copyWith(color: colors.textPrimary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Employees are automatically tracked when connected to the configured office WiFi network.',
                  style: AppTypography.bodySmall.copyWith(color: colors.textTertiary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
