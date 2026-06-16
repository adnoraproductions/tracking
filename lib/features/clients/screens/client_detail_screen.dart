import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/animated_stat_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../providers/client_provider.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(clientId));
    final projectsAsync = ref.watch(clientProjectsProvider(clientId));

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: clientAsync.when(
        data: (client) {
          return Stack(
            children: [
              // Ambient Glow
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [context.colors.success.withValues(alpha: 0.1), Colors.transparent],
                    ),
                  ),
                ),
              ),

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
                          Text('Clients', style: AppTypography.labelMedium.copyWith(color: context.colors.textSecondary)),
                        ],
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: AppSpacing.xl),

                    // Header
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colors.glassBorder),
                          ),
                          child: Center(
                            child: Text(client.name[0].toUpperCase(), style: AppTypography.headlineMedium.copyWith(color: context.colors.success)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client.name, style: AppTypography.displaySmall),
                              const SizedBox(height: 4),
                              Text('${client.industry} • Joined ${DateFormat('yyyy').format(client.createdAt)}', style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary)),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: client.status,
                          preset: client.status == 'Active' ? StatusPreset.active : StatusPreset.inactive,
                        ),
                      ],
                    ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.02),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Financials
                    Text('Financial Overview', style: AppTypography.titleMedium).animate(delay: 200.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedStatCard(
                            label: 'Total Revenue',
                            value: client.financials.totalRevenue,
                            prefix: '\$',
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: context.colors.success,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AnimatedStatCard(
                            label: 'Pending Payments',
                            value: client.financials.pendingPayments,
                            prefix: '\$',
                            icon: Icons.pending_actions_rounded,
                            iconColor: context.colors.amber,
                          ),
                        ),
                      ],
                    ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Contacts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Contacts', style: AppTypography.titleMedium),
                        Icon(Icons.add_circle_outline_rounded, color: context.colors.brand, size: 20),
                      ],
                    ).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),
                    
                    if (client.contacts.isEmpty)
                      Text('No contacts listed.', style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary))
                    else
                      ...client.contacts.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GlassCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: context.colors.glassHighlight, shape: BoxShape.circle),
                                child: Icon(Icons.person_outline, size: 18, color: context.colors.textSecondary),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(c.name, style: AppTypography.titleSmall),
                                        if (c.isPrimary) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: context.colors.brand.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                            child: Text('Primary', style: AppTypography.caption.copyWith(color: context.colors.brandLight, fontSize: 9)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text('${c.role} • ${c.email}', style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate(delay: 350.ms).fadeIn().slideX(begin: 0.03),
                      )),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Projects List
                    Text('Associated Projects', style: AppTypography.titleMedium).animate(delay: 400.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),

                    projectsAsync.when(
                      data: (projects) {
                        if (projects.isEmpty) return const Text('No projects yet.');
                        return Column(
                          children: projects.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: GestureDetector(
                              onTap: () => context.push(AppRoutes.projectDetail.replaceFirst(':id', p.id)),
                              child: GlassCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                borderRadius: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: AppTypography.titleSmall),
                                        Text(p.status, style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                                      ],
                                    ),
                                    Text('${(p.progress * 100).toInt()}%', style: AppTypography.labelMedium.copyWith(color: context.colors.brand)),
                                  ],
                                ),
                              ),
                            ),
                          )).toList(),
                        ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.05);
                      },
                      loading: () => const LoadingState(compact: true),
                      error: (e, _) => Text('Error loading projects: $e'),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Notes
                    Text('Notes', style: AppTypography.titleMedium).animate(delay: 500.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      borderRadius: 16,
                      child: Text(
                        client.notes?.isNotEmpty == true ? client.notes! : 'No notes available.',
                        style: AppTypography.bodyMedium.copyWith(color: context.colors.textSecondary, height: 1.5),
                      ),
                    ).animate(delay: 550.ms).fadeIn().slideY(begin: 0.05),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: LoadingState()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
