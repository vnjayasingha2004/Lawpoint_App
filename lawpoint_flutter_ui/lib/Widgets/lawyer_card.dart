import 'package:flutter/material.dart';
import 'package:lawpoint_app/gen_l10n/app_localizations.dart';
import '../Models/lawyer.dart';

class LawyerCard extends StatelessWidget {
  const LawyerCard({
    super.key,
    required this.lawyer,
    required this.onTap,
  });

  final Lawyer lawyer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                child: Text(
                  lawyer.fullName.isNotEmpty ? lawyer.fullName.trim()[0].toUpperCase() : '?',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lawyer.fullName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _VerifiedChip(isVerified: lawyer.verified),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${t.district}: ${lawyer.district}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: -8,
                      children: [
                        for (final s in lawyer.specialisations.take(3))
                          Chip(label: Text(s), visualDensity: VisualDensity.compact),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t.language}: ${lawyer.languages.join(', ')}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (lawyer.feeLkr != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fee: LKR ${lawyer.feeLkr!.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isVerified ? t.verified : t.unverified,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isVerified ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
