part of 'discover_screen.dart';

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text, this.onReadMore});

  final String text;
  final VoidCallback? onReadMore;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim().isEmpty
        ? 'No description available yet.'
        : widget.text.trim();
    final needsToggle = text.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded || !needsToggle ? null : 4,
          overflow: _expanded || !needsToggle
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: const Color(0xFF555555),
          ),
        ),
        if (needsToggle)
          TextButton(
            onPressed: () {
              if (widget.onReadMore != null) {
                widget.onReadMore!();
                return;
              }
              setState(() => _expanded = !_expanded);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  if (normalized.length < 6) return const Color(0xFFA1A1A1);
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ExploreStoriesSection extends StatelessWidget {
  const _ExploreStoriesSection({
    required this.books,
    required this.topics,
    required this.apiService,
    required this.onOpenExplore,
  });

  final List<BookCardModel> books;
  final List<ExploreTopicModel> topics;
  final ApiService apiService;
  final VoidCallback onOpenExplore;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final lead = books.first;
    final covers = books.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lead.primaryGenre.isEmpty ? 'Portal Fantasy' : lead.primaryGenre,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: covers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = covers[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  height: 120,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryDetailScreen(
                            apiService: apiService,
                            book: BookDetailModel(
                              id: item.id,
                              title: item.title,
                              author: item.author,
                              description: item.description,
                              statusText: item.statusText,
                              rating: item.rating,
                              genre: item.primaryGenre,
                              cta: item.cta,
                              coverPath: item.coverPath,
                            ),
                          ),
                        ),
                      );
                    },
                    child: _StoryCard(
                      book: item,
                      width: 86,
                      apiService: apiService,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(book: lead, apiService: apiService),
        const SizedBox(height: 16),
        _GenrePillRow(
          topics: topics,
          books: books,
          apiService: apiService,
          onOpenExplore: onOpenExplore,
        ),
      ],
    );
  }
}

class _DiscoverRailSection {
  const _DiscoverRailSection({required this.title, required this.books});

  final String title;
  final List<BookCardModel> books;
}

class _DynamicStoryRail extends StatefulWidget {
  const _DynamicStoryRail({required this.section, required this.apiService});

  final _DiscoverRailSection section;
  final ApiService apiService;

  @override
  State<_DynamicStoryRail> createState() => _DynamicStoryRailState();
}

