import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../auth/providers/auth_provider.dart';

/// Profile screen for employee
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.lg,
        left: AppSpacing.pagePaddingH,
        right: AppSpacing.pagePaddingH,
        bottom: 120,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // ─── Avatar & Name ──────────────────────────────
          _ProfileHeader()
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: AppSpacing.xxxl),

          // ─── Info Cards ─────────────────────────────────
          const _InfoSection(
            title: 'Personal Info',
            items: [
              _InfoItem(icon: Icons.email_outlined, label: 'Email', value: 'employee@adnora.com'),
              _InfoItem(icon: Icons.phone_outlined, label: 'Phone', value: '+91 98765 43210'),
              _InfoItem(icon: Icons.business_outlined, label: 'Department', value: 'Design'),
              _InfoItem(icon: Icons.badge_outlined, label: 'Designation', value: 'UI/UX Designer'),
            ],
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),

          const SizedBox(height: AppSpacing.lg),

          const _InfoSection(
            title: 'Work Info',
            items: [
              _InfoItem(icon: Icons.calendar_today_outlined, label: 'Joined', value: 'Jan 15, 2025'),
              _InfoItem(icon: Icons.supervisor_account_outlined, label: 'Reports To', value: 'Aarav Kumar'),
              _InfoItem(icon: Icons.work_outline_rounded, label: 'Employee ID', value: 'ADN-0042'),
            ],
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),

          const SizedBox(height: AppSpacing.xxl),

          // ─── Action Buttons ─────────────────────────────
          _ActionTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {},
          ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.sm),

          _ActionTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () {},
          ).animate(delay: 450.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.sm),

          _ActionTile(
            icon: Icons.info_outline_rounded,
            label: 'About ADNORA OS',
            subtitle: 'v1.0.0',
            onTap: () {},
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.xxl),

          // Sign out
          LiquidButton(
            label: 'Sign Out',
            icon: Icons.logout_rounded,
            variant: LiquidButtonVariant.danger,
            expanded: true,
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ).animate(delay: 550.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large avatar
        Container(
          width: AppSpacing.avatarXl,
          height: AppSpacing.avatarXl,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                context.colors.brand.withValues(alpha: 0.35),
                context.colors.brandDark.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: context.colors.brand.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brand.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'AD',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.colors.brandLight,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Text(
          'Adnora Employee',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'UI/UX Designer · Design',
          style: AppTypography.bodyMedium.copyWith(
            color: context.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ─── Info Section ─────────────────────────────────────────
class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.items});
  final String title;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              title.toUpperCase(),
              style: AppTypography.overline.copyWith(
                color: context.colors.brand,
                letterSpacing: 2,
              ),
            ),
          ),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Column(
              children: [
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: context.colors.glassBorder.withValues(alpha: 0.5),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ),
                      Text(
                        item.value,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Action Tile ──────────────────────────────────────────
class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          borderRadius: 16,
          fillColor: _isHovered
              ? context.colors.glassFill.withValues(alpha: 0.2)
              : null,
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.subtitle != null) ...[
                Text(
                  widget.subtitle!,
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textDisabled,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
