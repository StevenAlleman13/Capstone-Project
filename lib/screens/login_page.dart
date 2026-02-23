import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _neonGreen = Color(0xFF00FF66);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.signInWithPassword(
        email: _email.trim(),
        password: _password,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _supabase.auth.signUp(
        email: _email.trim(),
        password: _password,
      );

      final session = res.session;
      if (!mounted) return;

      if (session != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _error = 'Account created. Check your email to confirm before signing in.';
        });
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Google OAuth with Supabase
  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // Optional: if you have deep links configured, you can add redirectTo
        // redirectTo: 'io.supabase.flutter://login-callback/',
      );

      // OAuth flow will redirect; on success your auth state listener should route.
      // If you don't have a listener, you can check currentSession after returning.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 18),

          // LOCKIN Title
          Center(
            child: Text(
              'LOCK IN',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _neonGreen,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
            ),
          ),

          const SizedBox(height: 12),

          // Gameboy Logo
          Center(
            child: Image.asset(
              'assets/images/gameboy_lock.png',
              width: 150, // adjust size here
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 24),

            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 420,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (v) => _email = v,
                            validator: (v) => (v != null && v.contains('@'))
                                ? null
                                : 'Enter a valid email',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            obscureText: _obscure,
                            onChanged: (v) => _password = v,
                            validator: (v) =>
                                (v ?? '').length >= 6 ? null : 'Min 6 chars',
                          ),
                          const SizedBox(height: 18),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // 1) Sign in
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 2) Sign in with Google
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 26),
                              label: const Text('Sign in with Google'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _neonGreen.withOpacity(0.65)),
                                foregroundColor: _neonGreen,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 3) Create account (under Google)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signUp,
                              child: const Text(
                                'Create account',
                                style: TextStyle(color: _neonGreen),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}