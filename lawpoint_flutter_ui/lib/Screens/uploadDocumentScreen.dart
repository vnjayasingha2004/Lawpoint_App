import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lawpoint_app/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/lockerRepository.dart';
import '../Widgets/primary_button.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  PlatformFile? _picked;
  bool _loading = false;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    setState(() => _picked = res.files.first);
  }

  Future<void> _upload() async {
    final t = AppLocalizations.of(context)!;

    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.pickFile} first')),
      );
      return;
    }

    setState(() => _loading = true);
    final repo = context.read<LockerRepository>();

    try {
      if (!kIsWeb && _picked!.path != null) {
        await repo.uploadDocumentFile(file: File(_picked!.path!));
      } else {
        final bytes = _picked!.bytes;
        if (bytes == null) throw Exception('No file bytes');
        await repo.uploadDocumentBytes(fileName: _picked!.name, bytes: bytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploaded')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.uploadDocument)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(_picked?.name ?? t.pickFile),
                  subtitle: Text(_picked == null ? 'No file selected' : '${(_picked!.size / 1024).toStringAsFixed(1)} KB'),
                  trailing: TextButton(onPressed: _pick, child: Text(t.pickFile)),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: t.submit,
                icon: Icons.cloud_upload_rounded,
                isLoading: _loading,
                onPressed: _loading ? null : _upload,
              ),
              const SizedBox(height: 10),
              Text(
                'Security tip: You can upload via signed URL + server-side encryption (AES-256 at rest).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
