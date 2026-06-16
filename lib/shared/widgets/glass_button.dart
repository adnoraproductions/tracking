import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Premium glass-styled button with shimmer hover effect
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = GlassButtonVariant.primary,
    this.size = GlassButtonSize.medium,
    this.width,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final double? width;
  final bool enabled;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _verticalPadding {
    return switch (widget.size) {
      GlassButtonSize.small => AppSpacing.sm,
      GlassButtonSize.medium => AppSpacing.md + 2,
      GlassButtonSize.large => AppSpacing.lg,
    };
  }

  double get _horizontalPadding {
    return switch (widget.size) {
      GlassButtonSize.small => AppSpacing.lg,
      GlassButtonSize.medium => AppSpacing.xxl,
      GlassButtonSize.large => AppSpacing.xxxl,
    };
  }

  TextStyle get _textStyle {
    return switch (widget.size) {
      GlassButtonSize.small => AppTypography.labelMedium,
      GlassButtonSize.medium => AppTypography.labelLarge,
      GlassButtonSize.large => AppTypography.titleMedium,
    };
  }

  double get _iconSize {
    return switch (widget.size) {
      GlassButtonSize.small => 14,
      GlassButtonSize.medium => 18,
      GlassButtonSize.large => 20,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.enabled || widget.isLoading;

    Color bgColor;
    Color fgColor;
    Color borderColor;

    switch (widget.variant) {
      case GlassButtonVariant.primary:
        bgColor = context.colors.brand;
        fgColor = Colors.white;
        borderColor = context.colors.brand.withValues(alpha: 0.3);
      case GlassButtonVariant.secondary:
        bgColor = context.colors.glassFill;
        fgColor = context.colors.textPrimary;
        borderColor = context.colors.glassBorder;
      case GlassButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = context.colors.textSecondary;
        borderColor = Colors.transparent;
      case GlassButtonVariant.danger:
        bgColor = context.colors.error.withValues(alpha: 0.15);
        fgColor = context.colors.error;
        borderColor = context.colors.error.withValues(alpha: 0.3);
      case GlassButtonVariant.success:
        bgColor = context.colors.success.withValues(alpha: 0.15);
        fgColor = context.colors.success;
        borderColor = context.colors.success.withValues(alpha: 0.3);
    }

    if (isDisabled) {
      bgColor = bgColor.withValues(alpha: 0.4);
      fgColor = fgColor.withValues(alpha: 0.4);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: isDisabled
            ? null
            : (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: widget.width,
          transform: Matrix4.diagonal3Values(_isPressed ? 0.97 : 1.0, _isPressed ? 0.97 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          decoration: BoxDecoration(
            color: _isHovered && !isDisabled
                ? Color.lerp(bgColor, Colors.white, 0.08)
                : bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: widget.variant == GlassButtonVariant.primary && !isDisabled
                ? [
                    BoxShadow(
                      color: context.colors.brand.withValues(alpha: _isHovered ? 0.3 : 0.15),
                      blurRadius: _isHovered ? 20 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: _iconSize,
                  height: _iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: _iconSize, color: fgColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.label,
                style: _textStyle.copyWith(color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum GlassButtonVariant { primary, secondary, ghost, danger, success }

enum GlassButtonSize { small, medium, large }
