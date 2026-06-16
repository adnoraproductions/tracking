import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Compact status pill with dot indicator and preset color mappings
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color,
    this.preset,
    this.small = false,
    this.outlined = false,
  }) : assert(color != null || preset != null);

  final String label;
  final Color? color;
  final StatusPreset? preset;
  final bool small;
  final bool outlined;

  Color get _resolvedColor {
    if (color != null) return color!;
    return switch (preset!) {
      StatusPreset.active => AppColors.success,
      StatusPreset.inactive => AppColors.textDisabled,
      StatusPreset.pending => AppColors.warning,
      StatusPreset.completed => AppColors.brand,
      StatusPreset.error => AppColors.error,
      StatusPreset.info => AppColors.info,
      StatusPreset.inProgress => AppColors.cyan,
      StatusPreset.onHold => AppColors.amber,
      StatusPreset.archived => AppColors.textTertiary,
      StatusPreset.urgent => AppColors.error,
      StatusPreset.review => AppColors.pink,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _resolvedColor;
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 8.0 : 10.0;
    final vPad = small ? 2.0 : 4.0;
    final dotSize = small ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: c.withValues(alpha: outlined ? 0.4 : 0.2),
          width: outlined ? 1 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          SizedBox(width: small ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: c,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Preset status colors
enum StatusPreset {
  active,
  inactive,
  pending,
  completed,
  error,
  info,
  inProgress,
  onHold,
  archived,
  urgent,
  review,
}
