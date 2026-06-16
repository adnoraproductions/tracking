import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Supabase service for ADNORA OS
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Initialize Supabase — call once in main()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
      debug: kDebugMode,
    );
  }

  /// Current authenticated user
  static User? get currentUser => auth.currentUser;

  /// Current session
  static Session? get currentSession => auth.currentSession;

  /// Whether user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Auth state change stream
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  /// Sign in with email & password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return auth.signInWithPassword(email: email, password: password);
  }

  /// Sign up with email & password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return auth.signUp(email: email, password: password, data: data);
  }

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
  }

  /// Reset password
  static Future<void> resetPassword(String email) async {
    await auth.resetPasswordForEmail(email);
  }
}
