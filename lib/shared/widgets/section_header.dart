import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Reusable section header with title, subtitle, overline, and optional trailing action
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.trailing,
    this.onActionTap,
    this.actionLabel,
    this.actionIcon,
    this.bottomPadding = AppSpacing.lg,
    this.animate = true,
    this.animationDelay = Duration.zero,
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? trailing;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final double bottomPadding;
  final bool animate;
  final Duration animationDelay;

  @override
  Widget build(BuildContext context) {
    Widget header = Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: context.colors.brand,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(title, style: AppTypography.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onActionTap != null && actionLabel != null) ...[
            const SizedBox(width: AppSpacing.md),
            _SectionAction(
              label: actionLabel!,
              icon: actionIcon,
              onTap: onActionTap!,
            ),
          ],
        ],
      ),
    );

    if (animate) {
      header = header
          .animate(delay: animationDelay)
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideX(begin: -0.02, end: 0, duration: 400.ms);
    }

    return header;
  }
}

class _SectionAction extends StatefulWidget {
  const _SectionAction({
    required this.label,
    this.icon,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_SectionAction> createState() => _SectionActionState();
}

class _SectionActionState extends State<_SectionAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? context.colors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? context.colors.brand.withValues(alpha: 0.3)
                  : context.colors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: AppTypography.labelSmall.copyWith(
                  color: _isHovered ? context.colors.brand : context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 4),
                Icon(
                  widget.icon,
                  size: 14,
                  color: _isHovered ? context.colors.brand : context.colors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
