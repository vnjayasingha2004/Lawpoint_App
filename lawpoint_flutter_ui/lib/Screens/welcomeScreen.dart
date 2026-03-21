import 'package:flutter/material.dart';

import 'loginScreen.dart';
import 'registerClientScreen.dart';
import 'registerLawyerScreen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 34,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.balance_rounded,
                    size: 34, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('LawPoint',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                adminMode
                    ? 'The mobile app is designed for clients and lawyers. Admin actions are expected on the web dashboard.'
                    : 'A cleaner mobile App for verified lawyers, bookings, legal locker, case updates, messaging, knowledge hub, payments, and scheduled video sessions.',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 28),
              _FeatureRow(
                  icon: Icons.verified_user_rounded,
                  text: 'Verified lawyers and public profiles'),
              _FeatureRow(
                  icon: Icons.calendar_month_rounded,
                  text: 'Booking, schedule, and reminders'),
              _FeatureRow(
                  icon: Icons.lock_rounded,
                  text: 'Secure chat and legal locker'),
              _FeatureRow(
                  icon: Icons.language_rounded,
                  text: 'Ready for English, Sinhala, and Tamil'),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RegisterClientScreen())),
                child: const Text('Register as client'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RegisterLawyerScreen())),
                child: const Text('I am a lawyer - submit credentials'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
