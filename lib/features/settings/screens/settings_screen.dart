import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/auth_state.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final topPadding = MediaQuery.of(context).padding.top;
    final themeMode = ref.watch(themeModeProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: topPadding + AppSpacing.xl,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Page Title ─────────────────────────────────
          Text(
            'Settings',
            style: AppTypography.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Profile (Photo Upload) ─────────────────────
          const _SectionLabel('PROFILE'),
          const _ProfileHeader().animate(delay: 50.ms).fadeIn().slideY(begin: 0.02),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Appearance ─────────────────────────────────
          const _SectionLabel('APPEARANCE'),
          _SettingsGroup(
            children: [
              _ThemeTile(
                currentMode: themeMode,
                onChanged: (mode) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                },
              ),
            ],
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.02),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Workspace ──────────────────────────────────
          const _SectionLabel('WORKSPACE'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.domain_rounded,
                iconColor: colors.brand,
                title: 'Company Details',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: colors.cyan,
                title: 'Roles & Permissions',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.wifi_rounded,
                iconColor: colors.emerald,
                title: 'Office Wi-Fi',
                subtitle: 'Configure attendance networks',
                onTap: () => GoRouter.of(context).push('/admin/wifi-config'),
              ),
              _SettingsTile(
                icon: Icons.schedule_rounded,
                iconColor: colors.amber,
                title: 'Business Hours',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.02),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Notifications & Data ───────────────────────
          const _SectionLabel('NOTIFICATIONS & DATA'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                iconColor: colors.error,
                title: 'Notification Rules',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.file_download_outlined,
                iconColor: colors.info,
                title: 'Data Export',
                subtitle: 'Export attendance & project data',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsTile(
                icon: Icons.history_rounded,
                iconColor: colors.textSecondary,
                title: 'Audit Log',
                subtitle: 'System activity & security events',
                onTap: () => GoRouter.of(context).push('/audit-log'),
              ),
            ],
          ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.02),
          const SizedBox(height: AppSpacing.xxl),

          // ─── Billing ────────────────────────────────────
          const _SectionLabel('SUBSCRIPTION'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.credit_card_rounded,
                iconColor: colors.pink,
                title: 'Plan & Billing',
                subtitle: 'Manage subscription & invoices',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.02),
          const SizedBox(height: AppSpacing.xxl),

          // ─── About ──────────────────────────────────────
          const _SectionLabel('ABOUT'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: colors.textTertiary,
                title: 'About Adnora',
                subtitle: 'Version 1.0.0',
                showChevron: false,
                onTap: () {},
              ),
            ],
          ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.02),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon'),
        backgroundColor: context.colors.surfaceOverlay,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ─── Section Label ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: context.colors.textTertiary,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

// ─── Settings Group (iOS rounded section) ───────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceGrouped,
        borderRadius: BorderRadius.circular(12),
        border: colors.isDark
            ? Border.all(color: colors.glassBorder, width: 0.33)
            : null,
        boxShadow: colors.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.33,
                thickness: 0.33,
                indent: 56,
                color: colors.separator,
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Settings Tile ──────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = iconColor ?? colors.brand;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            // Chevron
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textDisabled,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Selector Tile ────────────────────────────────────────

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.currentMode, required this.onChanged});
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.indigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  colors.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: colors.indigo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Appearance',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented control
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.isDark
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                _ThemeSegment(
                  label: 'Light',
                  isActive: currentMode == ThemeMode.light,
                  onTap: () => onChanged(ThemeMode.light),
                ),
                _ThemeSegment(
                  label: 'Dark',
                  isActive: currentMode == ThemeMode.dark,
                  onTap: () => onChanged(ThemeMode.dark),
                ),
                _ThemeSegment(
                  label: 'Auto',
                  isActive: currentMode == ThemeMode.system,
                  onTap: () => onChanged(ThemeMode.system),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isActive ? colors.textPrimary : colors.textTertiary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Profile Header (Avatar Upload) ─────────────────────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader();

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final authState = ref.read(authNotifierProvider);
      if (authState is! AuthAuthenticated) return;

      final repo = ref.read(authRepositoryProvider);
      await repo.uploadProfilePhoto(
        authState.userId, 
        pickedFile.path, 
        pickedFile.name,
      );

      // Trigger profile refresh to load new avatar
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentProfileAsync = ref.watch(currentProfileProvider);
    
    final avatarUrl = currentProfileAsync.valueOrNull?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.glassBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.glassFill,
                    border: Border.all(color: colors.glassBorder, width: 2),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => Icon(Icons.person_rounded, size: 40, color: colors.textSecondary),
                          )
                        : Icon(Icons.person_rounded, size: 40, color: colors.textSecondary),
                  ),
                ),
                if (_isUploading)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                if (!_isUploading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Picture',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the avatar to change your photo. PNG or JPG max 2MB.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
