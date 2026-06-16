import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/status_pill.dart';
import '../models/drive_item.dart';

class FilePreviewScreen extends StatelessWidget {
  const FilePreviewScreen({super.key, required this.item});
  final DriveItem item;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: topPadding + AppSpacing.md,
              left: AppSpacing.pagePaddingH,
              right: AppSpacing.pagePaddingH,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 16, color: context.colors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Drive', style: AppTypography.labelMedium.copyWith(color: context.colors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: AppSpacing.xl),

                // File Name
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.displaySmall,
                      ),
                    ),
                    if (item.isFinalExport)
                      Icon(Icons.stars_rounded, color: context.colors.amber, size: 28),
                  ],
                ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.02),

                const SizedBox(height: AppSpacing.xxl),

                // Preview Box (Mocking an image/video player or web view)
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceOverlay,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.colors.glassBorder),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.mimeType.contains('video') ? Icons.play_circle_fill_rounded : Icons.image_rounded,
                          size: 64,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Preview Available', style: AppTypography.labelLarge.copyWith(color: context.colors.textSecondary)),
                        if (item.webViewLink != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('Linked to Google Drive', style: AppTypography.caption.copyWith(color: context.colors.brand)),
                        ],
                      ],
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppSpacing.xxxl),

                // Delivery Tracking Section (if applicable)
                if (item.deliveryStatus != null || item.isFinalExport) ...[
                  Text('Delivery Tracking', style: AppTypography.titleMedium).animate(delay: 300.ms).fadeIn(),
                  const SizedBox(height: AppSpacing.md),
                  
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    borderRadius: 16,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Status', style: AppTypography.bodyMedium),
                            StatusPill(
                              label: item.deliveryStatus ?? 'Pending',
                              preset: item.deliveryStatus == 'Delivered' ? StatusPreset.completed : StatusPreset.pending,
                            ),
                          ],
                        ),
                        Divider(height: 32, color: context.colors.glassBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivered At', style: AppTypography.bodyMedium),
                            Text(
                              item.deliveredAt != null ? DateFormat('MMM d, yyyy • h:mm a').format(item.deliveredAt!) : '--',
                              style: AppTypography.labelMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.05),
                ],

                const SizedBox(height: AppSpacing.xxxl),

                // File Details
                Text('Details', style: AppTypography.titleMedium).animate(delay: 400.ms).fadeIn(),
                const SizedBox(height: AppSpacing.md),
                
                GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      _DetailRow(label: 'Type', value: item.mimeType),
                      Divider(height: 24, color: context.colors.glassBorder),
                      _DetailRow(label: 'Size', value: '${(item.sizeBytes ?? 0) / 1024 / 1024} MB'),
                      Divider(height: 24, color: context.colors.glassBorder),
                      _DetailRow(label: 'Uploaded By', value: item.uploadedBy ?? 'Unknown'),
                      Divider(height: 24, color: context.colors.glassBorder),
                      _DetailRow(label: 'Date', value: DateFormat('MMM d, yyyy').format(item.createdAt)),
                    ],
                  ),
                ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.05),

              ],
            ),
          ),

          // Actions Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(AppSpacing.pagePaddingH, AppSpacing.md, AppSpacing.pagePaddingH, MediaQuery.of(context).padding.bottom + AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.background.withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: context.colors.glassBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LiquidButton(
                      label: 'Copy Link',
                      icon: Icons.link_rounded,
                      variant: LiquidButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: LiquidButton(
                      label: 'Download',
                      icon: Icons.download_rounded,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: 500.ms).fadeIn().slideY(begin: 1),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: context.colors.textTertiary)),
        Text(value, style: AppTypography.labelMedium),
      ],
    );
  }
}
