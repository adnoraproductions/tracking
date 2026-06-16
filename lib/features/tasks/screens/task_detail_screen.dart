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
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a real app, you'd fetch the single task from a taskDetailProvider.
    // For now, we pull from the kanban board state if available.
    final board = ref.watch(kanbanBoardProvider).value ?? {};
    final allTasks = board.values.expand((t) => t).toList();
    final task = allTasks.firstWhere((t) => t.id == taskId, orElse: () => _emptyTask);

    if (task.id == 'empty') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('Task not found.')),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Glow
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.brand.withValues(alpha: 0.1), Colors.transparent],
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
                      const Icon(Icons.arrow_back_ios_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Board', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: AppSpacing.xl),

                // Priority Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getPriorityColor(task.priority).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    task.priority,
                    style: AppTypography.labelSmall.copyWith(
                      color: _getPriorityColor(task.priority),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  task.title,
                  style: AppTypography.displaySmall,
                ).animate(delay: 150.ms).fadeIn().slideX(begin: -0.02),

                const SizedBox(height: AppSpacing.xl),

                // Metadata Row (Assignee & Due Date)
                Row(
                  children: [
                    Expanded(
                      child: _MetaTile(
                        icon: Icons.person_outline,
                        label: 'Assignee',
                        value: task.assigneeName ?? 'Unassigned',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MetaTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Due Date',
                        value: task.dueDate != null 
                            ? DateFormat('MMM d, yyyy').format(task.dueDate!)
                            : 'No Date',
                      ),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05),

                const SizedBox(height: AppSpacing.xxl),

                // Description
                Text('Description', style: AppTypography.titleMedium).animate(delay: 250.ms).fadeIn(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  task.description.isNotEmpty ? task.description : 'No description provided.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.6),
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: AppSpacing.xxxl),

                // Checklist
                if (task.checklist.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Checklist', style: AppTypography.titleMedium),
                      Text(
                        '${task.checklist.where((c) => c.isCompleted).length}/${task.checklist.length}',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.brand),
                      ),
                    ],
                  ).animate(delay: 350.ms).fadeIn(),
                  const SizedBox(height: AppSpacing.md),
                  
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    borderRadius: 20,
                    child: Column(
                      children: task.checklist.map((item) {
                        return CheckboxListTile(
                          value: item.isCompleted,
                          onChanged: (val) {
                            // In real app, trigger state update
                          },
                          title: Text(
                            item.title,
                            style: AppTypography.bodyMedium.copyWith(
                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              color: item.isCompleted ? AppColors.textDisabled : AppColors.textPrimary,
                            ),
                          ),
                          activeColor: AppColors.brand,
                          checkColor: Colors.white,
                          controlAffinity: ListTileControlAffinity.leading,
                          side: const BorderSide(color: AppColors.glassBorder),
                        );
                      }).toList(),
                    ),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.05),
                ],
              ],
            ),
          ),
          
          // Action Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(AppSpacing.pagePaddingH, AppSpacing.md, AppSpacing.pagePaddingH, MediaQuery.of(context).padding.bottom + AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.9),
                border: const Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: LiquidButton(
                label: 'Mark as Done',
                icon: Icons.check_circle_rounded,
                expanded: true,
                onPressed: () {
                  ref.read(kanbanBoardProvider.notifier).moveTask(task, 'Done');
                  context.pop();
                },
              ),
            ),
          ).animate(delay: 500.ms).fadeIn().slideY(begin: 1),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    return switch (priority) {
      'Urgent' => AppColors.error,
      'High' => AppColors.pink,
      'Medium' => AppColors.amber,
      'Low' => AppColors.cyan,
      _ => AppColors.textTertiary,
    };
  }

  static const _emptyTask = ProjectTask(
    id: 'empty',
    projectId: '',
    title: '',
    description: '',
    status: '',
    priority: '',
  );
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                Text(value, style: AppTypography.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
