// lib/features/auth/domain/auth_state.dart

/// Represents the authentication state of the app.
sealed class AuthState {
  const AuthState();
}

/// Initial state — auth status not yet determined.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// User is authenticated.
class AuthAuthenticated extends AuthState {
  final String userId;
  final String? email;

  const AuthAuthenticated({required this.userId, this.email});
}

/// User is not authenticated.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Auth operation in progress (login, register, logout).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Auth operation failed.
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);
}
