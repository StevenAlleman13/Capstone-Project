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

  Future<void> _forgotPassword() async {
    if (_email.trim().isEmpty || !_email.contains('@')) {
      setState(
        () =>
            _error = 'Enter your email above first, then tap Forgot Password.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.resetPasswordForEmail(_email.trim());
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamed('/reset-password', arguments: _email.trim());
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    } finally {      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Back'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                width: 150,
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
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            cursorColor: Colors.white,
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
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            cursorColor: Colors.white,
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
                            ),                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _submit,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _neonGreen.withOpacity(0.65),
                                ),
                                foregroundColor: _neonGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ),                          const SizedBox(height: 1),

                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: _neonGreen,
                                  fontSize: 13,
                                ),
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
