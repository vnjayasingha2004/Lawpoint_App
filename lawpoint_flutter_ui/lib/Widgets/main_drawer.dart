import 'package:flutter/material.dart';
import 'package:lawpoint_app/gen_l10n/app_localizations.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.onOpenKnowledgeHub,
    required this.onOpenSettings,
    required this.onLogout,
  });

  final VoidCallback onOpenKnowledgeHub;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: Text(t.appName),
              subtitle: Text(t.welcomeTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(t.knowledgeHub),
              onTap: () {
                Navigator.pop(context);
                onOpenKnowledgeHub();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(t.settings),
              onTap: () {
                Navigator.pop(context);
                onOpenSettings();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(t.logout),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
