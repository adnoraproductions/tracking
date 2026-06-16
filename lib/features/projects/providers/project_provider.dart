import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/project_repository.dart';

final projectFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  final filter = ref.watch(projectFilterProvider);
  
  return repo.getProjects(status: filter == 'All' ? null : filter);
});

final projectDetailProvider = FutureProvider.autoDispose.family<Project, String>((ref, id) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProjectById(id);
});
