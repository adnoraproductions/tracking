import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/journal_note.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(Supabase.instance.client);
});

class JournalRepository {
  JournalRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<JournalNote>> getJournalNotes(String projectId, String currentUserId) async {
    final response = await _supabase.from('journal_notes').select('''
      *,
      author:profiles!author_id ( name, avatar_url )
    ''')
    .eq('project_id', projectId)
    // Only fetch notes that are NOT private, OR are private but belong to the current user
    .or('is_private.eq.false,author_id.eq.$currentUserId')
    .order('created_at', ascending: false);

    return (response as List).map((row) {
      final author = row['author'] as Map<String, dynamic>?;

      return JournalNote(
        id: row['id'],
        projectId: row['project_id'],
        authorId: row['author_id'],
        authorName: author?['name'],
        authorAvatar: author?['avatar_url'],
        title: row['title'],
        content: row['content'] ?? '',
        noteType: row['note_type'] ?? 'text',
        isPinned: row['is_pinned'] ?? false,
        isPrivate: row['is_private'] ?? false,
        attachments: (row['attachments'] as List?)?.map((a) => JournalAttachment.fromJson(a as Map<String, dynamic>)).toList() ?? [],
        createdAt: DateTime.parse(row['created_at']),
        updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at']) : null,
      );
    }).toList();
  }

  Future<JournalNote> createNote(JournalNote note) async {
    final data = note.toJson()..remove('id')..remove('author_name')..remove('author_avatar');
    final response = await _supabase.from('journal_notes').insert(data).select().single();
    return JournalNote.fromJson(response);
  }

  Future<void> updatePinStatus(String noteId, bool isPinned) async {
    await _supabase.from('journal_notes').update({'is_pinned': isPinned}).eq('id', noteId);
  }
}
