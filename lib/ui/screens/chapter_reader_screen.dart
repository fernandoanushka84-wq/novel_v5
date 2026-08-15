import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/services/api_service.dart';

/// Inkitt-style chapter reader: cover at start, mid-chapter ads,
/// Next Chapter ads, themes, reactions, native share, scroll-to-top.
class ChapterReaderScreen extends StatefulWidget {
  const ChapterReaderScreen({
    super.key,
    required this.apiService,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.chapterContent,
    this.bookId,
    this.tags = const [],
    this.authorUserId,
    this.chapters = const [],
    this.initialChapterIndex = 0,
  });

  final ApiService apiService;
  final String title;
  final String author;
  final String coverPath;
  final int chapterNumber;
  final String chapterTitle;
  final String chapterContent;
  final int? bookId;
  final List<String> tags;
  final int? authorUserId;
  final List<Map<String, dynamic>> chapters;
  final int initialChapterIndex;

  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

enum _ReaderTheme { white, eggshell, nightowl }

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late int _chapterIndex;
  late List<Map<String, dynamic>> _chapters;
  late String _chapterTitle;
  late String _chapterContent;
  late int _chapterNumber;

  _ReaderTheme _theme = _ReaderTheme.white;
  double _fontSize = 17;
  bool _showThemePanel = false;
  final Set<String> _selectedReactions = {};
  final Map<String, int> _reactionCounts = {};
  bool _reactionsLoading = false;
  bool _liked = false;
  int _likeCount = 0;
  final ScrollController _scrollController = ScrollController();

  static const _reactionOptions = <List<String>>[
    ['❤️', 'Love this'],
    ['😂', 'Funny'],
    ['🌶️', 'Spicy'],
    ['😨', 'Suspenseful'],
    ['😢', 'Emotional'],
    ['🤔', 'Profound'],
    ['🥰', 'Heartwarming'],
    ['😲', 'Shocking'],
    ['✍️', 'Good Writing'],
    ['📖', 'Compelling Plot'],
    ['🎭', 'Great Character'],
    ['💬', 'Strong Dialog'],
  ];

  @override
  void initState() {
    super.initState();
    _chapters = List<Map<String, dynamic>>.from(widget.chapters);
    _loadLikeState();
    _chapterIndex = widget.initialChapterIndex.clamp(
      0,
      _chapters.isEmpty ? 0 : _chapters.length - 1,
    );
    if (_chapters.isNotEmpty) {
      _applyChapter(_chapters[_chapterIndex]);
    } else {
      _chapterTitle = widget.chapterTitle;
      _chapterContent = widget.chapterContent;
      _chapterNumber = widget.chapterNumber;
    }
    _loadChaptersIfNeeded();
    _loadReactions();
    _persistProgress();
  }

  Future<void> _persistProgress() async {
    final id = widget.bookId;
    if (id == null) return;
    try {
      await widget.apiService.saveReadingProgress(
        bookId: id,
        chapterNumber: _chapterNumber,
        progressPercent: 0,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChaptersIfNeeded() async {
    if (_chapters.isNotEmpty || widget.bookId == null) return;
    try {
      final list = await widget.apiService.fetchStoryChapters(widget.bookId!);
      if (!mounted || list.isEmpty) return;
      setState(() {
        _chapters = list;
        final idx = list.indexWhere(
          (c) => (c['chapter_number'] as num?)?.toInt() == widget.chapterNumber,
        );
        _chapterIndex = idx >= 0 ? idx : 0;
        _applyChapter(_chapters[_chapterIndex]);
      });
    } catch (_) {}
  }

  void _applyChapter(Map<String, dynamic> chapter) {
    _chapterTitle = chapter['title'] as String? ?? 'Untitled';
    _chapterContent = chapter['content'] as String? ?? '';
    _chapterNumber =
        (chapter['chapter_number'] as num?)?.toInt() ?? (_chapterIndex + 1);
    _selectedReactions.clear();
    _reactionCounts.clear();
    _loadReactions();
  }

  Color get _bg {
    switch (_theme) {
      case _ReaderTheme.white:
        return Colors.white;
      case _ReaderTheme.eggshell:
        return const Color(0xFFF5F0E6);
      case _ReaderTheme.nightowl:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get _fg =>
      _theme == _ReaderTheme.nightowl ? Colors.white : Colors.black87;

  Color get _muted =>
      _theme == _ReaderTheme.nightowl ? Colors.white60 : Colors.black54;

  Future<void> _goNext() async {
    await _persistProgress();
    if (_chapterIndex >= _chapters.length - 1) return;
    setState(() {
      _chapterIndex++;
      _applyChapter(_chapters[_chapterIndex]);
    });
    // Scroll to top of the new chapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _openChapterList() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final coverUrl = widget.coverPath.isEmpty
            ? null
            : widget.apiService.resolveAssetUrl(widget.coverPath);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (coverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            coverUrl,
                            width: 48,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.menu_book, size: 40),
                          ),
                        )
                      else
                        const Icon(Icons.menu_book, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'By ${widget.author}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final bookId = widget.bookId;
                          if (bookId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report submitted. Thank you.')),
                            );
                            return;
                          }
                          try {
                            final res = await widget.apiService.reportBook(bookId);
                            final flagged = res['flagged_for_admin'] == true;
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  flagged
                                      ? 'Report recorded. Story flagged for admin review (3+ reports).'
                                      : 'Report submitted. Thank you.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not report: $e')),
                            );
                          }
                        },
                        child: const Text(
                          'Report Story',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _chapters.isEmpty ? 1 : _chapters.length,
                    itemBuilder: (context, index) {
                      if (_chapters.isEmpty) {
                        return ListTile(
                          title: Text(
                            'Chapter $_chapterNumber: $_chapterTitle',
                          ),
                          selected: true,
                        );
                      }
                      final c = _chapters[index];
                      final chapterNo =
                          (c['chapter_number'] as num?)?.toInt() ?? index + 1;
                      final title = c['title'] as String? ?? 'Untitled';
                      final selected = index == _chapterIndex;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: const Color(0xFFFFF0EE),
                        title: Text(
                          'Chapter $chapterNo: $title',
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _chapterIndex = index;
                            _applyChapter(c);
                          });
                          Navigator.pop(ctx);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(0);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _share() async {
    final text =
        'Read "${widget.title}" by ${widget.author} — Chapter $_chapterNumber: $_chapterTitle\n'
        'Read free on our app.';
    try {
      await Share.share(text, subject: widget.title);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story link copied — share it anywhere')),
      );
    }
  }

