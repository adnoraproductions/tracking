import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../providers/project_provider.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));

    return Scaffold(
      backgroundColor: context.colors.background,
      body: projectAsync.when(
        data: (project) {
          final topPadding = MediaQuery.of(context).padding.top;
          
          return Stack(
            children: [
              // Ambient Glow
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [context.colors.brand.withValues(alpha: 0.1), Colors.transparent],
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
                          Text('Projects', style: AppTypography.labelMedium.copyWith(color: context.colors.textSecondary)),
                        ],
                      ),
                    ).animate().fadeIn(),

                    const SizedBox(height: AppSpacing.xl),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: AppTypography.displaySmall,
                          ),
                        ),
                        StatusPill(
                          label: project.status,
                          preset: _presetFor(project.status),
                        ),
                      ],
                    ).animate(delay: 100.ms).fadeIn().slideX(begin: -0.02),

                    if (project.clientName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Client: ${project.clientName}',
                        style: AppTypography.bodyMedium.copyWith(color: context.colors.textTertiary),
                      ).animate(delay: 150.ms).fadeIn(),
                    ],

                    const SizedBox(height: AppSpacing.xxl),

                    // Description
                    Text(
                      'Overview',
                      style: AppTypography.titleMedium,
                    ).animate(delay: 200.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      project.description.isNotEmpty ? project.description : 'No description provided.',
                      style: AppTypography.bodyMedium.copyWith(color: context.colors.textSecondary, height: 1.5),
                    ).animate(delay: 250.ms).fadeIn(),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Progress
                    GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      borderRadius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Overall Progress', style: AppTypography.titleSmall),
                              Text('${(project.progress * 100).toInt()}%', style: AppTypography.titleMedium.copyWith(color: context.colors.brand)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: project.progress,
                              minHeight: 8,
                              backgroundColor: context.colors.brand.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(context.colors.brand),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Project Workspace Navigation
                    Text('Workspace', style: AppTypography.titleMedium).animate(delay: 350.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Ensure the active project is set, then navigate
                              ref.read(projectFilterProvider.notifier).state = project.id;
                              context.go('/tasks');
                            },
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              borderRadius: 16,
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, color: context.colors.cyan, size: 28),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text('Tasks', style: AppTypography.labelMedium),
                                ],
                              ),
                            ),
                          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              context.go('/journal');
                            },
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              borderRadius: 16,
                              child: Column(
                                children: [
                                  Icon(Icons.book_outlined, color: context.colors.amber, size: 28),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text('Journal', style: AppTypography.labelMedium),
                                ],
                              ),
                            ),
                          ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.05),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              context.go('/drive');
                            },
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              borderRadius: 16,
                              child: Column(
                                children: [
                                  Icon(Icons.folder_outlined, color: context.colors.brandLight, size: 28),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text('Drive', style: AppTypography.labelMedium),
                                ],
                              ),
                            ),
                          ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.05),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Team
                    Text('Team Members', style: AppTypography.titleMedium).animate(delay: 400.ms).fadeIn(),
                    const SizedBox(height: AppSpacing.md),
                    
                    if (project.teamMembers.isEmpty)
                      const Text('No team members assigned.')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: project.teamMembers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final m = project.teamMembers[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            borderRadius: 16,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: context.colors.surfaceOverlay,
                                  child: Text(m.name[0], style: TextStyle(color: context.colors.brandLight)),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.name, style: AppTypography.titleSmall),
                                      Text(m.role, style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: Duration(milliseconds: 450 + (i * 50))).fadeIn().slideX(begin: 0.03);
                        },
                      ),
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

  StatusPreset _presetFor(String status) {
    return switch (status) {
      'In Progress' => StatusPreset.inProgress,
      'Planning' => StatusPreset.pending,
      'Completed' => StatusPreset.completed,
      'On Hold' => StatusPreset.onHold,
      _ => StatusPreset.inactive,
    };
  }
}
