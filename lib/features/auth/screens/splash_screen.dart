import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/adnora_logo.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Allow logo animation to play, then resolve routing
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _animationComplete = true);
        _resolveRoute();
      }
    });
  }

  Future<void> _resolveRoute() async {
    if (!mounted) return;

    final repo = ref.read(authRepositoryProvider);

    // Not authenticated → login
    if (!repo.isAuthenticated) {
      if (mounted) context.go(AppRoutes.login);
      return;
    }

    final userId = repo.currentUser!.id;

    // Fetch profile for role & onboarding check
    final profile = await repo.fetchProfile(userId);

    if (!mounted) return;

    // No profile yet → onboarding
    if (profile == null) {
      context.go(AppRoutes.onboarding);
      return;
    }

    // Onboarding not completed → onboarding
    if (!profile.onboardingComplete) {
      context.go(AppRoutes.onboarding);
      return;
    }

    // Route based on role
    context.go(AppRoutes.dashboard);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // ─── Ambient glow ───────────────────────────────
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.brand.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 0.8,
                  end: 1.2,
                  duration: 3000.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.cyan.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1.2,
                  end: 0.8,
                  duration: 3500.ms,
                  curve: Curves.easeInOut,
                ),
          ),

          // ─── Content ───────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AdnoraLogo(
                  size: AdnoraLogoSize.hero,
                  showTagline: false,
                  showText: false,
                )
                    .animate()
                    .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: AppSpacing.huge),
                if (_animationComplete)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.brand.withValues(alpha: 0.5),
                      strokeCap: StrokeCap.round,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
              ],
            ),
          ),

          // ─── Version ───────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
            left: 0,
            right: 0,
            child: Text(
              'v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textDisabled,
                letterSpacing: 1,
              ),
            ).animate(delay: 600.ms).fadeIn(duration: 500.ms),
          ),
        ],
      ),
    );
  }
}
