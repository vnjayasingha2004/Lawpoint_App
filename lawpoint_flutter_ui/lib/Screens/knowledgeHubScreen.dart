import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/knowledgeRepository.dart';
import '../Models/knowledgeArticle.dart';
import '../Widgets/ui.dart';

class KnowledgeHubScreen extends StatefulWidget {
  const KnowledgeHubScreen({super.key});

  @override
  State<KnowledgeHubScreen> createState() => _KnowledgeHubScreenState();
}

class _KnowledgeHubScreenState extends State<KnowledgeHubScreen> {
  final _query = TextEditingController();
  String _language = 'en';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<List<KnowledgeArticle>> _load() {
    return context.read<KnowledgeRepository>().getArticles(query: _query.text.trim(), languageCode: _language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Trilingual legal articles',
            subtitle: 'Search by topic and switch between English, Sinhala, and Tamil content where available.',
            child: Column(
              children: [
                TextField(controller: _query, decoration: const InputDecoration(labelText: 'Search topic or keyword')),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('EN')),
                    ButtonSegment(value: 'si', label: Text('SI')),
                    ButtonSegment(value: 'ta', label: Text('TA')),
                  ],
                  selected: {_language},
                  onSelectionChanged: (set) => setState(() => _language = set.first),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.search_rounded), label: const Text('Search articles')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<KnowledgeArticle>>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              }
              final items = snapshot.data ?? const [];
              if (items.isEmpty) {
                return const EmptyStateCard(icon: Icons.menu_book_rounded, title: 'No articles found', message: 'Try a broader keyword or another language.');
              }
              return Column(
                children: items.map((article) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(article.title),
                    subtitle: Text('${article.topic} • ${article.language.toUpperCase()}'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ArticleDetailScreen(article: article))),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArticleDetailScreen extends StatelessWidget {
  const _ArticleDetailScreen({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: article.title,
            subtitle: '${article.topic} • ${article.language.toUpperCase()}',
            child: Text(article.content.isEmpty ? 'No article body available.' : article.content),
          ),
        ],
      ),
    );
  }
}
