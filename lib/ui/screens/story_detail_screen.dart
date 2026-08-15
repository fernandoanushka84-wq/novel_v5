import 'package:flutter/material.dart';

import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'profile_screen.dart';
import 'chapter_reader_screen.dart';

/// Story detail page modeled after the Inkitt video:
/// centered cover, title, stats (Chapters / Last Updated / Reviews),
/// summary + Read More, Likes / Save / Reviews row, genres, tags,
/// author + Follow, chapter list, sticky green Read Now.
class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({
    super.key,
    required this.book,
    required this.apiService,
  });

  final BookDetailModel book;
  final ApiService apiService;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late BookDetailModel _book;
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _loadingChapters = true;
  bool _summaryExpanded = false;
  List<Map<String, dynamic>> _chapters = const [];
  List<String> _tags = const [];
  List<Map<String, dynamic>> _reviews = const [];
  bool _loadingReviews = true;
  String? _error;
  int _likesCount = 0;
  bool _liked = false;
  bool _likeBusy = false;
  List<Map<String, dynamic>> _authorStories = const [];
  List<Map<String, dynamic>> _youMayAlsoLike = const [];

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _tags = List<String>.from(widget.book.tags);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingChapters = true;
      _error = null;
    });
    try {
      final detail = await widget.apiService.fetchPublicBook(_book.id);
      if (detail != null && mounted) {
        setState(() {
          _book = BookDetailModel.fromMap(detail);
          _tags = List<String>.from(_book.tags);
          _likesCount = (detail['likes_count'] as num?)?.toInt() ??
              (detail['likes'] as num?)?.toInt() ??
              0;
        });
      }
      final chapters = await widget.apiService.fetchStoryChapters(_book.id);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
      final aid = _book.authorUserId;
      if (aid != null) {
        try {
          final following = await widget.apiService.fetchAuthorFollowing(aid);
          if (mounted) setState(() => _isFollowing = following);
        } catch (_) {}
        try {
          final others = await widget.apiService.fetchAuthorBooks(
            aid,
            excludeBookId: _book.id,
          );
          if (mounted) setState(() => _authorStories = others);
        } catch (_) {}
      }
      final reviews = await widget.apiService.fetchBookReviews(_book.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }


      try {
        final likeState = await widget.apiService.fetchBookLike(_book.id);
        if (mounted) {
          setState(() {
            _liked = (likeState['liked'] as bool?) ?? false;
            final c = (likeState['likes_count'] as num?)?.toInt();
            if (c != null) _likesCount = c;
          });
        }
      } catch (_) {}
      // More Stories by Author + You May Also Like (loaded above via aid)
      // Related by first tag or genre
      try {
        List<Map<String, dynamic>> related = [];
        if (_tags.isNotEmpty) {
          related = await widget.apiService.fetchBooksByTag(_tags.first);
        }
        if (related.isEmpty && _book.genre.isNotEmpty) {
          // fallback: search by genre via bootstrap-style or tag
          related = await widget.apiService.fetchBooksByTag(_book.genre);
        }
        related = related.where((b) => (b['id'] as num?)?.toInt() != _book.id).take(12).toList();
        if (mounted) setState(() => _youMayAlsoLike = related);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingChapters = false;
          _loadingReviews = false;
          _error = 'Unable to load story details.';
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final aid = _book.authorUserId;
    if (aid == null || _loadingFollow) return;
    setState(() => _loadingFollow = true);
    try {
      if (_isFollowing) {
        await widget.apiService.unfollowAuthor(aid);
      } else {
        await widget.apiService.followAuthor(aid);
      }
      if (!mounted) return;
      setState(() => _isFollowing = !_isFollowing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to follow authors')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  Future<void> _openReadingListPicker() async {
    try {
      var lists = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      final choice = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Save to reading list',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Create new list'),
                  onTap: () =>
                      Navigator.pop(ctx, <String, dynamic>{'_create': true}),
                ),
                if (lists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No lists yet — create one above.'),
                  ),
                ...lists.map((list) {
                  final name = list['name'] as String? ?? 'List';
                  return ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(name),
                    onTap: () => Navigator.pop(ctx, list),
                  );
                }),
              ],
            ),
          );
        },
      );
      if (choice == null) return;

      if (choice['_create'] == true) {
        final nameCtrl = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Create reading list'),
            content: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'List name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, nameCtrl.text.trim()),
                child: const Text('Create'),
              ),
            ],
          ),
        );
        if (name == null || name.isEmpty) return;
        final created = await widget.apiService.createReadingList({
          'name': name,
          'story_count': 0,
          'cover_path': '',
          'sort_order': lists.length + 1,
        });
        var newId = (created['id'] as num?)?.toInt() ?? 0;
        if (newId == 0) {
          lists = await widget.apiService.fetchReadingLists();
          for (final l in lists) {
            if ((l['name'] as String?) == name) {
              newId = (l['id'] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }
        if (newId != 0) {
          await widget.apiService.addReadingListItem(newId, _book.id);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newId != 0
                  ? 'Created "$name" and saved this story'
                  : 'Created "$name". Open Library to confirm.',
            ),
          ),
        );
        return;
      }

      final listId = (choice['id'] as num?)?.toInt() ?? 0;
      if (listId == 0) return;
      await widget.apiService.addReadingListItem(listId, _book.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${choice['name'] ?? 'reading list'}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('401') || e.toString().contains('403')
                ? 'Please sign in to use reading lists'
                : 'Could not save to reading list',
          ),
        ),
      );
    }
  }

  void _openChapter(Map<String, dynamic> chapter, {int? index}) {
    final chapterTitle = chapter['title'] as String? ?? 'Untitled chapter';
    final chapterNumber = (chapter['chapter_number'] as num?)?.toInt() ?? 1;
    final chapterContent = chapter['content'] as String? ?? '';
    final idx = index ??
        _chapters.indexWhere(
          (c) =>
              identical(c, chapter) ||
              ((c['chapter_number'] as num?)?.toInt() == chapterNumber &&
                  (c['title'] as String?) == chapterTitle),
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          apiService: widget.apiService,
          title: _book.title,
          author: _book.author,
          coverPath: _book.coverPath,
          chapterNumber: chapterNumber,
          chapterTitle: chapterTitle,
          chapterContent: chapterContent,
          bookId: _book.id,
          tags: _tags,
          authorUserId: _book.authorUserId,
          chapters: _chapters,
          initialChapterIndex: idx < 0 ? 0 : idx,
        ),
      ),
    );
  }

  Future<void> _readNow() async {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chapters available yet')),
      );
      return;
    }
    // Track as currently reading in library (Current Reads tab)
    try {
      await widget.apiService.addLibraryEntry({
        'book_id': _book.id,
        'reading_status': 'Reading',
        'updated_text': 'Just started',
        'chapters': _chapters.length,
        'primary_genre': _book.genre,
        'secondary_genre': '',
        'sort_order': 0,
      });
    } catch (_) {
      // ignore if already in library or not signed in
    }
    if (!mounted) return;
    _openChapter(_chapters.first);
  }

  Future<void> _openTag(String tag) async {
    final books = await widget.apiService.fetchBooksByTag(tag);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TagBooksScreen(
          tag: tag,
          books: books,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = _book.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(_book.coverPath);
    final summary = _book.description.isEmpty
        ? 'No summary available.'
        : _book.description;
    final needsExpand = summary.length > 160;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () {
                  // System share is handled on reader; here just open reading list as secondary
                  _openReadingListPicker();
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  final action = await showMenu<String>(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                    items: const [
                      PopupMenuItem(
                        value: 'list',
                        child: Text('Save to reading list'),
                      ),
                      PopupMenuItem(
                        value: 'review',
                        child: Text('Write a review'),
                      ),
                      PopupMenuItem(
                        value: 'report',
                        child: Text('Report story'),
                      ),
                    ],
                  );
                  if (action == 'list') {
                    await _openReadingListPicker();
                  } else if (action == 'review') {
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _WriteReviewScreen(
                          bookId: _book.id,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                    final reviews =
                        await widget.apiService.fetchBookReviews(_book.id);
                    if (mounted) setState(() => _reviews = reviews);
                  } else if (action == 'report') {
                    try {
                      final res = await widget.apiService.reportBook(_book.id);
                      if (!mounted) return;
                      final flagged = res['flagged_for_admin'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            flagged
                                ? 'Report recorded. Story flagged for admin (3+ reports).'
                                : 'Report submitted. Thank you.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not report: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),

          // Centered cover (matches video)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: coverUrl == null
                      ? Container(
                          width: 160,
                          height: 230,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.menu_book, size: 48),
                        )
                      : Image.network(
                          coverUrl,
                          width: 160,
                          height: 230,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 160,
                            height: 230,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Title centered
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_florist,
                          size: 18, color: Color(0xFFE85D4C)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _book.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_book.author.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'by ${_book.author}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Stats row: Chapters | Last Updated | Reviews
          if (!_loadingChapters)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statCell('Chapters', '${_chapters.length}'),
                    _statCell(
                      _book.lastUpdated.trim().isNotEmpty
                          ? 'Last Updated'
                          : 'Story Status',
                      _book.lastUpdated.trim().isNotEmpty
                          ? _book.lastUpdated.trim()
                          : (_book.statusText.isNotEmpty
                              ? _book.statusText
                              : 'Ongoing'),
                    ),
                    _statCell(
                      'Reviews',
                      _book.rating > 0
                          ? '★ ${_book.rating.toStringAsFixed(1)}'
                          : '${_reviews.length}',
                    ),
                  ],
                ),
              ),
            ),

          // Summary + Read More
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    maxLines: _summaryExpanded || !needsExpand ? null : 4,
                    overflow: _summaryExpanded || !needsExpand
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: const Color(0xFF444444),
                    ),
                  ),
                  if (needsExpand)
                    TextButton(
                      onPressed: () =>
                          setState(() => _summaryExpanded = !_summaryExpanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _summaryExpanded ? 'Show less' : 'Read More',
                        style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Likes | Save | Reviews row (video)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _likeBusy
                        ? null
                        : () async {
                            setState(() => _likeBusy = true);
                            try {
                              final res = _liked
                                  ? await widget.apiService.unlikeBook(_book.id)
                                  : await widget.apiService.likeBook(_book.id);
                              if (!mounted) return;
                              setState(() {
                                _liked = (res['liked'] as bool?) ?? !_liked;
                                _likesCount = (res['likes_count'] as num?)
                                        ?.toInt() ??
                                    _likesCount;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().contains('401')
                                        ? 'Sign in to like stories'
                                        : 'Could not update like',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _likeBusy = false);
                            }
                          },
                    icon: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: _liked ? Colors.red : null,
                    ),
                    label: Text(
                      _likesCount > 0 ? '$_likesCount Likes' : 'Likes',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openReadingListPicker,
                    icon: const Icon(Icons.bookmark_border, size: 20),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _WriteReviewScreen(
                            bookId: _book.id,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                      final reviews =
                          await widget.apiService.fetchBookReviews(_book.id);
                      if (mounted) setState(() => _reviews = reviews);
                    },
                    icon: const Icon(Icons.star_border, size: 20),
                    label: Text(
                      _reviews.isEmpty
                          ? 'Reviews'
                          : '${_reviews.length} Reviews',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Warnings (Inkitt-style — shown when present)
          if (_book.contentWarnings.trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Warnings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _book.contentWarnings.trim().toLowerCase().startsWith('this story')
                          ? _book.contentWarnings.trim()
                          : 'This story contains themes of: ${_book.contentWarnings.trim()}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Genres — chips keep hierarchical "Parent > Child" when present
          if (_book.genre.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Genres',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: () {
                        final raw = _book.genre.trim();
                        // Support both "Romance > Dark, Fantasy > Dark" and plain lists
                        final parts = raw
                            .split(RegExp(r'[,|]'))
                            .map((g) => g.trim())
                            .where((g) => g.isNotEmpty)
                            .toList();
                        if (parts.isEmpty) return <Widget>[];
                        return parts
                            .map(
                              (g) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  g,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList();
                      }(),
                    ),
                  ],
                ),
              ),
            ),

          // Tags / hashtags (clickable)
          if (_tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags
                          .map(
                            (t) => ActionChip(
                              label: Text(t.startsWith('#') ? t : '#$t'),
                              onPressed: () => _openTag(t),
                              backgroundColor: const Color(0xFFFFF0EE),
                              labelStyle: const TextStyle(
                                color: Color(0xFFE85D4C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

          // Author + Follow
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Author',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade300,
                        child: Text(
                          _book.author.isNotEmpty
                              ? _book.author[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _book.author.isEmpty ? 'Unknown author' : _book.author,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_book.authorUserId != null)
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: _loadingFollow ? null : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _isFollowing
                                    ? Colors.grey.shade400
                                    : const Color(0xFF00C853),
                              ),
                              foregroundColor: _isFollowing
                                  ? Colors.black54
                                  : const Color(0xFF00C853),
                              backgroundColor: _isFollowing
                                  ? Colors.grey.shade100
                                  : const Color(0xFFE8F8EF),
                            ),
                            child: Text(
                              _isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Reviews section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Reviews',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _WriteReviewScreen(
                            bookId: _book.id,
                            apiService: widget.apiService,
                          ),
                        ),
                      );
                      final reviews =
                          await widget.apiService.fetchBookReviews(_book.id);
                      if (mounted) setState(() => _reviews = reviews);
                    },
                    child: const Text('Write'),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingReviews)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            )
          else if (_reviews.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('No reviews yet. Be the first to review.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final r = _reviews[index];
                  final rating = (r['rating'] as num?)?.toInt() ?? 0;
                  final comment = r['comment'] as String? ??
                      r['body'] as String? ??
                      '';
                  final author = r['display_name'] as String? ??
                      r['author'] as String? ??
                      'Reader';
                  final avatarRaw = (r['avatar_url'] ??
                          r['photo_url'] ??
                          r['user_avatar'] ??
                          '')
                      .toString();
                  final avatarUrl = avatarRaw.isEmpty
                      ? ''
                      : widget.apiService.resolveAssetUrl(avatarRaw);
                  final reviewerId = (r['user_id'] as num?)?.toInt() ??
                      (r['author_id'] as num?)?.toInt();
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              author.isNotEmpty
                                  ? author[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: reviewerId != null && reviewerId > 0
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProfileScreen(
                                          apiService: widget.apiService,
                                          viewingUserId: reviewerId,
                                          achievements: const [],
                                          profile: ProfileModel(
                                            id: reviewerId,
                                            displayName: author,
                                            username: author
                                                .toLowerCase()
                                                .replaceAll(' ', ''),
                                            photoUrl: avatarRaw,
                                            coverUrl: '',
                                            following: 0,
                                            followers: 0,
                                            blocked: 0,
                                            chaptersRead: 0,
                                            socialKarma: 0,
                                            dayStreak: 0,
                                            readingLists: const [],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(
                          rating.clamp(0, 5),
                          (_) => const Icon(Icons.star,
                              size: 14, color: Colors.amber),
                        ),
                      ],
                    ),
                    subtitle: comment.isEmpty ? null : Text(comment),
                  );
                },
                childCount: _reviews.length,
              ),
            ),

          // Chapters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Chapters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_loadingChapters)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_chapters.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No chapters published yet.'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = _chapters[index];
                  final title =
                      chapter['title'] as String? ?? 'Untitled chapter';
                  final number =
                      (chapter['chapter_number'] as num?)?.toInt() ??
                          index + 1;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    leading: Text(
                      '$number',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openChapter(chapter, index: index),
                  );
                },
                childCount: _chapters.length,
              ),
            ),
          // More Stories by Author (matches video)
          if (_authorStories.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'More Stories by ${_book.author.isNotEmpty ? _book.author : 'Author'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _authorStories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final b = _authorStories[index];
                    final title = b['title'] as String? ?? '';
                    final cover = b['cover_path'] as String? ??
                        b['cover_url'] as String? ??
                        '';
                    final coverResolved = cover.isEmpty
                        ? null
                        : widget.apiService.resolveAssetUrl(cover);
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              book: BookDetailModel.fromMap(b),
                              apiService: widget.apiService,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: coverResolved == null
                                  ? Container(
                                      width: 100,
                                      height: 140,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.menu_book),
                                    )
                                  : Image.network(
                                      coverResolved,
                                      width: 100,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Container(
                                        width: 100,
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // You May Also Like (matches video)
          if (_youMayAlsoLike.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'You May Also Like',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _youMayAlsoLike.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final b = _youMayAlsoLike[index];
                    final title = b['title'] as String? ?? '';
                    final cover = b['cover_path'] as String? ??
                        b['cover_url'] as String? ??
                        '';
                    final coverResolved = cover.isEmpty
                        ? null
                        : widget.apiService.resolveAssetUrl(cover);
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              book: BookDetailModel.fromMap(b),
                              apiService: widget.apiService,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: coverResolved == null
                                  ? Container(
                                      width: 100,
                                      height: 140,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.menu_book),
                                    )
                                  : Image.network(
                                      coverResolved,
                                      width: 100,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Container(
                                        width: 100,
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _readNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Read Now',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagBooksScreen extends StatelessWidget {
  const _TagBooksScreen({
    required this.tag,
    required this.books,
    required this.apiService,
  });

  final String tag;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tag.startsWith('#') ? tag : '#$tag')),
      body: books.isEmpty
          ? const Center(child: Text('No stories with this tag yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final b = books[index];
                final title = b['title'] as String? ?? 'Untitled';
                final author = b['author'] as String? ?? '';
                final cover = b['cover_path'] as String? ?? '';
                return ListTile(
                  leading: cover.isEmpty
                      ? const Icon(Icons.menu_book)
                      : Image.network(
                          apiService.resolveAssetUrl(cover),
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        ),
                  title: Text(title),
                  subtitle: Text(author),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel.fromMap(b),
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

class _WriteReviewScreen extends StatefulWidget {
  const _WriteReviewScreen({
    required this.bookId,
    required this.apiService,
  });

  final int bookId;
  final ApiService apiService;

  @override
  State<_WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<_WriteReviewScreen> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.createBookReview(widget.bookId, {
        'rating': _rating,
        'comment': _controller.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit review — please sign in'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a review')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Share your thoughts…',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D4C),
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
