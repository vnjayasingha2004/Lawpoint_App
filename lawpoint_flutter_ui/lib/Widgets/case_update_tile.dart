import 'package:flutter/material.dart';
import '../Models/caseUpdate.dart';

class CaseUpdateTile extends StatelessWidget {
  const CaseUpdateTile({
    super.key,
    required this.update,
  });

  final CaseUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              update.updateText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${update.createdAt}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (update.hearingDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Text(
                    'Hearing: ${update.hearingDate}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
