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
import '../../../shared/widgets/loading_state.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final boardAsync = ref.watch(kanbanBoardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + AppSpacing.lg),

        // ─── Header ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
          child: Row(
            children: [
              // Back Button if nested inside a project
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
              Expanded(
                child: Text('Board', style: AppTypography.displaySmall)
                    .animate()
                    .fadeIn()
                    .slideX(begin: -0.03, end: 0),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Kanban Board ───────────────────────────────
        Expanded(
          child: boardAsync.when(
            data: (board) {
              if (board.isEmpty) return const Center(child: Text('No tasks found.'));

              final statuses = ['Todo', 'In Progress', 'Review', 'Done'];

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePaddingH),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: statuses.map((status) {
                    final tasks = board[status] ?? [];
                    return _KanbanColumn(
                      status: status,
                      tasks: tasks,
                    ).animate().fadeIn().slideY(begin: 0.05);
                  }).toList(),
                ),
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

// ─── Kanban Column ────────────────────────────────────────
class _KanbanColumn extends ConsumerWidget {
  const _KanbanColumn({required this.status, required this.tasks});
  final String status;
  final List<ProjectTask> tasks;

  Color _getStatusColor() {
    return switch (status) {
      'Todo' => AppColors.textDisabled,
      'In Progress' => AppColors.brand,
      'Review' => AppColors.amber,
      'Done' => AppColors.success,
      _ => AppColors.glassBorder,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                status.toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length}',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Drop Target & Task List
          Expanded(
            child: DragTarget<ProjectTask>(
              onWillAcceptWithDetails: (details) => details.data.status != status,
              onAcceptWithDetails: (details) {
                ref.read(kanbanBoardProvider.notifier).moveTask(details.data, status);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isHovered ? AppColors.brand.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isHovered
                        ? Border.all(color: AppColors.brand.withValues(alpha: 0.3), width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      return Draggable<ProjectTask>(
                        data: tasks[i],
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 300,
                            child: _TaskCard(task: tasks[i], isDragging: true),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _TaskCard(task: tasks[i]),
                        ),
                        child: _TaskCard(task: tasks[i]),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Task Card ────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.isDragging = false});
  final ProjectTask task;
  final bool isDragging;

  Color _getPriorityColor() {
    return switch (task.priority) {
      'Urgent' => AppColors.error,
      'High' => AppColors.pink,
      'Medium' => AppColors.amber,
      'Low' => AppColors.cyan,
      _ => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final completedItems = task.checklist.where((c) => c.isCompleted).length;
    final hasChecklist = task.checklist.isNotEmpty;

    return GestureDetector(
      onTap: () {
        if (!isDragging) {
          final path = AppRoutes.taskDetail.replaceFirst(':id', task.id);
          context.push(path);
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: 16,
        fillColor: isDragging ? AppColors.surfaceElevated.withValues(alpha: 0.9) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority & Due Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority,
                    style: AppTypography.caption.copyWith(
                      color: _getPriorityColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (task.dueDate != null)
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d').format(task.dueDate!),
                        style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              task.title,
              style: AppTypography.titleSmall.copyWith(height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppSpacing.md),

            // Footer (Checklist & Assignee)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasChecklist)
                  Row(
                    children: [
                      const Icon(Icons.check_box_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$completedItems/${task.checklist.length}',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  )
                else
                  const SizedBox(),
                  
                if (task.assigneeName != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.brandDark,
                    child: Text(
                      task.assigneeName![0],
                      style: const TextStyle(fontSize: 10, color: AppColors.brandLight),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
