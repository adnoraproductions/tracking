import 'package:flutter/material.dart';

extension AppColorsExtension on BuildContext {
  AppColorsData get colors => AppColorsData(this);
}

class AppColorsData {
  AppColorsData(this.context);
  final BuildContext context;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ─── Brand ──────────────────────────────────────────────
  Color get brand => AppColors.brand;
  Color get brandLight => AppColors.brandLight;
  Color get brandDark => AppColors.brandDark;
  Color get brandSubtle => isDark ? const Color(0x336A5BFF) : const Color(0x1A6A5BFF);

  // ─── Surfaces (iOS-style) ───────────────────────────────
  Color get background => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get surfaceElevated => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get surfaceOverlay => isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
  Color get surfaceGrouped => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  // ─── Glass (Liquid Glass) ───────────────────────────────
  Color get glassFill => isDark
      ? const Color(0x2EFFFFFF)  // 18% white
      : const Color(0xB8FFFFFF); // 72% white — clean frosted
  Color get glassBorder => isDark
      ? const Color(0x30FFFFFF)  // 19% white edge
      : const Color(0x26000000); // 15% black hairline
  Color get glassHighlight => isDark
      ? const Color(0x14FFFFFF)
      : const Color(0x0AFFFFFF); // inner shimmer
  Color get glassStroke => isDark
      ? const Color(0x3CFFFFFF)
      : const Color(0x1A000000);

  // ─── Text ───────────────────────────────────────────────
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get textSecondary => isDark ? const Color(0xFF98989F) : const Color(0xFF3C3C43);
  Color get textTertiary => isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);
  Color get textDisabled => isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);

  // ─── Separator (iOS style) ──────────────────────────────
  Color get separator => isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
  Color get separatorOpaque => isDark ? const Color(0xFF545456) : const Color(0xFFD1D1D6);

  // ─── Semantic ───────────────────────────────────────────
  Color get success => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get warning => isDark ? const Color(0xFFFFD60A) : const Color(0xFFFF9F0A);
  Color get error => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  Color get info => isDark ? const Color(0xFF64D2FF) : const Color(0xFF007AFF);

  // ─── Accents (iOS palette) ──────────────────────────────
  Color get cyan => isDark ? const Color(0xFF64D2FF) : const Color(0xFF32ADE6);
  Color get pink => isDark ? const Color(0xFFFF6482) : const Color(0xFFFF2D55);
  Color get amber => isDark ? const Color(0xFFFFD60A) : const Color(0xFFFF9F0A);
  Color get emerald => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get indigo => isDark ? const Color(0xFF7D7AFF) : const Color(0xFF5856D6);
  Color get teal => isDark ? const Color(0xFF6AC4DC) : const Color(0xFF5AC8FA);

  // ─── Gradients ──────────────────────────────────────────
  LinearGradient get brandGradient => const LinearGradient(
        colors: [Color(0xFF6A5BFF), Color(0xFF8B7FFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get surfaceGradient => LinearGradient(
        colors: isDark
            ? const [Color(0x0CFFFFFF), Color(0x04FFFFFF)]
            : const [Color(0x0A000000), Color(0x02000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Liquid glass shimmer — edge highlight that gives the "liquid" feel
  LinearGradient get liquidShimmer => LinearGradient(
        colors: isDark
            ? const [Color(0x20FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF)]
            : const [Color(0x40FFFFFF), Color(0x18FFFFFF), Color(0x00FFFFFF)],
        stops: const [0.0, 0.4, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get shimmerGradient => LinearGradient(
        colors: isDark
            ? const [Color(0x00FFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)]
            : const [Color(0x00000000), Color(0x08000000), Color(0x00000000)],
        stops: const [0.0, 0.5, 1.0],
        begin: const Alignment(-1.0, -0.3),
        end: const Alignment(1.0, 0.3),
      );

  // ─── Shadows (subtle for iOS) ──────────────────────────
  List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}

/// ADNORA OS Core Color Palette — Static constants for non-context usage
abstract final class AppColors {
  // ─── Brand ──────────────────────────────────────────────
  static const Color brand = Color(0xFF6A5BFF);
  static const Color brandLight = Color(0xFFA49BFF);
  static const Color brandDark = Color(0xFF4A3FCC);
  static const Color brandSubtle = Color(0x336A5BFF);

  // ─── Default surfaces (dark mode — used in shell/static contexts) ──
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color surfaceOverlay = Color(0xFF3A3A3C);

  // ─── Glass ──────────────────────────────────────────────
  static const Color glassFill = Color(0x2EFFFFFF);
  static const Color glassBorder = Color(0x30FFFFFF);
  static const Color glassHighlight = Color(0x14FFFFFF);
  static const Color glassStroke = Color(0x3CFFFFFF);

  // ─── Text ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF98989F);
  static const Color textTertiary = Color(0xFF636366);
  static const Color textDisabled = Color(0xFF48484A);

  // ─── Semantic ───────────────────────────────────────────
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFFD60A);
  static const Color error = Color(0xFFFF453A);
  static const Color info = Color(0xFF64D2FF);

  // ─── Accents ────────────────────────────────────────────
  static const Color cyan = Color(0xFF64D2FF);
  static const Color pink = Color(0xFFFF6482);
  static const Color amber = Color(0xFFFFD60A);
  static const Color emerald = Color(0xFF30D158);

  // ─── Gradients ──────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF6A5BFF), Color(0xFF8B7FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0x0CFFFFFF), Color(0x04FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x14FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // ─── Shadows ────────────────────────────────────────────
  static List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
