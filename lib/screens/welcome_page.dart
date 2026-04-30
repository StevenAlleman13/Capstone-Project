import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _neonGreen = Color(0xFF00FF66);

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _loading = false;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _signInWithGoogle() async {
    setState(() => _error = null);

    try {
      const webClientId =
          '866492092188-8d97rmk8g7lq1srrojif283gr4okv732.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: webClientId);

      final googleUser = await googleSignIn.authenticate();

      final scopes = ['email', 'profile'];
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) throw AuthException('No ID Token found.');

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOCKIN Title
                Text(
                  'LOCK IN',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _neonGreen,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    fontSize: 32,
                  ),
                ),

                const SizedBox(height: 16),

                // Gameboy Logo (smaller)
                Image.asset(
                  'assets/images/gameboy_lock.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),                const SizedBox(height: 48),

                // Buttons Container
                Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: 420,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            // Sign In Button (outlined style like Google button)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/login');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _neonGreen.withOpacity(0.65),
                                  ),
                                  foregroundColor: _neonGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Sign In'),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Sign In with Google Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _signInWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 26),
                                label: const Text('Sign in with Google'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _neonGreen.withOpacity(0.65),
                                  ),
                                  foregroundColor: _neonGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Create Account Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/signup');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _neonGreen.withOpacity(0.65),
                                  ),
                                  foregroundColor: _neonGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Create Account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
