import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(Supabase.instance.client);
});

class TaskRepository {
  TaskRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<ProjectTask>> getTasksByProject(String projectId) async {
    final response = await _supabase.from('tasks').select('''
      *,
      assignee:profiles!assignee_id ( name, avatar_url )
    ''').eq('project_id', projectId).order('created_at', ascending: true);

    return (response as List).map((row) {
      final assignee = row['assignee'] as Map<String, dynamic>?;
      
      return ProjectTask(
        id: row['id'],
        projectId: row['project_id'],
        title: row['title'],
        description: row['description'] ?? '',
        status: row['status'] ?? 'Todo',
        priority: row['priority'] ?? 'Medium',
        assigneeId: row['assignee_id'],
        assigneeName: assignee?['name'],
        assigneeAvatar: assignee?['avatar_url'],
        dueDate: row['due_date'] != null ? DateTime.parse(row['due_date']) : null,
        checklist: (row['checklist'] as List?)?.map((c) => TaskChecklistItem.fromJson(c as Map<String, dynamic>)).toList() ?? [],
        createdAt: row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
        updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
      );
    }).toList();
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _supabase.from('tasks').update({'status': status}).eq('id', taskId);
  }

  Future<void> updateChecklist(String taskId, List<TaskChecklistItem> checklist) async {
    final jsonList = checklist.map((e) => e.toJson()).toList();
    await _supabase.from('tasks').update({'checklist': jsonList}).eq('id', taskId);
  }
}