class _DynamicStoryRailState extends State<_DynamicStoryRail> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    // Slightly denser carousel (Inkitt-like card density)
    _pageController = PageController(viewportFraction: 0.28);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.books.isEmpty) {
      return const SizedBox.shrink();
    }

    final book = widget
        .section
        .books[_activeIndex.clamp(0, widget.section.books.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.section.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.brand,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.section.books.isEmpty)
          const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'No stories yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _pageController,
              padEnds: true,
              itemCount: widget.section.books.length,
              onPageChanged: (index) => setState(() => _activeIndex = index),
              itemBuilder: (context, index) {
                final item = widget.section.books[index];
                final isActive = index == _activeIndex;
                return AnimatedScale(
                  scale: isActive ? 1.08 : 0.9,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6, left: 4),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoryDetailScreen(
                                apiService: widget.apiService,
                                book: BookDetailModel(
                                  id: item.id,
                                  title: item.title,
                                  author: item.author,
                                  description: item.description,
                                  statusText: item.statusText,
                                  rating: item.rating,
                                  genre: item.primaryGenre,
                                  cta: item.cta,
                                  coverPath: item.coverPath,
                                ),
                              ),
                            ),
                          );
                        },
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: isActive ? 0 : 1.8,
                            sigmaY: isActive ? 0 : 1.8,
                          ),
                          child: _StoryCard(
                            book: item,
                            width: 88,
                            apiService: widget.apiService,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(
          book: book,
          apiService: widget.apiService,
          onRead: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: widget.apiService,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActiveStoryDetail extends StatelessWidget {
  const _ActiveStoryDetail({required this.book, this.onRead, this.apiService});

  final BookCardModel book;
  final VoidCallback? onRead;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _ExpandableDescription(
          text: book.description,
          onReadMore: () {
            if (onRead != null) {
              onRead!();
              return;
            }
            if (apiService == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: apiService!,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  book.statusText.isEmpty
                      ? 'Updated recently'
                      : book.statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (book.rating > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  book.rating.round().clamp(0, 5),
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF3C623),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (book.isCompleted) ...[
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: AppTheme.brand,
              ),
              Text(
                'Completed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.brand),
              ),
            ],
            _GenreTag(
              label: book.primaryGenre.isEmpty ? 'Novel' : book.primaryGenre,
            ),
            if (book.secondaryGenre.isNotEmpty)
              _GenreTag(label: book.secondaryGenre),
            ElevatedButton(
              onPressed: onRead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                book.cta,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.book,
    required this.apiService,
    this.width = 140,
  });

  final BookCardModel book;
  final ApiService apiService;
  final double width;

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: widget.book.id,
            title: widget.book.title,
            author: widget.book.author,
            description: widget.book.description,
            statusText: widget.book.statusText,
            rating: widget.book.rating,
            genre: widget.book.primaryGenre,
            cta: widget.book.cta,
            coverPath: widget.book.coverPath,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.book.accentHex);
    final coverUrl = widget.book.coverPath.isEmpty
        ? null
        : widget.apiService.resolveAssetUrl(widget.book.coverPath);
    final compact = widget.width <= 100;

    if (compact) {
      return GestureDetector(
        onTap: _openDetail,
        child: SizedBox(
          width: widget.width,
          height: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: coverUrl == null
                ? ColoredBox(
                    color: color.withValues(alpha: 0.15),
                    child: const Center(child: Icon(Icons.menu_book, size: 28)),
                  )
                : Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    width: widget.width,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: color.withValues(alpha: 0.15),
                      child: const Center(child: Icon(Icons.menu_book, size: 28)),
                    ),
                  ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: coverUrl == null
                    ? Container(
                        color: color.withValues(alpha: 0.2),
                        child: const Center(child: Icon(Icons.menu_book)),
                      )
                    : Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: color.withValues(alpha: 0.2),
                          child: const Center(child: Icon(Icons.menu_book)),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${widget.book.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AuthorsStrip extends StatefulWidget {
  const _AuthorsStrip({required this.books, required this.apiService});

  final List<BookCardModel> books;
  final ApiService apiService;

  @override
  State<_AuthorsStrip> createState() => _AuthorsStripState();
}

class _AuthorsStripState extends State<_AuthorsStrip> {
  Map<int, bool> _following = {};

  @override
  void initState() {
    super.initState();
    _loadFollowStates();
  }

  Future<void> _loadFollowStates() async {
    final ids = <int>[];
    final seenNames = <String>{};
    for (final book in widget.books) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      if (seenNames.contains(name)) continue;
      seenNames.add(name);
      final aid = book.authorUserId;
      if (aid != null) ids.add(aid);
      if (seenNames.length >= 8) break;
    }
    if (ids.isEmpty) return;
    final map = await widget.apiService.fetchAuthorsFollowing(ids);
    if (!mounted) return;
    setState(() => _following = map);
  }

  Future<void> _toggleFollowFor(int authorId) async {
    final currently = _following[authorId] ?? false;
    try {
      if (currently) {
        await widget.apiService.unfollowAuthor(authorId);
      } else {
        await widget.apiService.followAuthor(authorId);
      }
      if (!mounted) return;
      setState(() => _following[authorId] = !currently);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final byAuthor = <String, BookCardModel>{};
    for (final book in widget.books) {
      byAuthor.putIfAbsent(
        book.author.trim().isEmpty ? 'Unknown' : book.author,
        () => book,
      );
      if (byAuthor.length >= 8) break;
    }

    final authors = byAuthor.entries.toList();
    if (authors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Authors on Inkitt',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: authors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = authors[index].key;
              final book = authors[index].value;
              final letter = author.isNotEmpty ? author[0].toUpperCase() : 'A';
              final authorId = book.authorUserId;
              final isFollowing = authorId != null
                  ? (_following[authorId] ?? false)
                  : false;
              return Column(
                children: [
                  GestureDetector(
                    onTap: authorId != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProfileScreen(
                                  apiService: widget.apiService,
                                  viewingUserId: authorId,
                                  achievements: const [],
                                  profile: ProfileModel(
                                    id: authorId,
                                    displayName: author,
                                    username: author.toLowerCase().replaceAll(' ', ''),
                                    photoUrl: '',
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
                    onLongPress: authorId != null
                        ? () => _toggleFollowFor(authorId)
                        : null,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE8EEF9),
                          child: Text(
                            letter,
                            style: const TextStyle(color: AppTheme.brand),
                          ),
                        ),
                        if (authorId != null)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? Colors.white
                                    : Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing
                                      ? AppTheme.brand
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({
    required this.topics,
    required this.books,
    required this.apiService,
    this.onOpenExplore,
  });

  final List<ExploreTopicModel> topics;
  final List<BookCardModel> books;
  final ApiService apiService;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final genres = <String>{};
    for (final b in books) {
      if (b.primaryGenre.isNotEmpty) genres.add(b.primaryGenre);
      if (genres.length >= 8) break;
    }
    final items = genres.toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final label = items[index];
          return ActionChip(
            label: Text(label),
            onPressed: () async {
              final books = await apiService.fetchBooksByTag(label);
              if (!context.mounted) return;
              if (books.isEmpty && onOpenExplore != null) {
                onOpenExplore!();
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _GenreBooksScreen(
                    genre: label,
                    books: books,
                    apiService: apiService,
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

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.labels, required this.tabController});

  final List<String> labels;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final isSelected = tabController.index == index;
          return GestureDetector(
            onTap: () => tabController.animateTo(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? AppTheme.brand : AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  width: isSelected
                      ? math.max(labels[index].length * 11.0, 60)
                      : 0,
                  color: isSelected ? AppTheme.brand : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate({required this.child});

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _GenreBooksScreen extends StatelessWidget {
  const _GenreBooksScreen({
    required this.genre,
    required this.books,
    required this.apiService,
  });

  final String genre;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final label = genre.startsWith('#') ? genre : '#$genre';
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: books.isEmpty
          ? const Center(child: Text('No stories for this tag yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = books[index];
                final cover = (item['cover_path'] ?? '').toString();
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel.fromMap(item),
                        ),
                      ),
                    );
                  },
                  leading: SizedBox(
                    width: 40,
                    height: 56,
                    child: cover.isNotEmpty
                        ? Image.network(
                            apiService.resolveAssetUrl(cover),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(color: Color(0xFFE4E4E4)),
                          )
                        : const ColoredBox(color: Color(0xFFE4E4E4)),
                  ),
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(item['author']?.toString() ?? ''),
                );
              },
            ),
    );
  }
}
