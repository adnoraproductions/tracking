import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// ADNORA OS — iOS-Inspired Material Theme
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // iOS-style surfaces
    final background = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final surfaceElevated = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);

    // Text
    final textPrimary = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final textSecondary = isDark ? const Color(0xFF98989F) : const Color(0xFF3C3C43);
    final textTertiary = isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);

    // Glass
    final glassBorder = isDark ? const Color(0x30FFFFFF) : const Color(0x26000000);
    final glassFill = isDark ? const Color(0x2EFFFFFF) : const Color(0xB8FFFFFF);

    // Separator
    final separator = isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,

      // ─── Color Scheme ─────────────────────────────────────
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.brand,
        onPrimary: Colors.white,
        primaryContainer: isDark ? const Color(0xFF3D35B0) : const Color(0xFFE8E5FF),
        onPrimaryContainer: isDark ? AppColors.brandLight : AppColors.brandDark,
        secondary: isDark ? const Color(0xFF64D2FF) : const Color(0xFF32ADE6),
        onSecondary: isDark ? Colors.black : Colors.white,
        secondaryContainer: isDark ? const Color(0xFF1A3A4A) : const Color(0xFFD6EEFF),
        onSecondaryContainer: isDark ? const Color(0xFF64D2FF) : const Color(0xFF1A6B94),
        tertiary: isDark ? const Color(0xFFFF6482) : const Color(0xFFFF2D55),
        onTertiary: Colors.white,
        error: isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: separator,
        outlineVariant: glassBorder,
        shadow: isDark ? Colors.black : const Color(0x1A000000),
      ),

      // ─── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: background,

      // ─── AppBar (iOS Navigation Bar style) ─────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background.withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.brand, size: 22),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),

      // ─── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? glassBorder : Colors.transparent,
            width: 0.33,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button ──────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: separator, width: 0.5),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ─── Text Button ─────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ─── Icon Button ──────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // ─── Input ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? glassFill : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: separator, width: 0.33),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: separator, width: 0.33),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30), width: 1),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: textTertiary),
        labelStyle: AppTypography.bodyMedium.copyWith(color: textPrimary),
        errorStyle: AppTypography.caption.copyWith(
          color: isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
        ),
      ),

      // ─── Chip ─────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? glassFill : const Color(0xFFF2F2F7),
        side: BorderSide(color: separator, width: 0.33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        labelStyle: AppTypography.labelMedium.copyWith(color: textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // ─── Divider ──────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: separator,
        thickness: 0.33,
        space: 0,
      ),

      // ─── Bottom Navigation ────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.85),
        selectedItemColor: AppColors.brand,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
      ),

      // ─── Navigation Rail ──────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.brand),
        unselectedIconTheme: IconThemeData(color: textTertiary),
        indicatorColor: AppColors.brandSubtle,
      ),

      // ─── Dialog ───────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: AppTypography.headlineMedium.copyWith(color: textPrimary),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: textSecondary),
      ),

      // ─── Bottom Sheet ─────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),

      // ─── Snackbar ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF333333),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Tooltip ──────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTypography.caption.copyWith(color: Colors.white),
      ),

      // ─── Popup Menu ───────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: textPrimary),
      ),

      // ─── Tab Bar ──────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.brand,
        labelColor: textPrimary,
        unselectedLabelColor: textTertiary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ─── Progress Indicator ───────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: glassFill,
        circularTrackColor: glassFill,
      ),

      // ─── Switch (iOS style) ───────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
          }
          return isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EB);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return Colors.transparent;
        }),
      ),

      // ─── Text Selection ───────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brand.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.brand,
      ),
    );
  }
}
