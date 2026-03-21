import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Widgets/ui.dart';
import 'otpVerifyScreen.dart';

class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.registerClient(
      fullName: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
      password: _password.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result == null) {
      showAppSnack(
        context,
        authProvider.errorMessage ?? 'Registration failed.',
        error: true,
      );
      return;
    }

    if (result.otpRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              emailOrPhone: _email.text.trim(),
              helperText:
                  result.devOtp == null ? null : 'Dev OTP: ${result.devOtp}',
            ),
          ),
        );
      });
      return;
    } else {
      showAppSnack(
        context,
        result.message ?? 'Registration completed. Please login.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SectionCard(
                title: 'Create a client account',
                subtitle: 'You can sign up using email.',
                child: SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter your full name.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter your email.';
                  if (!value.contains('@')) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'Use at least 6 characters.'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
