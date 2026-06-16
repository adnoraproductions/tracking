import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';

/// Notifications screen for employee
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
          child: Row(
            children: [
              Expanded(
                child: Text('Notifications', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.03, end: 0),
              ),
              _MarkAllRead()
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Notification List ────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(
              left: AppSpacing.pagePaddingH,
              right: AppSpacing.pagePaddingH,
              bottom: 120,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: _sampleNotifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              return _NotificationTile(data: _sampleNotifications[i])
                  .animate(delay: Duration(milliseconds: 150 + (i * 50)))
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.03, end: 0);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Mark All Read ────────────────────────────────────────
class _MarkAllRead extends StatefulWidget {
  @override
  State<_MarkAllRead> createState() => _MarkAllReadState();
}

class _MarkAllReadState extends State<_MarkAllRead> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? context.colors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Mark all read',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Notification Data ────────────────────────────────────
class _NotifData {
  const _NotifData({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.isUnread = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final bool isUnread;
}

final _sampleNotifications = [
  const _NotifData(
    icon: Icons.check_circle_outline_rounded,
    color: AppColors.success,
    title: 'Leave Approved',
    body: 'Your casual leave request for Jun 20-21 has been approved by Admin.',
    time: '2m ago',
    isUnread: true,
  ),
  const _NotifData(
    icon: Icons.assignment_outlined,
    color: AppColors.brand,
    title: 'New Task Assigned',
    body: 'You\'ve been assigned "Create social media assets" in Project Rebrand.',
    time: '1h ago',
    isUnread: true,
  ),
  const _NotifData(
    icon: Icons.schedule_rounded,
    color: AppColors.amber,
    title: 'Clock-in Reminder',
    body: 'You haven\'t clocked in today yet. Don\'t forget to mark your attendance.',
    time: '3h ago',
    isUnread: true,
  ),
  const _NotifData(
    icon: Icons.comment_outlined,
    color: AppColors.cyan,
    title: 'New Comment',
    body: 'Aarav commented on "Landing Page Redesign": "Looks great, ship it!"',
    time: 'Yesterday',
  ),
  const _NotifData(
    icon: Icons.celebration_outlined,
    color: AppColors.pink,
    title: 'Milestone Reached',
    body: 'Project Adnora Rebrand is now 75% complete. Keep up the momentum!',
    time: '2 days ago',
  ),
  const _NotifData(
    icon: Icons.person_add_outlined,
    color: AppColors.emerald,
    title: 'Team Update',
    body: 'Priya has joined the Design department. Say hello!',
    time: '3 days ago',
  ),
];

// ─── Notification Tile ────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.data});
  final _NotifData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      fillColor: data.isUnread
          ? context.colors.brand.withValues(alpha: 0.04)
          : null,
      borderColor: data.isUnread
          ? context.colors.brand.withValues(alpha: 0.15)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: data.color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(data.icon, size: 20, color: data.color),
          ),

          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: data.isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (data.isUnread)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.brand.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.body,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.colors.textTertiary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  data.time,
                  style: AppTypography.caption.copyWith(
                    color: context.colors.textDisabled,
                    fontSize: 10,
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
