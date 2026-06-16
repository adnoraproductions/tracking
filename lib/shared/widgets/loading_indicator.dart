import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// ADNORA loading indicator with pulsing brand accent
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.message,
    this.color,
  });

  final double size;
  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: color ?? context.colors.brand,
              strokeCap: StrokeCap.round,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1500.ms,
                color: context.colors.brand.withValues(alpha: 0.3),
              ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: TextStyle(
                color: context.colors.textTertiary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-page loading overlay
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.background.withValues(alpha: 0.8),
      child: LoadingIndicator(message: message),
    );
  }
}