  Future<void> _loadLikeState() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    try {
      final res = await widget.apiService.fetchBookLike(bookId);
      if (!mounted) return;
      setState(() {
        _liked = (res['liked'] as bool?) ?? false;
        _likeCount = (res['likes_count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final bookId = widget.bookId;
    if (bookId == null) {
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
        if (_likeCount < 0) _likeCount = 0;
      });
      return;
    }
    try {
      final res = _liked
          ? await widget.apiService.unlikeBook(bookId)
          : await widget.apiService.likeBook(bookId);
      if (!mounted) return;
      setState(() {
        _liked = (res['liked'] as bool?) ?? !_liked;
        _likeCount = (res['likes_count'] as num?)?.toInt() ?? _likeCount;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to like. One like per account.')),
      );
    }
  }

  Widget _buildAdBanner({required String label}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: _theme == _ReaderTheme.nightowl
            ? Colors.white10
            : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _theme == _ReaderTheme.nightowl
              ? Colors.white24
              : const Color(0xFFD0D7DE),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Advertisement',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sponsored content',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Split chapter content roughly in half for mid-chapter ad placement.
  List<String> _contentParts() {
    final text = _chapterContent.trim();
    if (text.isEmpty) return ['', ''];
    final mid = text.length ~/ 2;
    final searchStart = (mid - 200).clamp(0, text.length);
    final searchEnd = (mid + 200).clamp(0, text.length);
    final window = text.substring(searchStart, searchEnd);
    final paraBreak = window.indexOf('\n\n');
    if (paraBreak >= 0) {
      final splitAt = searchStart + paraBreak;
      return [text.substring(0, splitAt).trim(), text.substring(splitAt).trim()];
    }
    final space = text.lastIndexOf(' ', mid);
    if (space > 0) {
      return [text.substring(0, space).trim(), text.substring(space).trim()];
    }
    return [text, ''];
  }

  @override
  Widget build(BuildContext context) {
    final total = _chapters.isEmpty ? 1 : _chapters.length;
    final pageLabel = '${_chapterIndex + 1}/$total';
    final hasNext =
        _chapters.isNotEmpty && _chapterIndex < _chapters.length - 1;
    final parts = _contentParts();
    final coverUrl = widget.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(widget.coverPath);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _fg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          pageLabel,
          style: TextStyle(color: _muted, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: _muted),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(widget.title),
                  content: Text(
                    'By ${widget.author}\n\nChapter $_chapterNumber: $_chapterTitle',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Chapter cover (book cover at start of every chapter)
                if (coverUrl != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl,
                        width: 140,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 140,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.menu_book, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Center(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _fg,
                      fontSize: _fontSize + 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'By ${widget.author}',
                    style: TextStyle(color: _muted, fontSize: _fontSize - 2),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '〜〜〜〜〜〜〜〜',
                    style: TextStyle(color: _muted, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _chapterTitle.toUpperCase().contains('CHAPTER') ||
                          _chapterTitle.toUpperCase().contains('PROLOGUE')
                      ? _chapterTitle
                      : 'CHAPTER $_chapterNumber: $_chapterTitle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _fg,
                    fontSize: _fontSize + 1,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                // Content protection: discourage select/copy (deterrent only)
                SelectionContainer.disabled(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // First half of content
                Text(
                  parts[0].isEmpty && parts[1].isEmpty
                      ? 'This chapter has not been written yet.'
                      : parts[0],
                  style: TextStyle(
                    color: _fg,
                    fontSize: _fontSize,
                    height: 1.75,
                  ),
                ),
                // Mid-chapter advertisement
                if (parts[0].isNotEmpty && parts[1].isNotEmpty)
                  _buildAdBanner(
                    label: 'Discover more stories you\'ll love',
                  ),
                // Second half of content
                if (parts[1].isNotEmpty)
                  Text(
                    parts[1],
                    style: TextStyle(
                      color: _fg,
                      fontSize: _fontSize,
                      height: 1.75,
                    ),
                  ),
                ],
                  ),
                ),
                const SizedBox(height: 24),
                // Ad near Next Chapter button
                if (hasNext)
                  _buildAdBanner(
                    label: 'Continue reading more free stories',
                  ),
                if (hasNext)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Next Chapter',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Let ${widget.author} know what you thought about this chapter!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Inkitt-style reaction grid (3 columns, compact)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reactionOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final opt = _reactionOptions[index];
                    final emoji = opt[0];
                    final label = opt[1];
                    final selected = _selectedReactions.contains(label);
                    return GestureDetector(
                      onTap: () => _toggleReaction(label),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE8F0FE)
                                  : (_theme == _ReaderTheme.nightowl
                                      ? Colors.white12
                                      : const Color(0xFFF3F4F6)),
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: const Color(0xFF1A73E8),
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: _theme == _ReaderTheme.nightowl
                                          ? Colors.white24
                                          : const Color(0xFFE5E7EB),
                                    ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF1A73E8)
                                  : _muted,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if ((_reactionCounts[label] ?? 0) > 0)
                            Text(
                              '${_reactionCounts[label]}',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? const Color(0xFF1A73E8)
                                    : _muted,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (_selectedReactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_selectedReactions.length} reaction${_selectedReactions.length == 1 ? '' : 's'} selected',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_showThemePanel) _buildThemePanel(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildThemePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: _muted.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _themeChip(
                'White',
                _ReaderTheme.white,
                Colors.white,
                Colors.black,
              ),
              _themeChip(
                'Eggshell',
                _ReaderTheme.eggshell,
                const Color(0xFFF5F0E6),
                Colors.black87,
              ),
              _themeChip(
                'Nightowl',
                _ReaderTheme.nightowl,
                const Color(0xFF1A1A1A),
                Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Font size', style: TextStyle(color: _muted, fontSize: 12)),
          Row(
            children: [
              Text('A−', style: TextStyle(color: _fg, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14,
                  max: 24,
                  divisions: 10,
                  activeColor: const Color(0xFFE85D4C),
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              Text('A+', style: TextStyle(color: _fg, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeChip(
    String label,
    _ReaderTheme value,
    Color bg,
    Color fg,
  ) {
    final selected = _theme == value;
    return GestureDetector(
      onTap: () => setState(() => _theme = value),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    selected ? const Color(0xFFE85D4C) : Colors.grey.shade400,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              'A',
              style: TextStyle(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  String _relativeTime(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _loadReactions() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    setState(() => _reactionsLoading = true);
    try {
      final data = await widget.apiService.fetchChapterReactions(
        bookId: bookId,
        chapterNumber: _chapterNumber,
      );
      final countsRaw = data['counts'];
      final mineRaw = data['mine'];
      final counts = <String, int>{};
      if (countsRaw is Map) {
        countsRaw.forEach((k, v) {
          counts[k.toString()] = int.tryParse(v.toString()) ?? 0;
        });
      }
      final mine = <String>{};
      if (mineRaw is List) {
        for (final e in mineRaw) {
          mine.add(e.toString());
        }
      }
      if (!mounted) return;
      setState(() {
        _reactionCounts
          ..clear()
          ..addAll(counts);
        _selectedReactions
          ..clear()
          ..addAll(mine);
        _reactionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reactionsLoading = false);
    }
  }

  Future<void> _toggleReaction(String label) async {
    final bookId = widget.bookId;
    if (bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to react to chapters')),
      );
      return;
    }
    // Optimistic UI
    final wasSelected = _selectedReactions.contains(label);
    setState(() {
      if (wasSelected) {
        _selectedReactions.remove(label);
        _reactionCounts[label] = ((_reactionCounts[label] ?? 1) - 1).clamp(0, 999999);
      } else {
        _selectedReactions.add(label);
        _reactionCounts[label] = (_reactionCounts[label] ?? 0) + 1;
      }
    });
    try {
      final res = await widget.apiService.toggleChapterReaction(
        bookId: bookId,
        chapterNumber: _chapterNumber,
        label: label,
      );
      if (!mounted) return;
      final selected = res['selected'] == true;
      final count = int.tryParse('${res['count'] ?? 0}') ?? 0;
      setState(() {
        if (selected) {
          _selectedReactions.add(label);
        } else {
          _selectedReactions.remove(label);
        }
        _reactionCounts[label] = count;
      });
    } catch (e) {
      // roll back
      if (!mounted) return;
      setState(() {
        if (wasSelected) {
          _selectedReactions.add(label);
          _reactionCounts[label] = (_reactionCounts[label] ?? 0) + 1;
        } else {
          _selectedReactions.remove(label);
          _reactionCounts[label] =
              ((_reactionCounts[label] ?? 1) - 1).clamp(0, 999999);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reaction: $e')),
      );
    }
  }

  Future<void> _openCommentsSheet() async {
    final bookId = widget.bookId;
    if (bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a published story to view comments')),
      );
      return;
    }

    final controller = TextEditingController();
    var comments = <Map<String, dynamic>>[];
    var loading = true;
    var posting = false;
    String? error;

    Future<void> loadComments(void Function(void Function()) setModal) async {
      setModal(() {
        loading = true;
        error = null;
      });
      try {
        final items = await widget.apiService.fetchChapterComments(
          bookId: bookId,
          chapterNumber: _chapterNumber,
        );
        setModal(() {
          comments = items;
          loading = false;
        });
      } catch (e) {
        setModal(() {
          loading = false;
          error = 'Could not load comments';
        });
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var startedLoad = false;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            if (!startedLoad) {
              startedLoad = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadComments(setModal);
              });
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.65,
                maxChildSize: 0.92,
                minChildSize: 0.4,
                builder: (_, scrollCtrl) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                loading
                                    ? 'Comments'
                                    : 'Comments (${comments.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: posting
                                  ? null
                                  : () => loadComments(setModal),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : error != null
                                ? Center(
                                    child: Text(
                                      error!,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : comments.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No comments yet — be the first!',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        controller: scrollCtrl,
                                        padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 12,
                                        ),
                                        itemCount: comments.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 16),
                                        itemBuilder: (_, i) {
                                          final c = comments[i];
                                          final name = (c['display_name'] ??
                                                  c['username'] ??
                                                  'Reader')
                                              .toString();
                                          final body =
                                              (c['body'] ?? '').toString();
                                          final when = _relativeTime(
                                            (c['created_at'] ?? '').toString(),
                                          );
                                          final photo =
                                              (c['photo_url'] ?? '').toString();
                                          final letter = name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'R';
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    const Color(0xFFE8EEF9),
                                                backgroundImage: photo.isNotEmpty
                                                    ? NetworkImage(
                                                        widget.apiService
                                                            .resolveAssetUrl(
                                                          photo,
                                                        ),
                                                      )
                                                    : null,
                                                child: photo.isEmpty
                                                    ? Text(
                                                        letter,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF1A73E8,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (when.isNotEmpty) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            when,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      body,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                enabled: !posting,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment…',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: posting
                                    ? null
                                    : (_) async {
                                        // handled by send button path below
                                      },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: posting
                                  ? null
                                  : () async {
                                      final text = controller.text.trim();
                                      if (text.isEmpty) return;
                                      setModal(() => posting = true);
                                      try {
                                        final item = await widget.apiService
                                            .postChapterComment(
                                          bookId: bookId,
                                          chapterNumber: _chapterNumber,
                                          body: text,
                                        );
                                        controller.clear();
                                        setModal(() {
                                          comments = [item, ...comments];
                                          posting = false;
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('Comment posted'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModal(() => posting = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Could not post: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: posting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: Color(0xFF1A73E8),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: _bg,
          border: Border(
            top: BorderSide(color: _muted.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _barItem(
              icon: Icons.text_fields,
              label: 'Theme',
              onTap: () =>
                  setState(() => _showThemePanel = !_showThemePanel),
            ),
            _barItem(
              icon: _liked ? Icons.favorite : Icons.favorite_border,
              label: _likeCount > 0 ? '$_likeCount Likes' : 'Like',
              color: _liked ? Colors.red : null,
              onTap: _toggleLike,
            ),
            _barItem(
              icon: Icons.chat_bubble_outline,
              label: 'Comments',
              onTap: _openCommentsSheet,
            ),
            _barItem(
              icon: Icons.ios_share,
              label: 'Share',
              onTap: _share,
            ),
            _barItem(
              icon: Icons.menu,
              label: 'Chapter',
              onTap: _openChapterList,
            ),
          ],
        ),
      ),
    );
  }

  Widget _barItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? _muted),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color ?? _muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
