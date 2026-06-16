import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// Premium loading state with orbital animation and glass styling
class LoadingState extends StatefulWidget {
  const LoadingState({
    super.key,
    this.message,
    this.compact = false,
    this.overlay = false,
  });

  final String? message;
  final bool compact;
  final bool overlay;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.compact ? 36 : 56,
            height: widget.compact ? 36 : 56,
            child: AnimatedBuilder(
              animation: _orbitController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _OrbitalPainter(
                    progress: _orbitController.value,
                    color: context.colors.brand,
                    compact: widget.compact,
                  ),
                );
              },
            ),
          ),
          if (widget.message != null && !widget.compact) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              widget.message!,
              style: AppTypography.bodySmall.copyWith(
                color: context.colors.textTertiary,
              ),
              textAlign: TextAlign.center,
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms),
          ],
        ],
      ),
    );

    if (widget.overlay) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: context.colors.background.withValues(alpha: 0.7),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

/// Custom orbital loading painter
class _OrbitalPainter extends CustomPainter {
  _OrbitalPainter({
    required this.progress,
    required this.color,
    this.compact = false,
  });

  final double progress;
  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - (compact ? 3 : 4);

    // Track ring
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2 : 2.5;

    canvas.drawCircle(center, radius, trackPaint);

    // Animated arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 2 : 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          color.withValues(alpha: 0.0),
          color,
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2,
      math.pi * 1.2,
      false,
      arcPaint,
    );

    // Orbiting dot
    final dotAngle = progress * math.pi * 2 + math.pi * 1.2;
    final dotOffset = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(dotOffset, compact ? 2.5 : 3.5, dotPaint);

    // Glow on dot
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(dotOffset, compact ? 3 : 5, glowPaint);
  }

  @override
  bool shouldRepaint(_OrbitalPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
