import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await AuthService.signIn(_email, _password);

    setState(() {
      _loading = false;
    });

    if (ok) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _error = 'Invalid credentials';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
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
                      validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      onChanged: (v) => _password = v,
                      validator: (v) => (v ?? '').length >= 6 ? null : 'Min 6 chars',
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // Show hints for the mock creds
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Demo credentials'),
                            content: const Text('Email: lockin@app.com\nPassword: password'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                            ],
                          ),
                        );
                      },
                      child: const Text('Need demo credentials?'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
