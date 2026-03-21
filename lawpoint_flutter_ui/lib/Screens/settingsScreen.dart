import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/appPreferencesProvider.dart';
import '../Data/providers/authProvider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferencesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Theme mode'),
              subtitle: Text(prefs.themeMode.name),
              trailing: DropdownButton<ThemeMode>(
                value: prefs.themeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) prefs.setThemeMode(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Language'),
              subtitle: Text(prefs.locale?.languageCode ?? 'system default'),
              trailing: DropdownButton<String?>(
                value: prefs.locale?.languageCode,
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('System'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'en',
                    child: Text('English'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'si',
                    child: Text('Sinhala'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'ta',
                    child: Text('Tamil'),
                  ),
                ],
                onChanged: (v) => prefs.setLocale(v == null ? null : Locale(v)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () async {
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;

                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        ],
      ),
    );
  }
}
