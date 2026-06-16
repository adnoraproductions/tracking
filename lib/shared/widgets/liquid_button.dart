import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Apple-inspired liquid button with spring physics, shimmer, and glow
class LiquidButton extends StatefulWidget {
  const LiquidButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = LiquidButtonVariant.primary,
    this.size = LiquidButtonSize.medium,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LiquidButtonVariant variant;
  final LiquidButtonSize size;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final bool expanded;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this);
    _scaleAnimation = const AlwaysStoppedAnimation(1.0);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    const spring = SpringDescription(mass: 1, stiffness: 600, damping: 18);
    final simulation = SpringSimulation(spring, 1.0, 0.94, 0);
    _scaleAnimation = _scaleController.drive(
      Tween<double>(begin: 1.0, end: 0.94),
    );
    _scaleController.animateWith(simulation);
  }

  void _onTapUp(TapUpDetails _) {
    _springBack();
    if (widget.enabled && !widget.isLoading) widget.onPressed?.call();
  }

  void _onTapCancel() => _springBack();

  void _springBack() {
    const spring = SpringDescription(mass: 1, stiffness: 400, damping: 15);
    final simulation = SpringSimulation(spring, _scaleController.value, 0, 0);
    _scaleAnimation = _scaleController.drive(
      Tween<double>(begin: 0.94, end: 1.0),
    );
    _scaleController.animateWith(simulation);
  }

  // ─── Variant Styling ──────────────────────────────────────
  _LiquidStyle get _style {
    final disabled = !widget.enabled || widget.isLoading;
    return switch (widget.variant) {
      LiquidButtonVariant.primary => _LiquidStyle(
          gradient: disabled
              ? [context.colors.brand.withValues(alpha: 0.3), context.colors.brandDark.withValues(alpha: 0.3)]
              : [context.colors.brand, context.colors.brandDark],
          foreground: Colors.white.withValues(alpha: disabled ? 0.5 : 1.0),
          glow: context.colors.brand.withValues(alpha: disabled ? 0 : 0.35),
          border: context.colors.brandLight.withValues(alpha: disabled ? 0.05 : 0.15),
        ),
      LiquidButtonVariant.secondary => _LiquidStyle(
          gradient: [context.colors.glassFill, context.colors.glassHighlight],
          foreground: context.colors.textPrimary.withValues(alpha: disabled ? 0.4 : 1.0),
          glow: Colors.transparent,
          border: context.colors.glassBorder,
        ),
      LiquidButtonVariant.ghost => _LiquidStyle(
          gradient: [Colors.transparent, Colors.transparent],
          foreground: context.colors.textSecondary.withValues(alpha: disabled ? 0.4 : 1.0),
          glow: Colors.transparent,
          border: Colors.transparent,
        ),
      LiquidButtonVariant.danger => _LiquidStyle(
          gradient: [context.colors.error.withValues(alpha: 0.15), context.colors.error.withValues(alpha: 0.08)],
          foreground: context.colors.error.withValues(alpha: disabled ? 0.4 : 1.0),
          glow: context.colors.error.withValues(alpha: disabled ? 0 : 0.15),
          border: context.colors.error.withValues(alpha: 0.25),
        ),
      LiquidButtonVariant.success => _LiquidStyle(
          gradient: [context.colors.success.withValues(alpha: 0.15), context.colors.success.withValues(alpha: 0.08)],
          foreground: context.colors.success.withValues(alpha: disabled ? 0.4 : 1.0),
          glow: context.colors.success.withValues(alpha: disabled ? 0 : 0.15),
          border: context.colors.success.withValues(alpha: 0.25),
        ),
    };
  }

  double get _verticalPad => switch (widget.size) {
    LiquidButtonSize.small => 10,
    LiquidButtonSize.medium => 14,
    LiquidButtonSize.large => 18,
  };

  double get _horizontalPad => switch (widget.size) {
    LiquidButtonSize.small => 16,
    LiquidButtonSize.medium => 24,
    LiquidButtonSize.large => 32,
  };

  TextStyle get _textStyle => switch (widget.size) {
    LiquidButtonSize.small => AppTypography.labelMedium,
    LiquidButtonSize.medium => AppTypography.labelLarge,
    LiquidButtonSize.large => AppTypography.titleMedium,
  };

  double get _iconSize => switch (widget.size) {
    LiquidButtonSize.small => 14,
    LiquidButtonSize.medium => 18,
    LiquidButtonSize.large => 20,
  };

  double get _radius => switch (widget.size) {
    LiquidButtonSize.small => 12,
    LiquidButtonSize.medium => 16,
    LiquidButtonSize.large => 20,
  };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final disabled = !widget.enabled || widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: disabled ? null : _onTapDown,
        onTapUp: disabled ? null : _onTapUp,
        onTapCancel: disabled ? null : _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            final scale = _scaleAnimation.value;
            return Transform.scale(scale: scale, child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.expanded ? double.infinity : widget.width,
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPad,
              vertical: _verticalPad,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered && !disabled
                    ? style.gradient.map((c) => Color.lerp(c, Colors.white, 0.07)!).toList()
                    : style.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: style.border, width: 1),
              boxShadow: [
                if (style.glow != Colors.transparent)
                  BoxShadow(
                    color: _isHovered ? style.glow.withValues(alpha: 0.5) : style.glow,
                    blurRadius: _isHovered ? 28 : 18,
                    spreadRadius: _isHovered ? 2 : 0,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer overlay for primary
                if (widget.variant == LiquidButtonVariant.primary && !disabled)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_radius),
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) {
                          return ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: const [
                                  Colors.transparent,
                                  Color(0x18FFFFFF),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                                begin: Alignment(-2 + 4 * _shimmerController.value, 0),
                                end: Alignment(-1 + 4 * _shimmerController.value, 0),
                              ).createShader(bounds);
                            },
                            child: Container(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),

                // Content row
                Row(
                  mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: _iconSize,
                        height: _iconSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: style.foreground,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (widget.icon != null) ...[
                      Icon(widget.icon, size: _iconSize, color: style.foreground),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        style: _textStyle.copyWith(
                          color: style.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting Types ─────────────────────────────────────
enum LiquidButtonVariant { primary, secondary, ghost, danger, success }

enum LiquidButtonSize { small, medium, large }

class _LiquidStyle {
  const _LiquidStyle({
    required this.gradient,
    required this.foreground,
    required this.glow,
    required this.border,
  });
  final List<Color> gradient;
  final Color foreground;
  final Color glow;
  final Color border;
}
