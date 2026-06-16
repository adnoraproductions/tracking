import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

/// iOS-style frosted glass app bar with large title support
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.showBackButton = false,
    this.blur = 20,
    this.height = AppSpacing.appBarHeight,
    this.largeTitle = false,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final double blur;
  final double height;
  final bool largeTitle;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topPad = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + topPad,
          padding: EdgeInsets.only(top: topPad),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: colors.isDark ? 0.75 : 0.85),
            border: Border(
              bottom: BorderSide(
                color: colors.separator.withValues(alpha: 0.3),
                width: 0.33,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 18,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Back',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (leading != null)
                  leading!,
                if (leading != null || showBackButton)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: titleWidget ??
                      Text(
                        title ?? '',
                        style: largeTitle
                            ? AppTypography.displaySmall.copyWith(
                                color: colors.textPrimary,
                              )
                            : AppTypography.headlineSmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: largeTitle ? TextAlign.left : TextAlign.center,
                      ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
