import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Elegant empty state widget with icon, title, and optional action
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.brand.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 36,
                color: context.colors.brand.withValues(alpha: 0.6),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.colors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
