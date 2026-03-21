import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/lawyer_form_options.dart';
import '../Data/providers/authProvider.dart';
import '../Widgets/ui.dart';
import 'otpVerifyScreen.dart';

class RegisterLawyerScreen extends StatefulWidget {
  const RegisterLawyerScreen({super.key});

  @override
  State<RegisterLawyerScreen> createState() => _RegisterLawyerScreenState();
}

class _RegisterLawyerScreenState extends State<RegisterLawyerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _enrolment = TextEditingController();
  final _basl = TextEditingController();

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedDistricts = {};

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _password.dispose();
    _enrolment.dispose();
    _basl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLanguages.isEmpty) {
      showAppSnack(context, 'Select at least one language.', error: true);
      return;
    }

    if (_selectedDistricts.isEmpty) {
      showAppSnack(context, 'Select at least one district.', error: true);
      return;
    }

    setState(() => _busy = true);

    final result = await context.read<AuthProvider>().registerLawyer(
          fullName: _name.text.trim(),
          email: _contact.text.trim(),
          password: _password.text,
          enrolmentNo: _enrolment.text.trim(),
          baslId: _basl.text.trim(),
          districts: _selectedDistricts.toList(),
          languages: _selectedLanguages.toList(),
        );

    if (!mounted) return;

    setState(() => _busy = false);

    if (result == null) {
      showAppSnack(
        context,
        context.read<AuthProvider>().errorMessage ?? 'Registration failed.',
        error: true,
      );
      return;
    }

    if (result.otpRequired) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            emailOrPhone: _contact.text.trim(),
            helperText:
                result.devOtp == null ? null : 'Dev OTP: ${result.devOtp}',
          ),
        ),
      );
    } else {
      showAppSnack(
        context,
        'Registration submitted. Wait for admin approval before public listing.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildMultiSelectChips({
    required String title,
    required String subtitle,
    required List<String> options,
    required Set<String> selected,
  }) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options
            .map(
              (item) => FilterChip(
                label: Text(item),
                selected: selected.contains(item),
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) {
                      selected.add(item);
                    } else {
                      selected.remove(item);
                    }
                  });
                },
                showCheckmark: true,
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lawyer registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SectionCard(
                title: 'Submit your credentials',
                subtitle:
                    'Approved lawyer profiles become searchable after admin verification.',
                child: SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your full name.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(labelText: 'Email or phone'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter email or phone.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _enrolment,
                decoration:
                    const InputDecoration(labelText: 'Enrolment number'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your enrolment number.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _basl,
                decoration: const InputDecoration(labelText: 'BASL ID'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your BASL ID.'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildMultiSelectChips(
                title: 'Languages',
                subtitle: 'Select all languages you can consult in.',
                options: lawyerLanguageOptions,
                selected: _selectedLanguages,
              ),
              const SizedBox(height: 16),
              _buildMultiSelectChips(
                title: 'Practice districts',
                subtitle: 'Select all districts where clients can find you.',
                options: sriLankanDistricts,
                selected: _selectedDistricts,
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
                    : const Text('Submit for verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
