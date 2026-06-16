

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/attendance_engine.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize engine for current user
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await ref.read(attendanceEngineProvider.notifier).initialize(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engineState = ref.watch(attendanceEngineProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.lg,
        left: AppSpacing.pagePaddingH,
        right: AppSpacing.pagePaddingH,
        bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Align(
            alignment: Alignment.centerLeft,
            child: Text('TIME TRACKER', style: AppTypography.caption.copyWith(
              color: context.colors.brand, letterSpacing: 2, fontWeight: FontWeight.w700,
            )).animate().fadeIn(duration: 400.ms),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Attendance', style: AppTypography.displaySmall)
                .animate(delay: 100.ms).fadeIn().slideX(begin: -0.03),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Main Timer Display
          _CircularTimer(engineState: engineState)
              .animate(delay: 200.ms)
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),

          const SizedBox(height: AppSpacing.xxxl),

          // Status Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WifiStatusBadge(isOnWifi: engineState.isOnOfficeWifi, currentSsid: engineState.currentSsid)
                  .animate(delay: 400.ms).fadeIn().slideY(begin: 0.1),
              const SizedBox(width: AppSpacing.md),
              _TrackingStatusBadge(isTracking: engineState.isTracking)
                  .animate(delay: 500.ms).fadeIn().slideY(begin: 0.1),
            ],
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Manual Override (only if needed)
          if (engineState.session?.isActive == true && !engineState.isTracking)
            TextButton.icon(
              onPressed: () {
                ref.read(attendanceEngineProvider.notifier).manualClockOut();
              },
              icon: Icon(Icons.stop_circle_outlined, color: context.colors.error),
              label: Text('Force Clock Out', style: AppTypography.labelLarge.copyWith(color: context.colors.error)),
            ).animate().fadeIn(),
        ],
      ),
    );
  }
}

// ─── Circular Timer ───────────────────────────────────────────
class _CircularTimer extends StatelessWidget {
  const _CircularTimer({required this.engineState});
  final AttendanceEngineState engineState;

  @override
  Widget build(BuildContext context) {
    final isTracking = engineState.isTracking;
    final color = isTracking ? context.colors.brand : context.colors.textDisabled;

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.glassFill,
        border: Border.all(color: context.colors.glassBorder, width: 1),
        boxShadow: [
          if (isTracking)
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 10,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Progress Ring
          if (isTracking)
            SizedBox(
              width: 280,
              height: 280,
              child: CircularProgressIndicator(
                value: null, // Indeterminate spinning
                strokeWidth: 2,
                color: context.colors.brand,
              ),
            ).animate().fadeIn(),
            
          // Inner content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTracking ? Icons.timer_outlined : Icons.timer_off_outlined,
                size: 32,
                color: color,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                engineState.timerText,
                style: AppTypography.displayLarge.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isTracking ? context.colors.textPrimary : context.colors.textSecondary,
                  fontWeight: FontWeight.w300,
                  fontSize: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isTracking ? 'Clocked In' : 'Paused',
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Badges ───────────────────────────────────────────────────
class _WifiStatusBadge extends StatelessWidget {
  const _WifiStatusBadge({required this.isOnWifi, required this.currentSsid});
  final bool isOnWifi;
  final String? currentSsid;

  @override
  Widget build(BuildContext context) {
    final color = isOnWifi ? context.colors.success : context.colors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnWifi ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isOnWifi ? (currentSsid ?? 'Office WiFi') : 'Not on Office WiFi',
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TrackingStatusBadge extends StatelessWidget {
  const _TrackingStatusBadge({required this.isTracking});
  final bool isTracking;

  @override
  Widget build(BuildContext context) {
    final color = isTracking ? context.colors.brand : context.colors.textDisabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTracking ? Icons.bolt_rounded : Icons.pause_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isTracking ? 'Auto-Tracking Active' : 'Auto-Tracking Paused',
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
