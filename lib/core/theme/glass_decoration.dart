import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Glass decoration utilities for ADNORA's liquid glass design system
class GlassDecoration {
  const GlassDecoration._();

  /// Standard frosted glass card — subtle in light, frosted in dark
  static BoxDecoration card(
    BuildContext context, {
    double borderRadius = AppSpacing.cardRadius,
    Color? borderColor,
    Color? fillColor,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: fillColor ?? colors.glassFill,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? colors.glassBorder,
        width: colors.isDark ? 0.5 : 0.33,
      ),
      boxShadow: colors.glassShadow,
    );
  }

  /// Liquid glass card — with shimmer gradient edge highlight
  static BoxDecoration liquid(
    BuildContext context, {
    double borderRadius = AppSpacing.cardRadius,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      gradient: colors.liquidShimmer,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.glassBorder,
        width: colors.isDark ? 0.5 : 0.33,
      ),
      boxShadow: colors.glassShadow,
    );
  }

  /// Elevated glass card with stronger presence
  static BoxDecoration elevated(
    BuildContext context, {
    double borderRadius = AppSpacing.cardRadius,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.surfaceElevated.withValues(alpha: colors.isDark ? 0.8 : 0.95),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.glassStroke,
        width: 0.33,
      ),
      boxShadow: colors.elevatedShadow,
    );
  }

  /// Subtle glass surface for nested elements
  static BoxDecoration subtle(
    BuildContext context, {
    double borderRadius = AppSpacing.radiusMd,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.isDark
          ? colors.glassHighlight
          : colors.glassFill.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.glassBorder.withValues(alpha: 0.06),
        width: 0.33,
      ),
    );
  }

  /// iOS grouped section card — solid surface with subtle border
  static BoxDecoration groupedSection(
    BuildContext context, {
    double borderRadius = 12,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      color: colors.surfaceGrouped,
      borderRadius: BorderRadius.circular(borderRadius),
      border: colors.isDark
          ? Border.all(color: colors.glassBorder, width: 0.33)
          : null,
      boxShadow: colors.isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Brand-accented glass decoration
  static BoxDecoration accent(
    BuildContext context, {
    double borderRadius = AppSpacing.cardRadius,
  }) {
    final colors = context.colors;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          colors.brand.withValues(alpha: 0.12),
          colors.brand.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.brand.withValues(alpha: 0.2),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.brand.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Sidebar item decoration
  static BoxDecoration sidebarItem(
    BuildContext context, {
    bool isActive = false,
  }) {
    final colors = context.colors;
    if (!isActive) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      );
    }
    return BoxDecoration(
      color: colors.brand.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(
        color: colors.brand.withValues(alpha: 0.2),
        width: 0.5,
      ),
    );
  }

  /// Blur filters
  static ImageFilter get blurFilter => ImageFilter.blur(
    sigmaX: 24,
    sigmaY: 24,
  );

  static ImageFilter get lightBlurFilter => ImageFilter.blur(
    sigmaX: 12,
    sigmaY: 12,
  );

  static ImageFilter get heavyBlurFilter => ImageFilter.blur(
    sigmaX: 40,
    sigmaY: 40,
  );
}
