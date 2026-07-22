import 'package:flutter/material.dart';

import '../services/auth_session_service.dart';

/// Minimal sign-in / register for post-login lobby gate.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _session = AuthSessionService.instance;
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registerMode) {
        await _session.register(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await _session.login(
          username: _username.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickRegister() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.quickRegisterTestUser();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Trust Rummy',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _registerMode ? 'Create an account' : 'Sign in to play',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_busy,
                ),
                if (_registerMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_busy,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_busy,
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Please wait…' : (_registerMode ? 'Register' : 'Sign in')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _registerMode = !_registerMode;
                            _error = null;
                          }),
                  child: Text(_registerMode ? 'Have an account? Sign in' : 'Need an account? Register'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _quickRegister,
                  child: const Text('Quick register (dev)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
