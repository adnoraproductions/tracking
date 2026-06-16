import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';
import '../../projects/models/project.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(Supabase.instance.client);
});

class ClientRepository {
  ClientRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<Client>> getClients() async {
    final response = await _supabase
        .from('clients')
        .select()
        .order('name', ascending: true);

    return (response as List).map((row) => Client.fromJson(row)).toList();
  }

  Future<Client> getClientById(String id) async {
    final response = await _supabase
        .from('clients')
        .select()
        .eq('id', id)
        .single();

    return Client.fromJson(response);
  }

  /// Fetch projects associated with a client to show in their profile
  Future<List<Project>> getClientProjects(String clientId) async {
    final response = await _supabase.from('projects').select('''
      *,
      clients ( name ),
      project_members (
        user_id,
        role,
        profiles ( name, avatar_url )
      )
    ''').eq('client_id', clientId).order('created_at', ascending: false);

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
  }

  /// Update notes for a client
  Future<void> updateClientNotes(String clientId, String notes) async {
    await _supabase.from('clients').update({'notes': notes}).eq('id', clientId);
  }
}
