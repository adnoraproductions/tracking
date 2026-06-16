import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/drive_item.dart';

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  return DriveRepository(Supabase.instance.client);
});

class DriveRepository {
  DriveRepository(this._supabase);
  final SupabaseClient _supabase;

  Future<List<DriveItem>> getDriveItems({
    required String projectId,
    String? parentFolderId,
    bool finalExportsOnly = false,
  }) async {
    var query = _supabase.from('drive_items').select().eq('project_id', projectId);

    if (finalExportsOnly) {
      query = query.eq('is_final_export', true);
    } else {
      if (parentFolderId == null) {
        query = query.filter('parent_folder_id', 'is', null); // Root
      } else {
        query = query.eq('parent_folder_id', parentFolderId);
      }
    }

    final response = await query.order('is_folder', ascending: false).order('name', ascending: true);

    return (response as List).map((row) => DriveItem.fromJson(row)).toList();
  }

  Future<DriveItem> updateDeliveryStatus(String itemId, String status) async {
    final updates = {
      'delivery_status': status,
      if (status == 'Delivered') 'delivered_at': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('drive_items')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();

    return DriveItem.fromJson(response);
  }

  Future<DriveItem> createFolder(String projectId, String name, String? parentFolderId) async {
    final response = await _supabase.from('drive_items').insert({
      'project_id': projectId,
      'parent_folder_id': parentFolderId,
      'name': name,
      'mime_type': 'application/vnd.google-apps.folder',
      'is_folder': true,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return DriveItem.fromJson(response);
  }
}
