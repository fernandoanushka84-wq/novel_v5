import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import 'chapter_reader_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.apiService,
    required this.storyId,
    required this.title,
    required this.author,
    required this.description,
    this.coverPath = '',
  });

  final ApiService apiService;
  final int storyId;
  final String title;
  final String author;
  final String description;
  final String coverPath;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _chapters = const [];

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await widget.apiService.fetchStoryChapters(
        widget.storyId,
      );
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load chapters. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _chapters.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontFamily: 'serif', fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'by ${widget.author}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.description.isEmpty
                            ? 'This story is ready in your reader. Full chapter content can be edited from the Write tab.'
                            : widget.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                          color: const Color(0xFF4F4F4F),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Chapters',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _chapters.isEmpty
                            ? 'No chapters are available yet. Start writing or check back soon.'
                            : 'Tap a chapter to read the full story.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 4),
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.redAccent),
                          ),
                        ),
                      const SizedBox(height: 18),
                    ],
                  );
                }

                final chapter = _chapters[index - 1];
                final chapterTitle =
                    chapter['title'] as String? ?? 'Untitled chapter';
                final chapterNumber =
                    chapter['chapter_number'] as int? ?? index;
                final chapterContent = chapter['content'] as String? ?? '';
                final snippet = chapterContent.isEmpty
                    ? 'This chapter has not been added yet.'
                    : chapterContent.replaceAll('\n', ' ').trim();
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChapterReaderScreen(
                          apiService: widget.apiService,
                          title: widget.title,
                          author: widget.author,
                          coverPath: widget.coverPath,
                          chapterNumber: chapterNumber,
                          chapterTitle: chapterTitle,
                          chapterContent: chapterContent,
                          bookId: widget.storyId,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chapter $chapterNumber',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            chapterTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snippet,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Icon(Icons.chevron_right, size: 20),
                              SizedBox(width: 6),
                              Text('Read full chapter'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
