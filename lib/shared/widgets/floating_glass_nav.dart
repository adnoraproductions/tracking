import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

class FloatingGlassNav extends StatelessWidget {
  const FloatingGlassNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: bottomPad > 0 ? bottomPad + 8 : AppSpacing.xl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.isDark 
                  ? const Color(0x3AFFFFFF) // Slightly stronger white frosted in dark mode
                  : const Color(0xB8FFFFFF), // Clean white frosted in light mode
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colors.glassBorder,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final isActive = i == currentIndex;
                final item = items[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    child: _NavItemWidget(item: item, isActive: isActive),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItemWidget extends StatelessWidget {
  const _NavItemWidget({required this.item, required this.isActive});
  final FloatingNavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? colors.brand.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? colors.brand : colors.textSecondary,
            size: 24,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? colors.brand : colors.textTertiary,
            fontFamily: 'Inter',
          ),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
