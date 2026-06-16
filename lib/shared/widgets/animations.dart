
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Reusable fade-slide transition wrapper with configurable direction and spring physics
class FadeSlideTransition extends StatelessWidget {
  const FadeSlideTransition({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 0.04),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: curve)
        .slide(begin: offset, end: Offset.zero, duration: duration, curve: curve);
  }
}

/// Scale-on-tap wrapper using spring physics
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.95,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;
  final bool enabled;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap>
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

  void _down() {
    if (!widget.enabled) return;
    _scale = _ctrl.drive(Tween(begin: 1.0, end: widget.scaleDown));
    _ctrl.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 600, damping: 18),
      0, 1, 0,
    ));
  }

  void _up() {
    if (!widget.enabled) return;
    _scale = _ctrl.drive(Tween(begin: widget.scaleDown, end: 1.0));
    _ctrl.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 400, damping: 15),
      0, 1, 0,
    ));
    widget.onTap();
  }

  void _cancel() {
    if (!widget.enabled) return;
    _scale = _ctrl.drive(Tween(begin: widget.scaleDown, end: 1.0));
    _ctrl.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 400, damping: 15),
      0, 1, 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Smooth animated counter that tweens between values
class SmoothCounter extends StatelessWidget {
  const SmoothCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutExpo,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
  });

  final double value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) {
        final formatted = fractionDigits > 0
            ? v.toStringAsFixed(fractionDigits)
            : v.toInt().toString();
        return Text(
          '$prefix$formatted$suffix',
          style: style ?? AppTypography.displaySmall,
        );
      },
    );
  }
}

/// Staggered list animation wrapper
class StaggeredList extends StatelessWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.initialDelay = Duration.zero,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.spacing = AppSpacing.md,
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration initialDelay;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i]
              .animate(delay: initialDelay + staggerDelay * i)
              .fadeIn(duration: 400.ms, curve: Curves.easeOut)
              .slideY(
                begin: 0.04,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              ),
        ],
      ],
    );
  }
}
