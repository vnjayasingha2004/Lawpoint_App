import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/lawyer_form_options.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';
import 'lawyerProfileScreen.dart';

class LawyerSearchScreen extends StatefulWidget {
  const LawyerSearchScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LawyerSearchScreen> createState() => _LawyerSearchScreenState();
}

class _LawyerSearchScreenState extends State<LawyerSearchScreen> {
  final _query = TextEditingController();
  final _specialisation = TextEditingController();

  String? _selectedDistrict;
  String? _selectedLanguage;

  @override
  void dispose() {
    _query.dispose();
    _specialisation.dispose();
    super.dispose();
  }

  Future<List<Lawyer>> _load() {
    return context.read<LawyerRepository>().searchLawyers(
          query: _query.text.trim(),
          district: _selectedDistrict,
          language: _selectedLanguage,
          specialisation: _specialisation.text.trim(),
        );
  }

  void _clearFilters() {
    _query.clear();
    _specialisation.clear();
    _selectedDistrict = null;
    _selectedLanguage = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final child = RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Search lawyers',
            subtitle:
                'Filter by specialization, Sri Lankan district, and language.',
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    labelText: 'Keyword or lawyer name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _specialisation,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDistrict,
                        decoration: const InputDecoration(
                          labelText: 'District',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All districts'),
                          ),
                          ...sriLankanDistricts.map(
                            (district) => DropdownMenuItem<String>(
                              value: district,
                              child: Text(district),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedDistrict = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All languages'),
                          ),
                          ...lawyerLanguageOptions.map(
                            (language) => DropdownMenuItem<String>(
                              value: language,
                              child: Text(language),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedLanguage = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_rounded),
                        label: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Lawyer>>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  title: 'No lawyers found',
                  message:
                      'Try broader search terms or remove one of the filters.',
                );
              }

              return Column(
                children: items
                    .map(
                      (lawyer) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              lawyer.fullName.isNotEmpty
                                  ? lawyer.fullName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(lawyer.fullName),
                          subtitle: Text(
                            '${lawyer.specialisations.join(', ')}\n'
                            '${displayMultiSelectText(lawyer.district)} • ${lawyer.languages.join(', ')}',
                          ),
                          isThreeLine: true,
                          trailing: lawyer.verified
                              ? const StatusPill('Verified')
                              : const StatusPill('Pending'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LawyerProfileScreen(lawyerId: lawyer.id),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Find Lawyers')),
      body: child,
    );
  }
}
