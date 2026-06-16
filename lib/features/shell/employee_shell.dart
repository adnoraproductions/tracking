import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

import '../../core/routes/app_router.dart';

import '../../shared/widgets/floating_glass_nav.dart';

/// Employee shell — Modern floating dock navigation
class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key, required this.child});
  final Widget child;

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  static const _routes = [
    AppRoutes.dashboard,
    AppRoutes.attendance,
    AppRoutes.leave,
    AppRoutes.profile,
  ];

  static const _navItems = [
    FloatingNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    FloatingNavItem(icon: Icons.bolt_outlined, activeIcon: Icons.bolt_rounded, label: 'Tracker'),
    FloatingNavItem(icon: Icons.history_rounded, activeIcon: Icons.history_rounded, label: 'History'),
    FloatingNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
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
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Page content
          Positioned.fill(
            bottom: 0,
            child: widget.child,
          ),

          // Modern Floating Dock
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

