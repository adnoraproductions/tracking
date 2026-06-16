import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Animated stat card with smooth counter, trend indicator, and glass styling
class AnimatedStatCard extends StatefulWidget {
  const AnimatedStatCard({
    super.key,
    required this.label,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.icon,
    this.iconColor,
    this.trend,
    this.trendLabel,
    this.animationDelay = Duration.zero,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final double value;
  final String prefix;
  final String suffix;
  final IconData? icon;
  final Color? iconColor;

  /// Positive = up trend, negative = down trend, null = no trend
  final double? trend;
  final String? trendLabel;
  final Duration animationDelay;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countController;
  late Animation<double> _countAnimation;
  double _prevValue = 0;

  @override
  void initState() {
    super.initState();
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _countAnimation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(
        parent: _countController,
        curve: Curves.easeOutExpo,
      ),
    );

    Future.delayed(widget.animationDelay, () {
      if (mounted) _countController.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _prevValue = oldWidget.value;
      _countAnimation = Tween<double>(
        begin: _prevValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _countController,
        curve: Curves.easeOutExpo,
      ));
      _countController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? context.colors.brand;

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(widget.compact ? 16 : AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: context.colors.glassFill,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: context.colors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: icon + label
              Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      width: widget.compact ? 32 : 40,
                      height: widget.compact ? 32 : 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          widget.compact ? 8 : 12,
                        ),
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.compact ? 16 : 20,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(width: widget.compact ? 8 : 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      style: (widget.compact
                              ? AppTypography.labelSmall
                              : AppTypography.labelMedium)
                          .copyWith(
                        color: context.colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              SizedBox(height: widget.compact ? 12 : 16),

              // Animated value
              AnimatedBuilder(
                animation: _countAnimation,
                builder: (context, _) {
                  return Text(
                    '${widget.prefix}${_formatValue(_countAnimation.value)}${widget.suffix}',
                    style: (widget.compact
                            ? AppTypography.headlineMedium
                            : AppTypography.displaySmall)
                        .copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),

              // Trend
              if (widget.trend != null) ...[
                const SizedBox(height: 8),
                _TrendIndicator(
                  value: widget.trend!,
                  label: widget.trendLabel,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      card = _SpringTap(onTap: widget.onTap!, child: card);
    }

    return card
        .animate(delay: widget.animationDelay)
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }
}

// ─── Trend Indicator ──────────────────────────────────────
class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.value, this.label});
  final double value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? context.colors.success : context.colors.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label!,
            style: AppTypography.caption.copyWith(
              color: context.colors.textDisabled,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Spring Tap Wrapper ───────────────────────────────────
class _SpringTap extends StatefulWidget {
  const _SpringTap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_SpringTap> createState() => _SpringTapState();
}

class _SpringTapState extends State<_SpringTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _scale = const AlwaysStoppedAnimation(1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _scale = _ctrl.drive(Tween(begin: 1.0, end: 0.96));
        _ctrl.animateWith(SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 600, damping: 18),
          0, 1, 0,
        ));
      },
      onTapUp: (_) {
        _scale = _ctrl.drive(Tween(begin: 0.96, end: 1.0));
        _ctrl.animateWith(SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 400, damping: 15),
          0, 1, 0,
        ));
        widget.onTap();
      },
      onTapCancel: () {
        _scale = _ctrl.drive(Tween(begin: 0.96, end: 1.0));
        _ctrl.animateWith(SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 400, damping: 15),
          0, 1, 0,
        ));
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
