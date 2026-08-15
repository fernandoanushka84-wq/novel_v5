import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Explore shows admin hashtags (#tags), not genres.
/// Tap a tag → books with that hashtag → tap book → StoryDetailScreen.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.topics = const [],
    required this.apiService,
  });

  final List<ExploreTopicModel> topics;
  final ApiService apiService;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _loading = true;
  List<_TagItem> _tags = const [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.apiService.fetchTags();
      final items = <_TagItem>[];
      for (final row in rows) {
        final name = (row['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final count = (row['book_count'] as num?)?.toInt() ??
            (row['topic_count'] as num?)?.toInt() ??
            0;
        items.add(_TagItem(name: name, bookCount: count));
      }
      if (items.isNotEmpty && items.every((t) => t.bookCount == 0)) {
        for (var i = 0; i < items.length; i++) {
          try {
            final books =
                await widget.apiService.fetchBooksByTag(items[i].name);
            items[i] = _TagItem(name: items[i].name, bookCount: books.length);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      if (items.isEmpty && widget.topics.isNotEmpty) {
        setState(() {
          _tags = widget.topics
              .map((t) => _TagItem(name: t.name, bookCount: t.topicCount))
              .toList();
          _loading = false;
        });
        return;
      }
      setState(() {
        _tags = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tags = widget.topics
            .map((t) => _TagItem(name: t.name, bookCount: t.topicCount))
            .toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Explore',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hashtags yet. Admin can add tags from the panel.',
                      style: TextStyle(color: AppTheme.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTags,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _tags.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final tag = _tags[index];
                      final label =
                          tag.name.startsWith('#') ? tag.name : '#${tag.name}';
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _TagBooksScreen(
                                tag: tag.name.replaceFirst('#', ''),
                                apiService: widget.apiService,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ),
                              Text(
                                tag.bookCount > 0
                                    ? '${tag.bookCount} ${tag.bookCount == 1 ? 'book' : 'books'}'
                                    : '0 books',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.muted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.muted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TagItem {
  const _TagItem({required this.name, required this.bookCount});
  final String name;
  final int bookCount;
}

class _TagBooksScreen extends StatefulWidget {
  const _TagBooksScreen({required this.tag, required this.apiService});

  final String tag;
  final ApiService apiService;

  @override
  State<_TagBooksScreen> createState() => _TagBooksScreenState();
}

class _TagBooksScreenState extends State<_TagBooksScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _stories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await widget.apiService.fetchBooksByTag(widget.tag);
    if (!mounted) return;
    setState(() {
      _stories = results;
      _loading = false;
    });
  }

  void _openBook(Map<String, dynamic> story) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel.fromMap(story),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.tag.startsWith('#') ? widget.tag : '#${widget.tag}';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty
              ? Center(
                  child: Text(
                    'No stories found for $title',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    final cover = (story['cover_path'] as String? ?? '');
                    final coverUrl = cover.isNotEmpty
                        ? widget.apiService.resolveAssetUrl(cover)
                        : null;
                    return ListTile(
                      onTap: () => _openBook(story),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                      leading: coverUrl == null
                          ? Container(
                              width: 44,
                              height: 64,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.menu_book, size: 20),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                coverUrl,
                                width: 44,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 44,
                                  height: 64,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ),
                      title: Text(
                        story['title']?.toString() ?? 'Untitled',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(story['author']?.toString() ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
    );
  }
}
