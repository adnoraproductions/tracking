import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Animated glass status badge / chip
class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.small = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? context.colors.brand;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? AppSpacing.sm : AppSpacing.md,
            vertical: small ? 2 : AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: small ? 10 : 12,
                  color: badgeColor,
                ),
                SizedBox(width: small ? 3 : AppSpacing.xs),
              ],
              // Dot indicator
              if (icon == null) ...[
                Container(
                  width: small ? 4 : 6,
                  height: small ? 4 : 6,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: small ? 4 : AppSpacing.sm),
              ],
              Text(
                label,
                style: (small ? AppTypography.caption : AppTypography.labelSmall)
                    .copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
