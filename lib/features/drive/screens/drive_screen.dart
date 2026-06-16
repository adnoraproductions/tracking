import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../models/drive_item.dart';
import '../providers/drive_provider.dart';

class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final driveItemsAsync = ref.watch(driveItemsProvider);
    final isFinalExportsOnly = ref.watch(finalExportsOnlyProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: topPadding + AppSpacing.lg),

            // ─── Header & Actions ───────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Drive', style: AppTypography.displaySmall)
                        .animate()
                        .fadeIn()
                        .slideX(begin: -0.03, end: 0),
                  ),
                  LiquidButton(
                    label: 'Upload',
                    icon: Icons.cloud_upload_rounded,
                    size: LiquidButtonSize.small,
                    onPressed: () {},
                  ).animate(delay: 100.ms).fadeIn(),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Breadcrumbs & Filters ──────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFinalExportsOnly)
                    Expanded(child: const _Breadcrumbs().animate(delay: 200.ms).fadeIn())
                  else
                    Expanded(
                      child: Text(
                        'Final Exports & Deliverables',
                        style: AppTypography.titleMedium.copyWith(color: AppColors.brand),
                      ).animate(delay: 200.ms).fadeIn(),
                    ),
                  
                  // Filter Toggle
                  GestureDetector(
                    onTap: () {
                      final current = ref.read(finalExportsOnlyProvider);
                      ref.read(finalExportsOnlyProvider.notifier).state = !current;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFinalExportsOnly ? AppColors.brand.withValues(alpha: 0.2) : AppColors.glassFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isFinalExportsOnly ? AppColors.brand.withValues(alpha: 0.5) : AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.stars_rounded, size: 16, color: isFinalExportsOnly ? AppColors.brandLight : AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Text('Finals Only', style: AppTypography.labelSmall.copyWith(color: isFinalExportsOnly ? AppColors.brandLight : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ).animate(delay: 250.ms).fadeIn(),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Items List ─────────────────────────────────
            Expanded(
              child: driveItemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('Folder is empty.'));
                  }

                  return ListView.separated(
                    padding: EdgeInsets.only(left: hPad, right: hPad, bottom: 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _DriveItemTile(item: item)
                          .animate(delay: Duration(milliseconds: 300 + (i * 50)))
                          .fadeIn()
                          .slideY(begin: 0.05);
                    },
                  );
                },
                loading: () => const Center(child: LoadingState()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),

        // ─── Active Uploads Overlay ───────────────────────
        const Positioned(
          bottom: 100,
          right: AppSpacing.pagePaddingH,
          child: _UploadsOverlay(),
        ),
      ],
    );
  }
}

// ─── Breadcrumbs ──────────────────────────────────────────
class _Breadcrumbs extends ConsumerWidget {
  const _Breadcrumbs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breadcrumbs = ref.watch(driveBreadcrumbsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: breadcrumbs.asMap().entries.map((e) {
          final isLast = e.key == breadcrumbs.length - 1;
          final crumb = e.value;

          return Row(
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(currentFolderIdProvider.notifier).state = crumb.id;
                  ref.read(driveBreadcrumbsProvider.notifier).navigateUpTo(crumb.id);
                },
                child: Text(
                  crumb.name,
                  style: AppTypography.titleSmall.copyWith(
                    color: isLast ? AppColors.textPrimary : AppColors.textTertiary,
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textDisabled),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Drive Item Tile ──────────────────────────────────────
class _DriveItemTile extends ConsumerWidget {
  const _DriveItemTile({required this.item});
  final DriveItem item;

  IconData get _icon {
    if (item.isFolder) return Icons.folder_rounded;
    if (item.mimeType.contains('image')) return Icons.image_rounded;
    if (item.mimeType.contains('video')) return Icons.videocam_rounded;
    if (item.mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color get _iconColor {
    if (item.isFolder) return AppColors.brand;
    if (item.isFinalExport) return AppColors.amber;
    if (item.mimeType.contains('image')) return AppColors.cyan;
    if (item.mimeType.contains('video')) return AppColors.pink;
    return AppColors.textSecondary;
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (item.isFolder) {
          ref.read(currentFolderIdProvider.notifier).state = item.id;
          ref.read(driveBreadcrumbsProvider.notifier).navigateTo(item.id, item.name);
        } else {
          // Navigate to preview
          context.push('/drive/preview', extra: item);
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 16,
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _iconColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isFinalExport)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.stars_rounded, size: 14, color: AppColors.amber),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!item.isFolder) ...[
                        Text(_formatSize(item.sizeBytes), style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
                        const SizedBox(width: 8),
                        Text('•', style: AppTypography.caption.copyWith(color: AppColors.textDisabled)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        DateFormat('MMM d, yyyy').format(item.createdAt),
                        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delivery Tracking (if applicable)
            if (item.deliveryStatus != null) ...[
              const SizedBox(width: AppSpacing.sm),
              StatusPill(
                label: item.deliveryStatus!,
                preset: item.deliveryStatus == 'Delivered' ? StatusPreset.completed : StatusPreset.pending,
                small: true,
              ),
            ],

            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.more_vert_rounded, color: AppColors.textDisabled, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Uploads Overlay ──────────────────────────────────────
class _UploadsOverlay extends ConsumerWidget {
  const _UploadsOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploads = ref.watch(activeUploadsProvider);
    if (uploads.isEmpty) return const SizedBox();

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      borderColor: AppColors.brand.withValues(alpha: 0.3),
      child: SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uploading ${uploads.length} item(s)', style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            ...uploads.map((job) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(job.fileName, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${(job.progress * 100).toInt()}%', style: AppTypography.caption.copyWith(color: AppColors.brand)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: job.progress,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                      minHeight: 2,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
