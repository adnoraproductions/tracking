import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/journal_note.dart';
import '../repositories/journal_repository.dart';

// Provides the project ID for the journal scope
final activeJournalProjectIdProvider = StateProvider.autoDispose<String?>((ref) => null);
// Provides the current search query
final journalSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Fetches raw notes
final rawJournalNotesProvider = FutureProvider.autoDispose<List<JournalNote>>((ref) async {
  final repo = ref.watch(journalRepositoryProvider);
  final projectId = ref.watch(activeJournalProjectIdProvider);
  final authState = ref.watch(authNotifierProvider);
  final userId = authState is AuthAuthenticated ? authState.userId : null;

  if (projectId == null || userId == null) return [];
  return repo.getJournalNotes(projectId, userId);
});

// Provides searched/filtered notes categorized
final filteredJournalNotesProvider = Provider.autoDispose<AsyncValue<Map<String, List<JournalNote>>>>((ref) {
  final asyncNotes = ref.watch(rawJournalNotesProvider);
  final searchQuery = ref.watch(journalSearchQueryProvider).toLowerCase();

  return asyncNotes.whenData((notes) {
    var filtered = notes;
    if (searchQuery.isNotEmpty) {
      filtered = notes.where((note) {
        return note.title.toLowerCase().contains(searchQuery) ||
               note.content.toLowerCase().contains(searchQuery);
      }).toList();
    }

    // Categorize
    final pinned = filtered.where((n) => n.isPinned).toList();
    final timeline = filtered.where((n) => !n.isPinned).toList();

    return {
      'pinned': pinned,
      'timeline': timeline,
    };
  });
});
