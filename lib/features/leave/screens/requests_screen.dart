import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/status_pill.dart';

/// Leave / Requests screen for employee
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),

        // ─── Header ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
          child: Row(
            children: [
              Expanded(
                child: Text('Requests', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.03, end: 0),
              ),
              LiquidButton(
                label: 'New Request',
                icon: Icons.add_rounded,
                size: LiquidButtonSize.small,
                onPressed: () {},
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Leave Balance Cards ──────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
          child: Row(
            children: [
              Expanded(
                child: const _BalanceChip(label: 'Casual', count: 8, total: 12, color: AppColors.brand)
                    .animate(delay: 150.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: const _BalanceChip(label: 'Sick', count: 4, total: 6, color: AppColors.cyan)
                    .animate(delay: 210.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: const _BalanceChip(label: 'Earned', count: 2, total: 15, color: AppColors.amber)
                    .animate(delay: 270.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Tab Bar ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
          child: _GlassTabBar(controller: _tabController),
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.lg),

        // ─── Tab Content ──────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const _RequestsList(status: 'all'),
              const _RequestsList(status: 'pending'),
              const _RequestsList(status: 'approved'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Balance Chip ─────────────────────────────────────────
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = count / total;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '$count/$total',
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glass Tab Bar ────────────────────────────────────────
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.labelSmall,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        padding: const EdgeInsets.all(3),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Pending'),
          Tab(text: 'Approved'),
        ],
      ),
    );
  }
}

// ─── Requests List ────────────────────────────────────────
class _RequestsList extends StatelessWidget {
  const _RequestsList({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final requests = _sampleRequests
        .where((r) => status == 'all' || r.status.toLowerCase() == status)
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.only(
        left: AppSpacing.pagePaddingH,
        right: AppSpacing.pagePaddingH,
        bottom: 120,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final r = requests[i];
        return _RequestTile(data: r)
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 400.ms)
            .slideX(begin: 0.03, end: 0);
      },
    );
  }
}

// ─── Request Tile ─────────────────────────────────────────
class _RequestData {
  const _RequestData({
    required this.type,
    required this.dateRange,
    required this.days,
    required this.reason,
    required this.status,
  });

  final String type;
  final String dateRange;
  final String days;
  final String reason;
  final String status;
}

final _sampleRequests = [
  const _RequestData(
    type: 'Casual Leave',
    dateRange: 'Jun 20 - Jun 21',
    days: '2 days',
    reason: 'Personal work',
    status: 'Pending',
  ),
  const _RequestData(
    type: 'Sick Leave',
    dateRange: 'Jun 5',
    days: '1 day',
    reason: 'Not feeling well',
    status: 'Approved',
  ),
  const _RequestData(
    type: 'Earned Leave',
    dateRange: 'May 15 - May 20',
    days: '5 days',
    reason: 'Vacation',
    status: 'Approved',
  ),
  const _RequestData(
    type: 'Casual Leave',
    dateRange: 'Apr 28',
    days: '1 day',
    reason: 'Family event',
    status: 'Approved',
  ),
  const _RequestData(
    type: 'Casual Leave',
    dateRange: 'Apr 10',
    days: '1 day',
    reason: 'Doctor appointment',
    status: 'Rejected',
  ),
];

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.data});
  final _RequestData data;

  StatusPreset get _preset => switch (data.status) {
    'Pending' => StatusPreset.pending,
    'Approved' => StatusPreset.active,
    'Rejected' => StatusPreset.error,
    _ => StatusPreset.inactive,
  };

  IconData get _icon => switch (data.type) {
    'Sick Leave' => Icons.medical_services_outlined,
    'Earned Leave' => Icons.flight_outlined,
    _ => Icons.event_outlined,
  };

  Color get _iconColor => switch (data.type) {
    'Sick Leave' => AppColors.cyan,
    'Earned Leave' => AppColors.amber,
    _ => AppColors.brand,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 18, color: _iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.type, style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${data.dateRange} · ${data.days}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: data.status,
                preset: _preset,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.glassHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              data.reason,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
