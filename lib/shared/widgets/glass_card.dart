import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/glass_decoration.dart';

/// Premium liquid glass card with backdrop blur and shimmer edge
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.hasEntranceAnimation = false,
    this.animationDelay = Duration.zero,
    this.fillColor,
    this.borderColor,
    this.blur,
    this.width,
    this.height,
    this.constraints,
    this.useLiquidEffect = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool hasEntranceAnimation;
  final Duration animationDelay;
  final Color? fillColor;
  final Color? borderColor;
  final double? blur;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final bool useLiquidEffect;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 16.0;
    final isDark = context.colors.isDark;
    final blurAmount = blur ?? (isDark ? 28.0 : 16.0);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          width: width,
          height: height,
          constraints: constraints,
          decoration: useLiquidEffect
              ? GlassDecoration.liquid(context, borderRadius: radius)
              : GlassDecoration.card(
                  context,
                  borderRadius: radius,
                  fillColor: fillColor,
                  borderColor: borderColor,
                ),
          padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
          margin: margin,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = _TapWrapper(onTap: onTap!, child: card);
    }

    if (hasEntranceAnimation) {
      card = card
          .animate(delay: animationDelay)
          .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
          .slideY(
            begin: 0.03,
            end: 0,
            duration: 450.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return card;
  }
}

/// Interactive tap wrapper with scale animation
class _TapWrapper extends StatefulWidget {
  const _TapWrapper({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapWrapper> createState() => _TapWrapperState();
}

class _TapWrapperState extends State<_TapWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
