import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(Supabase.instance.client);
});

class ProjectRepository {
  ProjectRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Project>> getProjects({String? status, String? clientId}) async {
    try {
      var query = _supabase.from('projects').select('''
        *,
        clients ( name ),
        project_members (
          user_id,
          role,
          profiles ( name, avatar_url )
        )
      ''');

      if (status != null && status != 'All') {
        query = query.eq('status', status);
      }
      if (clientId != null) {
        query = query.eq('client_id', clientId);
      }

      final response = await query.order('created_at', ascending: false);
      
      return (response as List).map((row) {
        final membersData = row['project_members'] as List? ?? [];
        final teamMembers = membersData.map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          return ProjectTeamMember(
            userId: m['user_id'],
            role: m['role'] ?? 'Member',
            name: profile?['name'] ?? 'Unknown',
            avatarUrl: profile?['avatar_url'],
          );
        }).toList();

        return Project(
          id: row['id'],
          name: row['name'],
          description: row['description'] ?? '',
          clientId: row['client_id'],
          clientName: row['clients']?['name'],
          status: row['status'] ?? 'Planning',
          progress: (row['progress'] ?? 0).toDouble(),
          startDate: row['start_date'] != null ? DateTime.parse(row['start_date']) : null,
          dueDate: row['due_date'] != null ? DateTime.parse(row['due_date']) : null,
          teamMembers: teamMembers,
          createdAt: row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
          updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Project Fetch Error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching projects.');
    }
  }

  Future<Project> getProjectById(String id) async {
    final response = await _supabase.from('projects').select('''
      *,
      clients ( name ),
      project_members (
        user_id,
        role,
        profiles ( name, avatar_url )
      )
    ''').eq('id', id).single();

    final membersData = response['project_members'] as List? ?? [];
    final teamMembers = membersData.map((m) {
      final profile = m['profiles'] as Map<String, dynamic>?;
      return ProjectTeamMember(
        userId: m['user_id'],
        role: m['role'] ?? 'Member',
        name: profile?['name'] ?? 'Unknown',
        avatarUrl: profile?['avatar_url'],
      );
    }).toList();

    return Project(
      id: response['id'],
      name: response['name'],
      description: response['description'] ?? '',
      clientId: response['client_id'],
      clientName: response['clients']?['name'],
      status: response['status'] ?? 'Planning',
      progress: (response['progress'] ?? 0).toDouble(),
      startDate: response['start_date'] != null ? DateTime.parse(response['start_date']) : null,
      dueDate: response['due_date'] != null ? DateTime.parse(response['due_date']) : null,
      teamMembers: teamMembers,
      createdAt: response['created_at'] != null ? DateTime.parse(response['created_at']) : null,
      updatedAt: response['updated_at'] != null ? DateTime.parse(response['updated_at']) : null,
    );
  }

  Future<void> updateProjectProgress(String id, double progress) async {
    await _supabase.from('projects').update({'progress': progress}).eq('id', id);
  }

  Future<void> updateProjectStatus(String id, String status) async {
    await _supabase.from('projects').update({'status': status}).eq('id', id);
  }
}
