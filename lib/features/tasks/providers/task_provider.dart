import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

// Provider that holds the current selected project ID for tasks.
// Set this before navigating to the kanban board, or pass it via family provider.
final activeProjectIdProvider = StateProvider.autoDispose<String?>((ref) => null);

final projectTasksProvider = FutureProvider.autoDispose<List<ProjectTask>>((ref) async {
  final repo = ref.watch(taskRepositoryProvider);
  final projectId = ref.watch(activeProjectIdProvider);
  
  if (projectId == null) return [];
  return repo.getTasksByProject(projectId);
});

// Kanban Board State Notifier to handle local drag-and-drop before saving to DB
final kanbanBoardProvider = StateNotifierProvider.autoDispose<KanbanBoardNotifier, AsyncValue<Map<String, List<ProjectTask>>>>((ref) {
  final projectId = ref.watch(activeProjectIdProvider);
  return KanbanBoardNotifier(
    ref.read(taskRepositoryProvider),
    projectId,
  );
});

class KanbanBoardNotifier extends StateNotifier<AsyncValue<Map<String, List<ProjectTask>>>> {
  KanbanBoardNotifier(this.repo, this.projectId) : super(const AsyncValue.loading()) {
    if (projectId != null) {
      loadTasks();
    } else {
      state = const AsyncValue.data({});
    }
  }

  final TaskRepository repo;
  final String? projectId;

  Future<void> loadTasks() async {
    try {
      state = const AsyncValue.loading();
      final tasks = await repo.getTasksByProject(projectId!);
      
      final board = {
        'Todo': <ProjectTask>[],
        'In Progress': <ProjectTask>[],
        'Review': <ProjectTask>[],
        'Done': <ProjectTask>[],
      };

      for (var task in tasks) {
        if (board.containsKey(task.status)) {
          board[task.status]!.add(task);
        } else {
          board['Todo']!.add(task);
        }
      }

      state = AsyncValue.data(board);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> moveTask(ProjectTask task, String newStatus) async {
    if (state.value == null || task.status == newStatus) return;

    final currentBoard = Map<String, List<ProjectTask>>.from(state.value!);
    
    // Optimistic UI update
    currentBoard[task.status]?.removeWhere((t) => t.id == task.id);
    final updatedTask = task.copyWith(status: newStatus);
    currentBoard[newStatus]?.add(updatedTask);
    
    state = AsyncValue.data(currentBoard);

    try {
      // Persist to DB
      await repo.updateTaskStatus(task.id, newStatus);
    } catch (e) {
      // Revert on failure
      loadTasks(); 
    }
  }
}
