import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/routes/app_router.dart';
import '../../shared/widgets/adnora_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';

import '../../shared/widgets/floating_glass_nav.dart';

/// Admin shell — responsive glass sidebar on desktop/tablet, iOS tab bar on mobile
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _routes = [
    AppRoutes.dashboard,
    AppRoutes.adminEmployees,
    AppRoutes.adminAttendance,
    AppRoutes.adminWifiConfig,
    AppRoutes.reports,
    AppRoutes.settings,
  ];

  static const _navItems = [
    FloatingNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    FloatingNavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Team'),
    FloatingNavItem(icon: Icons.fingerprint_outlined, activeIcon: Icons.fingerprint_rounded, label: 'Attendance'),
    FloatingNavItem(icon: Icons.wifi_outlined, activeIcon: Icons.wifi_rounded, label: 'Network'),
    FloatingNavItem(icon: Icons.bar_chart_rounded, activeIcon: Icons.insert_chart_rounded, label: 'Reports'),
    FloatingNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  void _onNavTap(int index) {
    final target = _routes[index];
    final current = GoRouterState.of(context).matchedLocation;
    if (current != target) {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Layout
          Row(
            children: [
              if (isDesktop)
                _GlassSidebar(
                  items: _navItems,
                  currentIndex: idx,
                  onTap: _onNavTap,
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
              Expanded(
                child: isDesktop
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colors.separator.withValues(alpha: 0.3),
                              width: 0.33,
                            ),
                          ),
                        ),
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ],
          ),

          // Modern Floating Dock (Mobile only)
          if (!isDesktop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingGlassNav(
                items: _navItems,
                currentIndex: idx,
                onTap: _onNavTap,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

// ─── Desktop Glass Sidebar ─────────────────────────────────────

class _GlassSidebar extends StatelessWidget {
  const _GlassSidebar({required this.items, required this.currentIndex, required this.onTap});
  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 240,
      color: colors.isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F8FA),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: AdnoraLogo(size: AdnoraLogoSize.small),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, i) {
                final isActive = i == currentIndex;
                final item = items[i];
                return _SidebarItem(
                  item: item,
                  isActive: isActive,
                  onTap: () => onTap(i),
                );
              },
            ),
          ),
          _AdminProfileSnippet(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({required this.item, required this.isActive, required this.onTap});
  final FloatingNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = widget.isActive
        ? colors.brand
        : _isHovered ? colors.textPrimary : colors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? colors.brand.withValues(alpha: 0.1)
                : _isHovered
                    ? colors.surfaceOverlay.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.isActive ? widget.item.activeIcon : widget.item.icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(
                widget.item.label,
                style: AppTypography.labelLarge.copyWith(
                  color: color,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminProfileSnippet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.brand.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text('A', style: TextStyle(
                color: colors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin', style: AppTypography.labelMedium.copyWith(color: colors.textPrimary)),
                Text('Workspace', style: AppTypography.caption.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: Icon(Icons.logout_rounded, size: 18, color: colors.error),
          ),
        ],
      ),
    );
  }
}
