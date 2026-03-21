import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Widgets/ui.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.emailOrPhone,
    this.helperText,
  });

  final String emailOrPhone;
  final String? helperText;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _otp = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);

    final ok = await context.read<AuthProvider>().verifyEmail(
          email: widget.emailOrPhone.trim().toLowerCase(),
          code: _otp.text.trim(),
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      showAppSnack(context, 'OTP verified. You can now login.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showAppSnack(
        context,
        context.read<AuthProvider>().errorMessage ?? 'Verification failed.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionCard(
              title: 'Verification code',
              subtitle: 'Enter the code sent to ${widget.emailOrPhone}',
              child: widget.helperText == null
                  ? const SizedBox.shrink()
                  : Text(widget.helperText!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP'),
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
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
