import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/lawyer_form_options.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';

class LawyerProfileEditScreen extends StatefulWidget {
  const LawyerProfileEditScreen({super.key});

  @override
  State<LawyerProfileEditScreen> createState() =>
      _LawyerProfileEditScreenState();
}

class _LawyerProfileEditScreenState extends State<LawyerProfileEditScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _fees = TextEditingController();
  final _specs = TextEditingController();

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedDistricts = {};

  bool _saving = false;
  Lawyer? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context.read<LawyerRepository>().getMyLawyerProfile();
    if (!mounted || profile == null) return;

    setState(() {
      _profile = profile;
      _selectedLanguages
        ..clear()
        ..addAll(normalizeSelectedValues(profile.languages));
      _selectedDistricts
        ..clear()
        ..addAll(splitMultiSelectText(profile.district));
    });

    _name.text = profile.fullName;
    _bio.text = profile.bio ?? '';
    _fees.text = profile.feeLkr?.toStringAsFixed(0) ?? '';
    _specs.text = profile.specialisations.join(', ');
  }

  List<String> _split(String text) =>
      text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (_selectedLanguages.isEmpty) {
      showAppSnack(context, 'Select at least one language.', error: true);
      return;
    }

    if (_selectedDistricts.isEmpty) {
      showAppSnack(context, 'Select at least one district.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await context.read<LawyerRepository>().updateMyLawyerProfile(
            fullName: _name.text.trim(),
            district: joinMultiSelectText(_selectedDistricts),
            bio: _bio.text.trim(),
            feesLkr: double.tryParse(_fees.text.trim()),
            languages: normalizeSelectedValues(_selectedLanguages),
            specializations: _split(_specs.text),
          );

      if (!mounted) return;
      showAppSnack(context, 'Profile updated.');
      Navigator.of(context).pop();
    } catch (e) {
      showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _fees.dispose();
    _specs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fees,
              decoration: const InputDecoration(
                labelText: 'Consultation fee (LKR)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _specs,
              decoration: const InputDecoration(
                labelText: 'Specializations (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              decoration: const InputDecoration(labelText: 'Bio'),
              minLines: 4,
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              title: 'Languages',
              subtitle: 'Select every language you can consult in.',
              options: lawyerLanguageOptions,
              selected: _selectedLanguages,
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              title: 'Practice districts',
              subtitle: 'Select one or more districts.',
              options: sriLankanDistricts,
              selected: _selectedDistricts,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
