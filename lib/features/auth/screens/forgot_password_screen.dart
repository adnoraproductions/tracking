import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_text_field.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _resetSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).resetPassword(
          _emailController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthPasswordResetSent) {
        setState(() => _resetSent = true);
      }
      if (next is AuthError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: context.colors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // ─── Ambient Orb ──────────────────────────────
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.brand.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 0.8,
                  end: 1.2,
                  duration: 4000.ms,
                  curve: Curves.easeInOut,
                ),
          ),

          // ─── Content ──────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _resetSent
                      ? _buildSuccessState()
                      : _buildFormState(isLoading),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        GlassButton(
          label: 'Back',
          onPressed: () => context.pop(),
          variant: GlassButtonVariant.ghost,
          size: GlassButtonSize.small,
          icon: Icons.arrow_back_ios_rounded,
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: AppSpacing.xxxl),

        // Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.colors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: context.colors.brand.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.lock_reset_rounded,
            color: context.colors.brand,
            size: 28,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: AppSpacing.xxl),

        Text(
          'Reset password',
          style: AppTypography.displaySmall,
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.sm),

        Text(
          'Enter your email and we\'ll send you a link to reset your password.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.colors.textTertiary,
            height: 1.5,
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.xxxl),

        // Glass form card
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: context.colors.glassFill,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                border: Border.all(
                  color: context.colors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassTextField(
                      controller: _emailController,
                      label: 'Email address',
                      hint: 'you@adnora.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onSubmitted: (_) => _handleReset(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    GlassButton(
                      label: 'Send Reset Link',
                      onPressed: isLoading ? null : _handleReset,
                      isLoading: isLoading,
                      variant: GlassButtonVariant.primary,
                      size: GlassButtonSize.large,
                      width: double.infinity,
                      icon: Icons.send_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideY(
              begin: 0.05,
              end: 0,
              duration: 500.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated check mark
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                context.colors.success.withValues(alpha: 0.15),
                context.colors.success.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(
              color: context.colors.success.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            color: context.colors.success,
            size: 48,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: AppSpacing.xxxl),

        Text(
          'Check your email',
          style: AppTypography.displaySmall,
          textAlign: TextAlign.center,
        ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.md),

        Text(
          'We\'ve sent a password reset link to\n${_emailController.text.trim()}',
          style: AppTypography.bodyMedium.copyWith(
            color: context.colors.textTertiary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.xxxl),

        GlassButton(
          label: 'Back to Sign In',
          onPressed: () => context.pop(),
          variant: GlassButtonVariant.secondary,
          size: GlassButtonSize.large,
          icon: Icons.arrow_back_rounded,
        ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}
