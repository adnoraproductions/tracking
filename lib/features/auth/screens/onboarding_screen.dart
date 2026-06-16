import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/glass_button.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.dashboard_rounded,
      title: 'Command Center',
      subtitle:
          'Your entire creative operation at a glance. Track projects, manage teams, and stay on top of deadlines.',
      gradient: [AppColors.brand, Color(0xFF6C63FF)],
    ),
    _OnboardingPageData(
      icon: Icons.schedule_rounded,
      title: 'Smart Attendance',
      subtitle:
          'Clock in with a tap. Automated tracking, break management, and real-time session insights.',
      gradient: [AppColors.cyan, Color(0xFF0891B2)],
    ),
    _OnboardingPageData(
      icon: Icons.rocket_launch_rounded,
      title: 'Ship Faster',
      subtitle:
          'Organize tasks, collaborate with your team, and deliver exceptional creative work — on time, every time.',
      gradient: [AppColors.pink, Color(0xFFDB2777)],
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final repo = ref.read(authRepositoryProvider);
    final user = repo.currentUser;

    if (user != null) {
      // Try to mark onboarding complete
      try {
        await repo.completeOnboarding(user.id);
        // Invalidate profile cache
        ref.invalidate(currentProfileProvider);
      } catch (_) {
        // Proceed even if update fails
      }
    }

    if (mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  void _skip() => _complete();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // ─── Page View ──────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _OnboardingPage(data: page, index: index);
            },
          ),

          // ─── Skip Button ────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.lg,
            right: AppSpacing.xxl,
            child: GlassButton(
              label: 'Skip',
              onPressed: _skip,
              variant: GlassButtonVariant.ghost,
              size: GlassButtonSize.small,
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
          ),

          // ─── Bottom Controls ────────────────────────────
          Positioned(
            bottom: bottomPadding + AppSpacing.xxxl,
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? context.colors.brand
                            : context.colors.textDisabled,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                    onPressed: _next,
                    variant: GlassButtonVariant.primary,
                    size: GlassButtonSize.large,
                    icon: _currentPage == _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : null,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ),
        ],
      ),
    );
  }
}

// ─── Page Data ────────────────────────────────────────────
class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
}

// ─── Single Page Widget ───────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.index});

  final _OnboardingPageData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Icon orb
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.gradient[0].withValues(alpha: 0.2),
                  data.gradient[0].withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(
                color: data.gradient[0].withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient[0].withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          )
              .animate(delay: Duration(milliseconds: 100 * index))
              .fadeIn(duration: 600.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: AppSpacing.huge),

          // Title
          Text(
            data.title,
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),

          const SizedBox(height: AppSpacing.lg),

          // Subtitle
          Text(
            data.subtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: context.colors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate(delay: 350.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.1, end: 0, duration: 500.ms),

          const SizedBox(height: 120), // Space for bottom controls
        ],
      ),
    );
  }
}
