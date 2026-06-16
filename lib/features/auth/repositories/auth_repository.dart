import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_profile.dart';

/// Repository handling all Supabase auth & profile operations
class AuthRepository {
  AuthRepository();

  SupabaseClient get _client => SupabaseService.client;

  // ─── Authentication ─────────────────────────────────────

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ─── Profile ────────────────────────────────────────────

  /// Fetch user profile from `profiles` table
  Future<UserProfile?> fetchProfile(String userId) async {

    try {
      final response = await _client
          .from(AppConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('AuthRepository.fetchProfile error: $e');
      return null;
    }
  }

  /// Create initial profile after first login
  Future<UserProfile> createProfile({
    required String userId,
    required String email,
    required String fullName,
    String role = 'employee',
  }) async {

    final now = DateTime.now().toIso8601String();
    final data = {
      'id': userId,
      'email': email,
      'full_name': fullName,
      'role': role,
      'is_active': true,
      'onboarding_complete': false,
      'created_at': now,
      'updated_at': now,
    };

    final response = await _client
        .from(AppConstants.tableProfiles)
        .upsert(data)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Update profile fields
  Future<UserProfile> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {

    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from(AppConstants.tableProfiles)
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Upload profile photo and update profile
  Future<String> uploadProfilePhoto(String userId, dynamic fileBytesOrPath, String fileName) async {
    final fileExt = fileName.split('.').last;
    final filePath = '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    // Depending on web or mobile, we either upload bytes or a file path
    // Assuming mobile file path here for simplicity:
    final file = io.File(fileBytesOrPath as String);
    
    await _client.storage.from('avatars').upload(
          filePath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);

    await updateProfile(
      userId: userId,
      updates: {'avatar_url': publicUrl},
    );

    return publicUrl;
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding(String userId) async {
    await _client
        .from(AppConstants.tableProfiles)
        .update({
          'onboarding_complete': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  // ─── Role Detection ─────────────────────────────────────

  /// Returns the role string for a given user
  Future<String> getUserRole(String userId) async {

    try {
      final response = await _client
          .from(AppConstants.tableProfiles)
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] as String? ?? 'employee';
    } catch (_) {
      return 'employee';
    }
  }

  // ─── Session ────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;
  
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
