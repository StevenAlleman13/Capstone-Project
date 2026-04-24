import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

const Color _neonGreen = Color(0xFF00FF66);

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _resetPassword() async {
    final token = _tokenController.text.trim();
    final password = _passwordController.text;

    if (token.length != 8) {
      setState(() => _error = 'Enter the 8-digit code from your email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.recovery,
      );
      await _supabase.auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset! Please sign in.')),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter the 8-digit code sent to your email and choose a new password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _neonGreen),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: '8-digit code'),
                keyboardType: TextInputType.number,
                maxLength: 8,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                cursorColor: Colors.white,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                cursorColor: Colors.white,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
