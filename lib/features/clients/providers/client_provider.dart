import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client.dart';
import '../../projects/models/project.dart';
import '../repositories/client_repository.dart';

final clientSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final rawClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getClients();
});

final filteredClientsProvider = Provider.autoDispose<AsyncValue<List<Client>>>((ref) {
  final asyncClients = ref.watch(rawClientsProvider);
  final query = ref.watch(clientSearchQueryProvider).toLowerCase();

  return asyncClients.whenData((clients) {
    if (query.isEmpty) return clients;
    return clients.where((c) => 
      c.name.toLowerCase().contains(query) || 
      c.industry.toLowerCase().contains(query)
    ).toList();
  });
});

final clientDetailProvider = FutureProvider.autoDispose.family<Client, String>((ref, id) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getClientById(id);
});

final clientProjectsProvider = FutureProvider.autoDispose.family<List<Project>, String>((ref, clientId) async {
  final repo = ref.watch(clientRepositoryProvider);
  return repo.getClientProjects(clientId);
});
