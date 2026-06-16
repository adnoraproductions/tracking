import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/constants/app_colors.dart';

/// macOS-style floating dock with glass backdrop, spring hover, and active indicator
class FloatingDock extends StatelessWidget {
  const FloatingDock({
    super.key,
    required this.items,
    this.currentIndex = 0,
    this.onItemTap,
  });

  final List<FloatingDockItem> items;
  final int currentIndex;
  final ValueChanged<int>? onItemTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: context.colors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: context.colors.brand.withValues(alpha: 0.05),
                blurRadius: 40,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              return _DockIcon(
                item: items[i],
                isActive: i == currentIndex,
                onTap: () => onItemTap?.call(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class FloatingDockItem {
  const FloatingDockItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
  });

  final IconData icon;
  final String label;
  final IconData? activeIcon;
  final int? badge;
}

class _DockIcon extends StatefulWidget {
  const _DockIcon({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final FloatingDockItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleAnim = const AlwaysStoppedAnimation(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    setState(() => _isHovered = true);
    const spring = SpringDescription(mass: 1, stiffness: 500, damping: 16);
    _scaleAnim = _controller.drive(Tween(begin: 1.0, end: 1.18));
    _controller.animateWith(SpringSimulation(spring, 0, 1, 0));
  }

  void _onHoverExit() {
    setState(() => _isHovered = false);
    const spring = SpringDescription(mass: 1, stiffness: 500, damping: 16);
    _scaleAnim = _controller.drive(Tween(begin: 1.18, end: 1.0));
    _controller.animateWith(SpringSimulation(spring, 0, 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isActive
        ? (widget.item.activeIcon ?? widget.item.icon)
        : widget.item.icon;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.item.label,
          preferBelow: false,
          verticalOffset: 30,
          decoration: BoxDecoration(
            color: context.colors.surfaceOverlay,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.glassBorder, width: 0.5),
          ),
          textStyle: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              );
            },
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? context.colors.brand.withValues(alpha: 0.15)
                    : _isHovered
                        ? context.colors.glassFill
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: widget.isActive
                    ? Border.all(
                        color: context.colors.brand.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: widget.isActive
                        ? context.colors.brand
                        : _isHovered
                            ? context.colors.textPrimary
                            : context.colors.textTertiary,
                  ),

                  // Badge
                  if (widget.item.badge != null && widget.item.badge! > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.item.badge! > 9
                                ? '9+'
                                : widget.item.badge.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Active dot indicator
                  if (widget.isActive)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.colors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
