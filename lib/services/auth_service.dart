import 'dart:async';

/// A minimal mock authentication service. Replace with real backend later.
class AuthService {
  /// Simulate a network call and validate credentials.
  ///
  /// Returns `true` only when email is `user@example.com` and password is `password`.
  static Future<bool> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return email.trim().toLowerCase() == 'lockin@app.com' && password == 'password';
  }

  /// Simulated sign out (no-op for the mock).
  static Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
