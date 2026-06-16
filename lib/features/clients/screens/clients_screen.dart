import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_button.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../models/client.dart';
import '../providers/client_provider.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    final clientsAsync = ref.watch(filteredClientsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),

        // ─── Header & Actions ───────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              Expanded(
                child: Text('Clients', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn()
                    .slideX(begin: -0.03, end: 0),
              ),
              LiquidButton(
                label: 'New Client',
                icon: Icons.add_business_rounded,
                size: LiquidButtonSize.small,
                onPressed: () {},
              ).animate(delay: 100.ms).fadeIn(),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ─── Search Bar ─────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _ClientSearchBar().animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Grid / List ────────────────────────────────
        Expanded(
          child: clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) return const Center(child: Text('No clients found.'));

              return GridView.builder(
                padding: EdgeInsets.only(left: hPad, right: hPad, bottom: 120),
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 3 : 1,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: isDesktop ? 1.5 : 2,
                ),
                itemCount: clients.length,
                itemBuilder: (context, i) {
                  return _ClientCard(client: clients[i])
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
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────
class _ClientSearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: context.colors.textTertiary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              onChanged: (val) => ref.read(clientSearchQueryProvider.notifier).state = val,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search clients, industries...',
                hintStyle: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Client Card ──────────────────────────────────────────
class _ClientCard extends StatefulWidget {
  const _ClientCard({required this.client});
  final Client client;

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _isHovered = false;

  StatusPreset get _preset => switch (widget.client.status) {
    'Active' => StatusPreset.active,
    'Lead' => StatusPreset.pending,
    'Inactive' => StatusPreset.inactive,
    _ => StatusPreset.inactive,
  };

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final path = AppRoutes.clientDetail.replaceFirst(':id', widget.client.id);
          context.push(path);
        },
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: 20,
          fillColor: _isHovered ? context.colors.glassFill.withValues(alpha: 0.18) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.glassBorder),
                    ),
                    child: Center(
                      child: widget.client.logoUrl != null 
                          ? Icon(Icons.image_not_supported_outlined, color: context.colors.textTertiary) // Placeholder for Image.network
                          : Text(widget.client.name[0].toUpperCase(), style: AppTypography.titleMedium.copyWith(color: context.colors.brandLight)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.client.name, style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(widget.client.industry, style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                      ],
                    ),
                  ),
                  StatusPill(label: widget.client.status, preset: _preset, small: true),
                ],
              ),

              // Financial Overview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(label: 'Revenue', value: currency.format(widget.client.financials.totalRevenue), color: context.colors.success),
                  if (widget.client.financials.pendingPayments > 0)
                    _MiniStat(label: 'Pending', value: currency.format(widget.client.financials.pendingPayments), color: context.colors.amber),
                  _MiniStat(label: 'Contacts', value: '${widget.client.contacts.length}', color: context.colors.brand),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.labelLarge.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
      ],
    );
  }
}
