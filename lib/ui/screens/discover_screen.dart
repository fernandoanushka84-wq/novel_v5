import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';

import 'explore_screen.dart';
import 'profile_screen.dart';
import 'story_detail_screen.dart';

part 'discover_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.data,
    required this.apiService,
  });

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<String> _tabs;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = widget.data.discoverTabs.isNotEmpty
        ? widget.data.discoverTabs
        : const ['New', 'Popular', 'Fanfiction', 'Newsfeed'];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              children: [
                const Text(
                  'Inkitt',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search, size: 26),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SearchScreen(
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert, size: 24),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Discover options')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _CategoryTabs(
                labels: _tabs,
                tabController: _tabController,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildTabContent(_selectedTabIndex)),
      ],
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tabLabel = _tabs[tabIndex].toLowerCase();
    final allBooks = _booksForDiscover();
    final sections = _discoverSectionsForTab(tabLabel, allBooks);
    final showExploreLead = tabLabel == 'new' && sections.isNotEmpty;

    return Container(
      color: Colors.white,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          if (showExploreLead) ...[
            _ExploreStoriesSection(
              books: sections.first.books,
              topics: widget.data.exploreTopics,
              apiService: widget.apiService,
              onOpenExplore: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExploreScreen(
                      topics: widget.data.exploreTopics,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          for (var i = 0; i < sections.length; i++) ...[
            if (!(showExploreLead && i == 0)) ...[
              _DynamicStoryRail(
                section: sections[i],
                apiService: widget.apiService,
              ),
              const SizedBox(height: 24),
              if (i == 1) ...[
                _GenrePillRow(
                  topics: widget.data.exploreTopics,
                  books: allBooks,
                  apiService: widget.apiService,
                  onOpenExplore: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ExploreScreen(
                          topics: widget.data.exploreTopics,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              if (i == 2) ...[
                _AuthorsStrip(books: allBooks, apiService: widget.apiService),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ],
      ),
    );
  }

  List<BookCardModel> _booksForDiscover() {
    if (widget.data.discoverBooks.isNotEmpty) {
      return widget.data.discoverBooks;
    }

    final seen = <int>{};
    final merged = <BookCardModel>[];
    for (final book in [
      ...widget.data.recentlyUpdated,
      ...widget.data.recentlyCompleted,
    ]) {
      if (!seen.contains(book.id)) {
        seen.add(book.id);
        merged.add(book);
      }
    }
    return merged;
  }

  List<_DiscoverRailSection> _discoverSectionsForTab(
    String tab,
    List<BookCardModel> books,
  ) {
    List<BookCardModel> takeWhere(bool Function(BookCardModel) test) {
      return books.where(test).toList();
    }

    final recentlyUpdated = takeWhere(
      (b) => b.sectionName == 'recently_updated',
    );
    final recentlyCompleted = takeWhere(
      (b) => b.sectionName == 'recently_completed' || b.isCompleted,
    );
    final topRated = [...books]..sort((a, b) => b.rating.compareTo(a.rating));
    final fantasy = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('fantasy') ||
          b.secondaryGenre.toLowerCase().contains('fantasy'),
    );
    final paranormal = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('paranormal') ||
          b.secondaryGenre.toLowerCase().contains('urban'),
    );
    final action = takeWhere(
      (b) =>
          b.primaryGenre.toLowerCase().contains('action') ||
          b.secondaryGenre.toLowerCase().contains('action') ||
          b.primaryGenre.toLowerCase().contains('adventure') ||
          b.secondaryGenre.toLowerCase().contains('adventure'),
    );

    switch (tab) {
      case 'popular':
        return [
          _DiscoverRailSection(
            title: 'Trending Now',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Most Completed',
            books: recentlyCompleted.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Fan Favorites',
            books: topRated.skip(2).take(10).toList(),
          ),
        ];
      case 'fanfiction':
        return [
          _DiscoverRailSection(
            title: 'Fan Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Romance & Drama',
            books: takeWhere(
              (b) =>
                  b.primaryGenre.toLowerCase().contains('romance') ||
                  b.primaryGenre.toLowerCase().contains('drama'),
            ).take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Completed Fan Stories',
            books: recentlyCompleted.take(10).toList(),
          ),
        ];
      case 'newsfeed':
        return [
          _DiscoverRailSection(
            title: 'Fresh Updates',
            books: recentlyUpdated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Staff Picks',
            books: topRated.take(10).toList(),
          ),
          _DiscoverRailSection(
            title: 'Rising Stories',
            books: topRated.skip(4).take(10).toList(),
          ),
        ];
      default:
        return [
          _DiscoverRailSection(
            title: 'Recently Updated',
            books: recentlyUpdated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Recently Completed',
            books: recentlyCompleted.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Selected Stories',
            books: topRated.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'New in Fantasy',
            books: fantasy.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Action & Adventure Fantasy',
            books: action.take(12).toList(),
          ),
          _DiscoverRailSection(
            title: 'Paranormal & Urban Fantasy',
            books: paranormal.take(12).toList(),
          ),
        ];
    }
  }
}


// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.apiService,
    this.initialQuery = '',
    this.initialGenre = '',
  });

  final ApiService apiService;
  final String initialQuery;
  final String initialGenre;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _genre = '';
  double _minRating = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    final rows = await widget.apiService.searchStories(
      query: _searchQuery,
      genre: _genre,
      minRating: _minRating,
    );
    if (!mounted) return;
    setState(() {
      _results = rows;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery;
    _genre = widget.initialGenre;
    _searchController = TextEditingController(text: widget.initialQuery);
    _runSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search stories, people, lists...',
            border: InputBorder.none,
            hintStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _runSearch();
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() => _searchQuery = '');
                _searchController.clear();
                _runSearch();
              },
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              final selected = await showModalBottomSheet<_SearchFilters>(
                context: context,
                builder: (_) => const _FilterSheet(),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              );
              if (selected == null) return;
              setState(() {
                _genre = selected.genre;
                _minRating = selected.minRating;
              });
              _runSearch();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE8E8E8)),
                  ),
                  onTap: () {
                    final id = (item['id'] as num?)?.toInt();
                    if (id == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: widget.apiService,
                          book: BookDetailModel.fromMap(item),
                        ),
                      ),
                    );
                  },
                  leading: SizedBox(
                    width: 40,
                    height: 56,
                    child: (item['cover_path']?.toString() ?? '').isNotEmpty
                        ? Image.network(
                            widget.apiService.resolveAssetUrl(
                              item['cover_path'].toString(),
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0xFFE4E4E4)),
                          )
                        : const ColoredBox(color: Color(0xFFE4E4E4)),
                  ),
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(item['author']?.toString() ?? ''),
                  trailing: Text(
                    (item['rating'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
    );
  }
}

class _SearchFilters {
  const _SearchFilters({required this.genre, required this.minRating});

  final String genre;
  final double minRating;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _selectedGenre;
  double _ratingFilter = 0;
  String? _completionStatus;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Genre',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Romance', 'Fantasy', 'Mystery', 'Horror', 'Sci-Fi']
                .map(
                  (genre) => FilterChip(
                    label: Text(genre),
                    selected: _selectedGenre == genre,
                    onSelected: (selected) {
                      setState(() => _selectedGenre = selected ? genre : null);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Star Rating',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _ratingFilter,
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (value) => setState(() => _ratingFilter = value),
          ),
          const SizedBox(height: 24),
          Text(
            'Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Complete', 'Ongoing', 'Hiatus']
                .map(
                  (status) => FilterChip(
                    label: Text(status),
                    selected: _completionStatus == status,
                    onSelected: (selected) {
                      setState(
                        () => _completionStatus = selected ? status : null,
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _SearchFilters(
                  genre: _selectedGenre ?? '',
                  minRating: _ratingFilter,
                ),
              ),
              child: const Text('View Results'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Story detail (matches video: cover, stats, summary, genres, chapters, CTA)
// ---------------------------------------------------------------------------
