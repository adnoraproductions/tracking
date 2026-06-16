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
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/status_pill.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final hPad = isDesktop ? AppSpacing.xxxl : AppSpacing.pagePaddingH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),
        
        // ─── Header ─────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Row(
            children: [
              Expanded(
                child: Text('Projects', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.03, end: 0),
              ),
              LiquidButton(
                label: 'New Project',
                icon: Icons.add_rounded,
                size: LiquidButtonSize.small,
                onPressed: () {},
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Filters ────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: const _ProjectFilters(),
        ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.lg),

        // ─── Projects Grid/List ─────────────────────────
        Expanded(
          child: ref.watch(projectsProvider).when(
                data: (projects) {
                  if (projects.isEmpty) {
                    return const Center(child: Text('No projects found.'));
                  }
                  return GridView.builder(
                    padding: EdgeInsets.only(
                      left: hPad,
                      right: hPad,
                      bottom: 120,
                    ),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 1,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isDesktop ? 1.4 : 2,
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, i) {
                      return _ProjectCard(project: projects[i])
                          .animate(delay: Duration(milliseconds: i * 60))
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05, end: 0);
                    },
                  );
                },
                loading: () => const Center(child: LoadingState(compact: true)),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
      ],
    );
  }
}

// ─── Filters ──────────────────────────────────────────────
class _ProjectFilters extends ConsumerWidget {
  const _ProjectFilters();

  static const _filters = ['All', 'Planning', 'In Progress', 'On Hold', 'Completed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(projectFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _filters.map((filter) {
          final isActive = filter == activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => ref.read(projectFilterProvider.notifier).state = filter,
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
                  filter,
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

// ─── Project Card ─────────────────────────────────────────
class _ProjectCard extends StatefulWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _isHovered = false;

  StatusPreset get _preset => switch (widget.project.status) {
    'In Progress' => StatusPreset.inProgress,
    'Planning' => StatusPreset.pending,
    'Completed' => StatusPreset.completed,
    'On Hold' => StatusPreset.onHold,
    _ => StatusPreset.inactive,
  };

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final path = AppRoutes.projectDetail.replaceFirst(':id', widget.project.id);
          context.push(path);
        },
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: 20,
          fillColor: _isHovered ? context.colors.glassFill.withValues(alpha: 0.18) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.folder_rounded, color: context.colors.brand, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project.name,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.project.clientName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.project.clientName!,
                            style: AppTypography.caption.copyWith(color: context.colors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  StatusPill(label: widget.project.status, preset: _preset, small: true),
                ],
              ),
              
              const Spacer(),

              // Team Assignment
              if (widget.project.teamMembers.isNotEmpty)
                SizedBox(
                  height: 28,
                  child: Stack(
                    children: [
                      for (int i = 0; i < widget.project.teamMembers.take(4).length; i++)
                        Positioned(
                          left: i * 20.0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.surfaceOverlay,
                              border: Border.all(color: context.colors.surfaceElevated, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                widget.project.teamMembers[i].name[0],
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.brandLight),
                              ),
                            ),
                          ),
                        ),
                      if (widget.project.teamMembers.length > 4)
                        Positioned(
                          left: 4 * 20.0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.glassBorder,
                              border: Border.all(color: context.colors.surfaceElevated, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '+${widget.project.teamMembers.length - 4}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.md),

              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress', style: AppTypography.caption.copyWith(color: context.colors.textTertiary)),
                  Text('${(widget.project.progress * 100).toInt()}%', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.project.progress,
                  minHeight: 4,
                  backgroundColor: context.colors.brand.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(context.colors.brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
