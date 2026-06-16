import 'package:flutter/material.dart';

extension AppColorsExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ─── Brand ──────────────────────────────────────────────
  Color get brand => const Color(0xFF6A5BFF);
  Color get brandLight => const Color(0xFFA49BFF);
  Color get brandDark => const Color(0xFF4A3FCC);
  Color get brandSubtle => const Color(0x336A5BFF);

  // ─── Surfaces ───────────────────────────────────────────
  Color get background => isDark ? const Color(0xFF05070A) : const Color(0xFFF9FAFB);
  Color get surface => isDark ? const Color(0xFF0B0F14) : const Color(0xFFFFFFFF);
  Color get surfaceElevated => isDark ? const Color(0xFF111820) : const Color(0xFFF3F4F6);
  Color get surfaceOverlay => isDark ? const Color(0xFF1A2230) : const Color(0xFFE5E7EB);

  // ─── Glass ──────────────────────────────────────────────
  Color get glassFill => isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000);
  Color get glassBorder => isDark ? const Color(0x28FFFFFF) : const Color(0x1F000000);
  Color get glassHighlight => isDark ? const Color(0x0FFFFFFF) : const Color(0x05000000);
  Color get glassStroke => isDark ? const Color(0x33FFFFFF) : const Color(0x26000000);

  // ─── Text ───────────────────────────────────────────────
  Color get textPrimary => isDark ? const Color(0xFFF5F5F7) : const Color(0xFF111827);
  Color get textSecondary => isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);
  Color get textTertiary => isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
  Color get textDisabled => isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);

  // ─── Semantic ───────────────────────────────────────────
  Color get success => const Color(0xFF34D399);
  Color get warning => const Color(0xFFFBBF24);
  Color get error => const Color(0xFFF87171);
  Color get info => const Color(0xFF60A5FA);

  // ─── Accents ────────────────────────────────────────────
  Color get cyan => const Color(0xFF22D3EE);
  Color get pink => const Color(0xFFF472B6);
  Color get amber => const Color(0xFFFBBF24);
  Color get emerald => const Color(0xFF34D399);

  // ─── Gradients ──────────────────────────────────────────
  LinearGradient get brandGradient => const LinearGradient(
        colors: [Color(0xFF6A5BFF), Color(0xFF8B7FFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get surfaceGradient => LinearGradient(
        colors: isDark 
            ? const [Color(0x14FFFFFF), Color(0x08FFFFFF)]
            : const [Color(0x08000000), Color(0x02000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get shimmerGradient => LinearGradient(
        colors: isDark
            ? const [Color(0x00FFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)]
            : const [Color(0x00000000), Color(0x0A000000), Color(0x00000000)],
        stops: const [0.0, 0.5, 1.0],
        begin: const Alignment(-1.0, -0.3),
        end: const Alignment(1.0, 0.3),
      );

  // ─── Shadows ────────────────────────────────────────────
  List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: brand.withValues(alpha: isDark ? 0.05 : 0.02),
          blurRadius: 40,
          offset: const Offset(0, 4),
        ),
      ];

  List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
}
