import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/appointmentRepository.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Data/repositories/lockerRepository.dart';
import '../Models/document.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';

class LegalLockerScreen extends StatefulWidget {
  const LegalLockerScreen({
    super.key,
    this.sharedMode = false,
    this.embedded = false,
  });

  final bool sharedMode;
  final bool embedded;

  @override
  State<LegalLockerScreen> createState() => _LegalLockerScreenState();
}

class _LegalLockerScreenState extends State<LegalLockerScreen> {
  bool _uploading = false;
  final Set<String> _deletingIds = <String>{};

  Future<List<Lawyer>> _loadShareableLawyers() async {
    final appointments =
        await context.read<AppointmentRepository>().getMyAppointments();

    final allowedLawyerIds = appointments
        .where((a) {
          final status = a.status.toUpperCase();
          return status == 'SCHEDULED' || status == 'COMPLETED';
        })
        .map((a) => a.lawyerId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (allowedLawyerIds.isEmpty) return [];

    final lawyers = await context.read<LawyerRepository>().searchLawyers();

    final items = lawyers
        .where((l) => l.verified && allowedLawyerIds.contains(l.id))
        .toList();

    items.sort((a, b) => a.fullName.compareTo(b.fullName));
    return items;
  }

  Future<List<Lawyer>> _loadRevokableLawyers(DocumentItem doc) async {
    if (doc.sharedWithIds.isEmpty) return [];

    final lawyers = await context.read<LawyerRepository>().searchLawyers();

    final items =
        lawyers.where((l) => doc.sharedWithIds.contains(l.id)).toList();

    items.sort((a, b) => a.fullName.compareTo(b.fullName));
    return items;
  }

  Future<void> _download(DocumentItem doc) async {
    try {
      final file = await context.read<LockerRepository>().downloadDocument(doc);
      if (!mounted) return;
      showAppSnack(context, 'Downloaded to: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<List<DocumentItem>> _load() {
    return widget.sharedMode
        ? context.read<LockerRepository>().getSharedDocuments()
        : context.read<LockerRepository>().getMyDocuments();
  }

  String _friendlyCategory(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'sri_nic':
        return 'Sri Lankan NIC';
      case 'birth_certificate':
        return 'Birth certificate';
      case 'land_deed_extract':
        return 'Land deed / extract';
      case 'other_secret':
        return 'Other secret doc';
      default:
        return 'Not set';
    }
  }

  String _redactionMessage(DocumentItem doc) {
    switch (doc.redactionStatus.toUpperCase()) {
      case 'READY':
        return 'Redacted copy is ready.';
      case 'MANUAL_REQUIRED':
        return doc.manualShareApproved
            ? 'Auto-redaction needs manual review. Risky share has been approved.'
            : 'Auto-redaction needs manual review. Sharing may expose sensitive data.';
      case 'FAILED':
        return 'Auto-redaction failed. Keep this private until fixed.';
      case 'NOT_REQUIRED':
      default:
        return doc.isSecret ? 'Secret document uploaded.' : 'Normal upload.';
    }
  }

  String _reviewMessage(DocumentItem doc) {
    if (!doc.requiresPreviewBeforeShare) {
      return 'Preview review not required.';
    }
    return doc.reviewedForShare
        ? 'Blurred NIC preview reviewed and approved.'
        : 'You must preview the blurred NIC copy before sharing.';
  }

  Future<_UploadChoice?> _askUploadChoice() async {
    String classification = 'NORMAL';
    String secretCategory = 'sri_nic';

    return showDialog<_UploadChoice>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final isSecret = classification == 'SECRET';
            final pdfAllowedForCategory = secretCategory != 'sri_nic';

            return AlertDialog(
              title: const Text('Upload document'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'NORMAL',
                      groupValue: classification,
                      title: const Text('Normal document'),
                      subtitle: const Text('Uploaded normally'),
                      onChanged: (v) => setLocal(() => classification = v!),
                    ),
                    RadioListTile<String>(
                      value: 'SECRET',
                      groupValue: classification,
                      title: const Text('Secret document'),
                      subtitle: const Text(
                        'Lawyer will only get a redacted copy',
                      ),
                      onChanged: (v) => setLocal(() => classification = v!),
                    ),
                    if (isSecret) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: secretCategory,
                        decoration: const InputDecoration(
                          labelText: 'Secret category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'sri_nic',
                            child: Text('Sri Lankan NIC'),
                          ),
                          DropdownMenuItem(
                            value: 'birth_certificate',
                            child: Text('Birth certificate'),
                          ),
                          DropdownMenuItem(
                            value: 'land_deed_extract',
                            child: Text('Land deed / extract'),
                          ),
                          DropdownMenuItem(
                            value: 'other_secret',
                            child: Text('Other secret document'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setLocal(() => secretCategory = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pdfAllowedForCategory
                              ? 'Allowed secret file types: JPG / PNG / WEBP / PDF.'
                              : 'NIC secret uploads are image only: JPG / PNG / WEBP.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (secretCategory == 'sri_nic') ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sri Lankan NIC uploads must be previewed and approved before sharing.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _UploadChoice(
                        classification: classification,
                        secretCategory:
                            classification == 'SECRET' ? secretCategory : null,
                      ),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUpload() async {
    final choice = await _askUploadChoice();
    if (choice == null) return;

    final isSecret = choice.classification == 'SECRET';
    final isNicSecret = isSecret && choice.secretCategory == 'sri_nic';

    final picked = await FilePicker.platform.pickFiles(
      type: isSecret ? FileType.custom : FileType.any,
      allowedExtensions: isSecret
          ? (isNicSecret
              ? ['jpg', 'jpeg', 'png', 'webp']
              : ['jpg', 'jpeg', 'png', 'webp', 'pdf'])
          : null,
    );

    if (picked == null || picked.files.single.path == null) return;

    setState(() => _uploading = true);

    try {
      final uploaded =
          await context.read<LockerRepository>().uploadDocumentFile(
                file: File(picked.files.single.path!),
                classification: choice.classification,
                secretCategory: choice.secretCategory,
              );

      if (!mounted) return;
      setState(() {});

      if (uploaded.isSecret &&
          uploaded.redactionStatus.toUpperCase() == 'READY') {
        if (uploaded.requiresPreviewBeforeShare) {
          showAppSnack(
            context,
            'Secret NIC uploaded. Preview the blurred copy before sharing.',
          );
        } else {
          showAppSnack(
            context,
            'Secret document uploaded. Lawyers will only receive the redacted copy.',
          );
        }
      } else if (uploaded.isSecret) {
        showAppSnack(
          context,
          'Secret document uploaded privately, but redaction is not ready yet.',
          error: true,
        );
      } else {
        showAppSnack(context, 'Document uploaded.');
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool> _confirmRiskyShare(DocumentItem doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dangerous share warning'),
        content: Text(
          'Auto-redaction could not safely blur "${doc.fileName}".\n\n'
          'If you continue, the lawyer may receive the original unblurred file with sensitive data visible.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<bool> _previewAndApprove(DocumentItem doc) async {
    try {
      final bytes =
          await context.read<LockerRepository>().fetchPreviewBytes(doc.id);

      if (!mounted) return false;

      bool approved = false;

      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool confirmChecked = false;

          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('Preview blurred shared copy'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 420),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Preview could not be rendered.',
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'This is the blurred version that the lawyer will see.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: confirmChecked,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'I checked this blurred NIC preview and approve this version for sharing.',
                        ),
                        onChanged: (v) {
                          setLocal(() => confirmChecked = v == true);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: confirmChecked
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: const Text('Approve preview'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return false;

      final updated =
          await context.read<LockerRepository>().markDocumentReviewed(doc.id);

      approved = updated.reviewedForShare;

      if (!mounted) return approved;

      if (approved) {
        showAppSnack(
          context,
          'Blurred NIC preview approved. You can now share it.',
        );
      }

      setState(() {});
      return approved;
    } catch (e) {
      if (!mounted) return false;
      showAppSnack(context, e.toString(), error: true);
      return false;
    }
  }

  Future<void> _share(DocumentItem doc) async {
    bool allowRiskyShare = false;

    if (doc.requiresPreviewBeforeShare &&
        doc.redactionStatus.toUpperCase() == 'READY' &&
        !doc.reviewedForShare) {
      final approved = await _previewAndApprove(doc);
      if (!approved) return;
    }

    if (doc.isSecret &&
        doc.redactionStatus.toUpperCase() == 'MANUAL_REQUIRED') {
      final confirmed = await _confirmRiskyShare(doc);
      if (!confirmed) return;
      allowRiskyShare = true;
    }

    final lawyers = await _loadShareableLawyers();
    if (lawyers.isEmpty) {
      if (mounted) {
        showAppSnack(
          context,
          'Book an appointment first before sharing with a lawyer.',
          error: true,
        );
      }
      return;
    }

    if (!mounted) return;

    Lawyer? selected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share with lawyer'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SizedBox(
            width: 360,
            child: DropdownButtonFormField<Lawyer>(
              value: selected,
              items: lawyers
                  .map(
                    (l) => DropdownMenuItem<Lawyer>(
                      value: l,
                      child: Text(l.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setLocal(() => selected = v),
              decoration: const InputDecoration(labelText: 'Choose lawyer'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(allowRiskyShare ? 'Share anyway' : 'Share'),
          ),
        ],
      ),
    );

    if (ok != true || selected == null) return;

    try {
      await context.read<LockerRepository>().shareDocument(
            documentId: doc.id,
            lawyerId: selected!.id,
            allowRiskyShare: allowRiskyShare,
          );
      if (!mounted) return;

      showAppSnack(
        context,
        allowRiskyShare
            ? 'Document shared with warning. The lawyer may see the original file.'
            : (doc.isSecret
                ? 'Redacted copy shared with ${selected!.fullName}.'
                : 'Document shared with ${selected!.fullName}.'),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _revoke(DocumentItem doc) async {
    final lawyers = await _loadRevokableLawyers(doc);
    if (lawyers.isEmpty) {
      if (mounted) {
        showAppSnack(
          context,
          'This document is not shared with any lawyer yet.',
        );
      }
      return;
    }

    if (!mounted) return;

    Lawyer? selected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke access'),
        content: StatefulBuilder(
          builder: (context, setLocal) => SizedBox(
            width: 360,
            child: DropdownButtonFormField<Lawyer>(
              value: selected,
              items: lawyers
                  .map(
                    (l) => DropdownMenuItem<Lawyer>(
                      value: l,
                      child: Text(l.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setLocal(() => selected = v),
              decoration: const InputDecoration(labelText: 'Lawyer to revoke'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (ok != true || selected == null) return;

    try {
      await context.read<LockerRepository>().revokeDocument(
            documentId: doc.id,
            lawyerId: selected!.id,
          );
      if (!mounted) return;
      showAppSnack(context, 'Access revoked for ${selected!.fullName}.');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(DocumentItem doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document'),
        content: Text(
          doc.isSecret
              ? 'Delete "${doc.fileName}"?\n\nThis will remove the original file and the redacted copy permanently.'
              : 'Delete "${doc.fileName}" permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    setState(() => _deletingIds.add(doc.id));

    try {
      await context.read<LockerRepository>().deleteDocument(doc.id);
      if (!mounted) return;
      showAppSnack(context, 'Document deleted.');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(doc.id));
      }
    }
  }

  Color _reviewColor(DocumentItem doc) {
    if (!doc.requiresPreviewBeforeShare) return Colors.blue;
    return doc.reviewedForShare ? Colors.green : Colors.orange;
  }

  String _reviewPill(DocumentItem doc) {
    if (!doc.requiresPreviewBeforeShare) return 'No review needed';
    return doc.reviewedForShare ? 'Preview approved' : 'Review required';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sharedMode ? 'Shared documents' : 'Legal Locker'),
      ),
      floatingActionButton: widget.sharedMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
            ),
      body: FutureBuilder<List<DocumentItem>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? <DocumentItem>[];

          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: widget.sharedMode
                    ? Icons.folder_shared_outlined
                    : Icons.lock_outline_rounded,
                title: widget.sharedMode
                    ? 'No shared documents'
                    : 'No documents yet',
                message: widget.sharedMode
                    ? 'Client-shared files will appear here for authorized lawyers.'
                    : 'Upload normal docs or secret docs. Secret NIC files must be previewed before sharing.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = items[i];
              final shareAllowed = !doc.isSecret ||
                  doc.redactionStatus.toUpperCase() == 'READY' ||
                  doc.redactionStatus.toUpperCase() == 'MANUAL_REQUIRED';
              final deleting = _deletingIds.contains(doc.id);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            doc.isSecret
                                ? Icons.privacy_tip_outlined
                                : Icons.insert_drive_file_rounded,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.fileName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${doc.fileType} • ${friendlyDateTime(doc.uploadedAt)}'
                                  '${doc.sizeBytes > 0 ? ' • ${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB' : ''}',
                                ),
                                if (doc.isSecret) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                      'Category: ${_friendlyCategory(doc.secretCategory)}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    _redactionMessage(doc),
                                    style: TextStyle(
                                      color:
                                          doc.redactionStatus.toUpperCase() ==
                                                  'READY'
                                              ? Colors.green
                                              : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _reviewMessage(doc),
                                    style: TextStyle(
                                      color: _reviewColor(doc),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusPill(
                            doc.shared ? 'Shared' : 'Private',
                            color: statusColor(
                              doc.shared ? 'approved' : 'pending',
                            ),
                          ),
                          StatusPill(
                            doc.isSecret ? 'Secret' : 'Normal',
                            color:
                                doc.isSecret ? Colors.deepOrange : Colors.blue,
                          ),
                          if (doc.isSecret)
                            StatusPill(
                              doc.redactionStatus,
                              color:
                                  doc.redactionStatus.toUpperCase() == 'READY'
                                      ? Colors.green
                                      : Colors.orange,
                            ),
                          if (doc.isSecret)
                            StatusPill(
                              _reviewPill(doc),
                              color: _reviewColor(doc),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!widget.sharedMode && doc.isSecret)
                            OutlinedButton.icon(
                              onPressed:
                                  doc.redactionStatus.toUpperCase() == 'READY'
                                      ? () => _previewAndApprove(doc)
                                      : null,
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text(
                                doc.reviewedForShare
                                    ? 'Preview again'
                                    : 'Preview blurred copy',
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: deleting ? null : () => _download(doc),
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                              widget.sharedMode && doc.isSecret
                                  ? 'Download redacted'
                                  : 'Download',
                            ),
                          ),
                          if (!widget.sharedMode)
                            OutlinedButton.icon(
                              onPressed: deleting
                                  ? null
                                  : (shareAllowed ? () => _share(doc) : null),
                              icon: const Icon(Icons.share_rounded),
                              label: Text(
                                doc.requiresPreviewBeforeShare &&
                                        !doc.reviewedForShare
                                    ? 'Review to share'
                                    : 'Share',
                              ),
                            ),
                          if (!widget.sharedMode && doc.shared)
                            OutlinedButton.icon(
                              onPressed: deleting ? null : () => _revoke(doc),
                              icon: const Icon(Icons.link_off_rounded),
                              label: const Text('Revoke'),
                            ),
                          if (!widget.sharedMode)
                            OutlinedButton.icon(
                              onPressed: deleting ? null : () => _delete(doc),
                              icon: deleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _UploadChoice {
  final String classification;
  final String? secretCategory;

  const _UploadChoice({
    required this.classification,
    required this.secretCategory,
  });
}
