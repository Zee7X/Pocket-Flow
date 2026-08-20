// lib/features/auth/data/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Current authenticated user (null if not signed in).
  User? get currentUser => _client.auth.currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Register a new account with email and password.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: name != null ? {'name': name} : null,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }
}
