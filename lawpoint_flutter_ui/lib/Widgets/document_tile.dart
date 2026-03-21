import 'package:flutter/material.dart';
import '../Models/document.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    this.onTap,
  });

  final DocumentItem document;
  final VoidCallback? onTap;

  IconData _iconForType(String mime) {
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('image')) return Icons.image_rounded;
    if (mime.contains('word')) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(_iconForType(document.fileType), color: theme.colorScheme.primary),
      title: Text(document.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        document.shared ? 'Shared with lawyer' : 'Private',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
