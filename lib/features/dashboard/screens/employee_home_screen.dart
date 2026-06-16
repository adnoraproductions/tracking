import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/attendance_engine.dart';
import '../../../shared/widgets/animated_stat_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../auth/providers/auth_provider.dart';

class EmployeeHomeScreen extends ConsumerStatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  ConsumerState<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends ConsumerState<EmployeeHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref.read(attendanceEngineProvider.notifier).initialize(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final engineState = ref.watch(attendanceEngineProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final greeting = _greeting();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.lg,
        left: AppSpacing.pagePaddingH,
        right: AppSpacing.pagePaddingH,
        bottom: 120, // dock clearance
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppSpacing.xs),
                    profileAsync.when(
                      data: (profile) => Text(
                        'Welcome back, ${profile?.fullName.split(' ').first ?? ''} 👋',
                        style: AppTypography.displaySmall,
                      )
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: -0.03, end: 0),
                      loading: () => const SizedBox(height: 32),
                      error: (_, __) => const SizedBox(height: 32),
                    ),
                  ],
                ),
              ),
              // Avatar
              _GlassAvatar()
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ─── Quick Status Card ──────────────────────────
          _QuickStatusCard(engineState: engineState)
              .animate(delay: 200.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.04, end: 0),

          const SizedBox(height: AppSpacing.xxl),

          // ─── Stats Grid ─────────────────────────────────
          SectionHeader(
            title: 'Overview',
            overline: 'TODAY',
            animationDelay: 300.ms,
          ),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              AnimatedStatCard(
                label: 'Hours Logged',
                value: engineState.elapsedSeconds / 3600,
                suffix: 'h',
                icon: Icons.schedule_rounded,
                iconColor: context.colors.cyan,
                animationDelay: 400.ms,
                compact: true,
              ),
              AnimatedStatCard(
                label: 'Tasks Done',
                value: 3,
                icon: Icons.check_circle_outline_rounded,
                iconColor: context.colors.success,
                animationDelay: 460.ms,
                compact: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ─── Recent Activity ────────────────────────────
          SectionHeader(
            title: 'Recent Activity',
            actionLabel: 'View All',
            actionIcon: Icons.arrow_forward_rounded,
            onActionTap: () {},
            animationDelay: 600.ms,
          ),

          ..._buildActivityItems(engineState),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<Widget> _buildActivityItems(AttendanceEngineState engineState) {
    final activities = <_ActivityData>[];

    if (engineState.session?.firstClockIn != null) {
      final t = engineState.session!.firstClockIn!;
      activities.add(_ActivityData(
        icon: Icons.login_rounded,
        color: context.colors.success,
        title: 'Clocked in',
        subtitle: 'Today at ${t.hour}:${t.minute.toString().padLeft(2, '0')}',
        status: 'Active',
        statusPreset: StatusPreset.active,
      ));
    }

    if (activities.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Text('No activity today', style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary)),
        ),
      ];
    }

    return activities.asMap().entries.map((e) {
      final i = e.key;
      final a = e.value;
      return Padding(
        padding: EdgeInsets.only(bottom: i < activities.length - 1 ? AppSpacing.md : 0),
        child: _ActivityTile(data: a)
            .animate(delay: Duration(milliseconds: 650 + (i * 60)))
            .fadeIn(duration: 400.ms)
            .slideX(begin: 0.03, end: 0),
      );
    }).toList();
  }
}

// ─── Glass Avatar ─────────────────────────────────────────
class _GlassAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.avatarLg,
      height: AppSpacing.avatarLg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            context.colors.brand.withValues(alpha: 0.3),
            context.colors.brand.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: context.colors.brand.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.brand.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: context.colors.brandLight,
          size: 28,
        ),
      ),
    );
  }
}

// ─── Quick Status Card ────────────────────────────────────
class _QuickStatusCard extends ConsumerWidget {
  const _QuickStatusCard({required this.engineState});
  final AttendanceEngineState engineState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTracking = engineState.isTracking;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isTracking ? context.colors.brand : context.colors.surfaceElevated).withValues(alpha: 0.1),
                (isTracking ? context.colors.brand : context.colors.surfaceElevated).withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: (isTracking ? context.colors.brand : context.colors.glassBorder).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Pulse dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isTracking ? context.colors.success : context.colors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isTracking ? context.colors.success : context.colors.error).withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (c) => isTracking ? c.repeat(reverse: true) : null)
                  .scaleXY(
                    begin: 1,
                    end: 1.3,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTracking ? 'Currently Clocked In' : 'Not Clocked In',
                      style: AppTypography.titleMedium.copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTracking ? 'Auto-tracking via Office WiFi' : 'Connect to Office WiFi to start',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.go(AppRoutes.attendance),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.brand.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'View Timer',
                    style: AppTypography.labelSmall.copyWith(
                      color: context.colors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Activity Tile ────────────────────────────────────────
class _ActivityData {
  const _ActivityData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusPreset,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final StatusPreset statusPreset;
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.data});
  final _ActivityData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: data.color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(
            label: data.status,
            preset: data.statusPreset,
            small: true,
          ),
        ],
      ),
    );
  }
}
