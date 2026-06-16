import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/loading_state.dart';
import '../models/report_config.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final config = ref.watch(reportConfigProvider);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: topPadding + AppSpacing.lg),

            // ─── Header ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Text('Reports & Analytics', style: AppTypography.displaySmall)
                  .animate()
                  .fadeIn()
                  .slideX(begin: -0.03, end: 0),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ─── Report Types (Tabs) ────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const _ReportTabs().animate(delay: 100.ms).fadeIn(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ─── Config Area (Date Pickers / Selectors) ─────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _ConfigBar(config: config).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ─── Data Preview ───────────────────────────────
            Expanded(
              child: const _DataPreview().animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),
            ),
          ],
        ),

        // ─── Export Overlay ───────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(hPad, AppSpacing.md, hPad, MediaQuery.of(context).padding.bottom + AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.background.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: context.colors.glassBorder)),
            ),
            child: const _ExportActions().animate(delay: 400.ms).fadeIn().slideY(begin: 1),
          ),
        ),
      ],
    );
  }
}

// ─── Tabs ─────────────────────────────────────────────────
class _ReportTabs extends ConsumerWidget {
  const _ReportTabs();

  static const _types = [
    ReportType.daily,
    ReportType.weekly,
    ReportType.monthly,
    ReportType.employee,
    ReportType.project,
  ];

  String _formatName(ReportType type) {
    return type.name[0].toUpperCase() + type.name.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeType = ref.watch(reportConfigProvider).type;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _types.map((type) {
          final isActive = type == activeType;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                final now = DateTime.now();
                ref.read(reportConfigProvider.notifier).state = ReportConfig(
                  type: type,
                  startDate: DateTime(now.year, now.month, now.day),
                  endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? context.colors.brand.withValues(alpha: 0.15) : context.colors.glassFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? context.colors.brand.withValues(alpha: 0.5) : context.colors.glassBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _formatName(type),
                  style: AppTypography.labelSmall.copyWith(
                    color: isActive ? context.colors.brand : context.colors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Config Bar ───────────────────────────────────────────
class _ConfigBar extends ConsumerWidget {
  const _ConfigBar({required this.config});
  final ReportConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTargetRequired = config.type == ReportType.employee || config.type == ReportType.project;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          if (isTargetRequired) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.glassHighlight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  config.type == ReportType.employee ? 'Select Employee...' : 'Select Project...',
                  style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary),
                ),
              ),
            ),
          ] else ...[
            Icon(Icons.date_range_rounded, color: context.colors.textTertiary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Date Range Active',
              style: AppTypography.bodyMedium.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Data Preview ─────────────────────────────────────────
class _DataPreview extends ConsumerWidget {
  const _DataPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final previewAsync = ref.watch(reportPreviewProvider);

    return previewAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_outlined, size: 48, color: context.colors.glassBorder),
                const SizedBox(height: AppSpacing.md),
                Text('No data available for current selection.', style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary)),
              ],
            ),
          );
        }

        // Render basic JSON-like preview or table
        return ListView.builder(
          padding: EdgeInsets.only(left: hPad, right: hPad, bottom: 120),
          physics: const BouncingScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 100, child: Text('${e.key}:', style: AppTypography.caption.copyWith(color: context.colors.textTertiary))),
                        Expanded(child: Text('${e.value}', style: AppTypography.bodySmall)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: LoadingState()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── Export Actions ───────────────────────────────────────
class _ExportActions extends ConsumerWidget {
  const _ExportActions();

  void _handleExport(BuildContext context, WidgetRef ref, ExportFormat format) async {
    final config = ref.read(reportConfigProvider);
    final dataAsync = ref.read(reportPreviewProvider);

    if (dataAsync.value == null || dataAsync.value!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    final dataConfig = config.copyWith(data: dataAsync.value!);
    
    ref.read(isExportingProvider.notifier).state = true;
    try {
      final service = ref.read(exportServiceProvider);
      final path = await service.exportReport(dataConfig, format);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Failed.')));
      }
    } finally {
      ref.read(isExportingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExporting = ref.watch(isExportingProvider);

    if (isExporting) {
      return const SizedBox(
        height: 48,
        child: Center(child: LoadingState(compact: true)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: LiquidButton(
            label: 'CSV',
            icon: Icons.table_view_rounded,
            variant: LiquidButtonVariant.secondary,
            onPressed: () => _handleExport(context, ref, ExportFormat.csv),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: LiquidButton(
            label: 'Excel',
            icon: Icons.grid_on_rounded,
            variant: LiquidButtonVariant.secondary,
            onPressed: () => _handleExport(context, ref, ExportFormat.excel),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: LiquidButton(
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            variant: LiquidButtonVariant.primary,
            onPressed: () => _handleExport(context, ref, ExportFormat.pdf),
          ),
        ),
      ],
    );
  }
}
