// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../domain/auth_state.dart' as domain;

// ─── Supabase client provider ────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ─── AuthRepository provider ─────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

// ─── Auth state notifier ─────────────────────────────────────────────────────
class AuthNotifier extends Notifier<domain.AuthState> {
  @override
  domain.AuthState build() {
    // Listen to Supabase auth state changes
    final sub = ref
        .watch(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen(_onAuthStateChange);

    ref.onDispose(sub.cancel);

    // Initial state from current session
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['username'] as String?;
      return domain.AuthAuthenticated(
        userId: user.id,
        email: user.email,
        displayName: name,
      );
    }
    return const domain.AuthUnauthenticated();
  }

  void _onAuthStateChange(AuthState authState) {
    final user = authState.session?.user;
    if (user != null) {
      final name = user.userMetadata?['name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['username'] as String?;
      state = domain.AuthAuthenticated(
        userId: user.id,
        email: user.email,
        displayName: name,
      );
    } else {
      state = const domain.AuthUnauthenticated();
    }
  }

  /// Sign in with email + password.
  Future<void> signIn({required String email, required String password}) async {
    state = const domain.AuthLoading();
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          );
      // State update happens via onAuthStateChange listener
    } on AuthException catch (e) {
      state = domain.AuthError(_localizeAuthError(e.message));
    } catch (e) {
      state = domain.AuthError('Terjadi kesalahan. Coba lagi.');
    }
  }

  /// Register new account.
  Future<void> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    state = const domain.AuthLoading();
    try {
      final res = await ref.read(authRepositoryProvider).signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
      // If email confirmation is required, Supabase returns a user but no session
      if (res.user != null && res.session == null) {
        // Treat as success — email confirmation needed
        state = domain.AuthError(
          'Pendaftaran berhasil! Cek email untuk konfirmasi akun.',
        );
      }
      // If session is returned immediately, listener handles state
    } on AuthException catch (e) {
      state = domain.AuthError(_localizeAuthError(e.message));
    } catch (e) {
      state = domain.AuthError('Terjadi kesalahan. Coba lagi.');
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    state = const domain.AuthLoading();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      state = const domain.AuthUnauthenticated();
    }
  }

  /// Reset password via email.
  Future<void> resetPassword(String email) async {
    state = const domain.AuthLoading();
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      state = domain.AuthError('Link reset password telah dikirim ke email.');
    } on AuthException catch (e) {
      state = domain.AuthError(_localizeAuthError(e.message));
    } catch (e) {
      state = domain.AuthError('Terjadi kesalahan. Coba lagi.');
    }
  }

  String _localizeAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Email atau password salah.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'Email sudah terdaftar. Coba login.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password minimal 6 karakter.';
    }
    if (lower.contains('unable to validate email address')) {
      return 'Format email tidak valid.';
    }
    if (lower.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
    }
    return message;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, domain.AuthState>(AuthNotifier.new);
