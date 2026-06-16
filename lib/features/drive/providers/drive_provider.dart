import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drive_item.dart';
import '../repositories/drive_repository.dart';

// Provides the project ID context
final activeDriveProjectIdProvider = StateProvider<String?>((ref) => null);

// Provides the current folder context (null means Root)
final currentFolderIdProvider = StateProvider<String?>((ref) => null);

// Toggle for Final Exports view
final finalExportsOnlyProvider = StateProvider<bool>((ref) => false);

// Active Upload Jobs
final activeUploadsProvider = StateProvider<List<UploadJob>>((ref) => []);

final driveItemsProvider = FutureProvider<List<DriveItem>>((ref) async {
  final repo = ref.watch(driveRepositoryProvider);
  final projectId = ref.watch(activeDriveProjectIdProvider);
  final folderId = ref.watch(currentFolderIdProvider);
  final finalExportsOnly = ref.watch(finalExportsOnlyProvider);

  if (projectId == null) return [];

  return repo.getDriveItems(
    projectId: projectId,
    parentFolderId: folderId,
    finalExportsOnly: finalExportsOnly,
  );
});

// Breadcrumbs provider
class Breadcrumb {
  Breadcrumb({required this.id, required this.name});
  final String? id; // null = Root
  final String name;
}

final driveBreadcrumbsProvider = StateNotifierProvider<BreadcrumbsNotifier, List<Breadcrumb>>((ref) {
  return BreadcrumbsNotifier();
});

class BreadcrumbsNotifier extends StateNotifier<List<Breadcrumb>> {
  BreadcrumbsNotifier() : super([Breadcrumb(id: null, name: 'Root')]);

  void navigateTo(String id, String name) {
    state = [...state, Breadcrumb(id: id, name: name)];
  }

  void navigateUpTo(String? id) {
    final index = state.indexWhere((b) => b.id == id);
    if (index != -1) {
      state = state.sublist(0, index + 1);
    }
  }

  void reset() {
    state = [Breadcrumb(id: null, name: 'Root')];
  }
}
