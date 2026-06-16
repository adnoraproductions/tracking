import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../shared/enums/enums.dart';
import '../models/auth_state.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

// ─── Repository Provider ──────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ─── Auth State Notifier ──────────────────────────────────
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthInitial());

  final AuthRepository _repo;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final response = await _repo.signIn(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        state = AuthAuthenticated(userId: user.id);
      } else {
        state = const AuthError('Sign in failed. Please try again.');
      }
    } on supa.AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Unexpected error: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      await _repo.signOut();
      state = const AuthUnauthenticated();
    } catch (e) {
      debugPrint('SignOut error: $e');
      state = const AuthUnauthenticated();
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AuthLoading();
    try {
      await _repo.resetPassword(email);
      state = const AuthPasswordResetSent();
    } on supa.AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Failed to send reset email: ${e.toString()}');
    }
  }

  void clearError() {
    if (state is AuthError) {
      state = const AuthUnauthenticated();
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (lower.contains('too many requests') ||
        lower.contains('rate_limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (lower.contains('user not found')) {
      return 'No account found with this email.';
    }
    return message;
  }
}

// ─── User Profile Provider ────────────────────────────────
final userProfileProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.fetchProfile(userId);
});

// ─── Current Profile Provider ─────────────────────────────
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return null;
  return repo.fetchProfile(user.id);
});

// ─── User Role Provider ───────────────────────────────────
final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.role ?? UserRole.employee;
});

// ─── Is Admin Provider ────────────────────────────────────
final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(userRoleProvider.future);
  return role == UserRole.admin;
});

// ─── Onboarding Status Provider ───────────────────────────
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.onboardingComplete ?? false;
});

// ─── Supabase Auth Stream Provider ────────────────────────
final supabaseAuthStreamProvider =
    StreamProvider<supa.AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});
