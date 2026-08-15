import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'create_story_screen.dart';
import 'edit_chapter_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key, required this.data, required this.apiService});

  final AppBootstrap data;
  final ApiService apiService;

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabs;
  late TabController _storySubTabs;
  late TabController _analyticsSubTabs;
  late Future<List<Map<String, dynamic>>> _storiesFuture;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);
    _storySubTabs = TabController(
      length: widget.data.writeScreen.storyTabs.isNotEmpty
          ? widget.data.writeScreen.storyTabs.length
          : 2,
      vsync: this,
    );
    _analyticsSubTabs = TabController(length: 2, vsync: this);
    _storiesFuture = widget.apiService.fetchWriterStories();
    _mainTabs.addListener(() => setState(() {}));
    _storySubTabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mainTabs.dispose();
    _storySubTabs.dispose();
    _analyticsSubTabs.dispose();
    super.dispose();
  }

  Future<void> _reloadStories() async {
    if (!mounted) return;
    setState(() {
      _storiesFuture = widget.apiService.fetchWriterStories();
    });
  }

  Future<void> _openCreateStory({Map<String, dynamic>? story}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CreateStoryScreen(apiService: widget.apiService, story: story),
      ),
    );
    if (!mounted || result != true) return;
    await _reloadStories();
  }

  Future<void> _openEditChapter(Map<String, dynamic> story) async {
    final storyId = (story['id'] as num?)?.toInt();
    if (storyId == null) return;

    List<Map<String, dynamic>> chapters = const [];
    try {
      chapters = await widget.apiService.fetchStoryChapters(storyId);
    } catch (_) {}

    if (!mounted) return;

    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chapters — ${story['title'] ?? 'Story'}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (chapters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No chapters yet. Add the first one.'),
                  ),
                for (final c in chapters)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        '${(c['chapter_number'] as num?)?.toInt() ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(
                      (c['title'] ??
                              'Chapter ${(c['chapter_number'] as num?)?.toInt() ?? ''}')
                          .toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      (c['submission_status'] ?? 'draft').toString(),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add new chapter'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    if (choice == 'new') {
      await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => EditChapterScreen(
            apiService: widget.apiService,
            storyId: storyId,
            createNew: true,
            chapterTitle: 'Chapter ${(chapters.length + 1)}',
          ),
        ),
      );
    } else if (choice is Map<String, dynamic>) {
      final id = (choice['id'] as num?)?.toInt();
      final chapterNo = (choice['chapter_number'] as num?)?.toInt();
      final title = (choice['title'] ?? 'Chapter').toString();
      await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => EditChapterScreen(
            apiService: widget.apiService,
            storyId: storyId,
            chapterId: id,
            chapterNumber: chapterNo,
            chapterTitle: title,
          ),
        ),
      );
    }
  }

  Future<void> _deleteStory(Map<String, dynamic> story) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: Text('Delete "${story['title']}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    await widget.apiService.deleteWriterStory(story['id'] as int);
    if (mounted) {
      await _reloadStories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Text(
                'Write',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _openCreateStory(),
                icon: const Icon(Icons.add_rounded, size: 28),
                tooltip: 'Create Story',
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: TabBar(
            controller: _mainTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.brand,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Manage Stories'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        Expanded(
          child: _mainTabs.index == 0
              ? _ManageStoriesTab(
                  storySubTabs: _storySubTabs,
                  storiesFuture: _storiesFuture,
                  query: _query,
                  writeModel: widget.data.writeScreen,
                  apiService: widget.apiService,
                  onQueryChange: (value) => setState(() => _query = value),
                  onCreateStory: () => _openCreateStory(),
                  onEditStory: (story) => _openCreateStory(story: story),
                  onEditChapter: _openEditChapter,
                  onDeleteStory: _deleteStory,
                  onRefresh: _reloadStories,
                )
              : _AnalyticsTab(analyticsSubTabs: _analyticsSubTabs),
        ),
      ],
    );
  }
}

class _ManageStoriesTab extends StatelessWidget {
  const _ManageStoriesTab({
    required this.storySubTabs,
    required this.storiesFuture,
    required this.query,
    required this.writeModel,
    required this.apiService,
    required this.onQueryChange,
    required this.onCreateStory,
    required this.onEditStory,
    required this.onEditChapter,
    required this.onDeleteStory,
    required this.onRefresh,
  });

  final TabController storySubTabs;
  final Future<List<Map<String, dynamic>>> storiesFuture;
  final String query;
  final WriteScreenModel writeModel;
  final ApiService apiService;
  final ValueChanged<String> onQueryChange;
  final VoidCallback onCreateStory;
  final ValueChanged<Map<String, dynamic>> onEditStory;
  final ValueChanged<Map<String, dynamic>> onEditChapter;
  final ValueChanged<Map<String, dynamic>> onDeleteStory;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: TabBar(
            controller: storySubTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.brand,
            tabs: writeModel.storyTabs.isNotEmpty
                ? writeModel.storyTabs.map((e) => Tab(text: e)).toList()
                : const [Tab(text: 'Submitted'), Tab(text: 'Drafts')],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            onChanged: onQueryChange,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 16,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Text(
                writeModel.filterLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.south_rounded, size: 16, color: AppTheme.muted),
              const SizedBox(width: 4),
              Text(
                writeModel.sortLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: storiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stories = (snapshot.data ?? <Map<String, dynamic>>[])
                    .where((story) {
                      final statusText =
                          story['status_text']?.toString().toLowerCase() ?? '';
                      final isDraft = statusText.contains('draft');
                      if (storySubTabs.index == 0 && isDraft) {
                        return false;
                      }
                      if (storySubTabs.index == 1 && !isDraft) {
                        return false;
                      }
                      if (query.trim().isEmpty) return true;
                      final q = query.trim().toLowerCase();
                      final title =
                          story['title']?.toString().toLowerCase() ?? '';
                      final author =
                          story['author']?.toString().toLowerCase() ?? '';
                      return title.contains(q) || author.contains(q);
                    })
                    .toList();

                if (stories.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 56,
                              color: AppTheme.muted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              writeModel.emptyTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: onCreateStory,
                              child: Text(
                                writeModel.emptyCta,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.brand,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    return _StoryListCard(
                      story: story,
                      apiService: apiService,
                      onEdit: () => onEditStory(story),
                      onEditChapter: () => onEditChapter(story),
                      onDelete: () => onDeleteStory(story),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryListCard extends StatelessWidget {
  const _StoryListCard({
    required this.story,
    required this.apiService,
    required this.onEdit,
    required this.onEditChapter,
    required this.onDelete,
  });

  final Map<String, dynamic> story;
  final ApiService apiService;
  final VoidCallback onEdit;
  final VoidCallback onEditChapter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = story['title']?.toString() ?? 'Untitled';
    final author = story['author']?.toString() ?? '';
    final description = story['description']?.toString() ?? '';
    final genre = story['genre']?.toString() ?? '';
    final statusText = story['status_text']?.toString().trim() ?? 'Draft';
    final isDraft = statusText.toLowerCase().contains('draft');
    final coverPath = story['cover_path']?.toString() ?? '';
    final coverUrl = coverPath.isEmpty ? '' : apiService.resolveAssetUrl(coverPath);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 52,
              height: 74,
              color: AppTheme.brand.withValues(alpha: 0.14),
              child: coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      width: 52,
                      height: 74,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.book_rounded,
                        color: AppTheme.brand,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.book_rounded,
                      color: AppTheme.brand,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                if (author.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'by $author',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                if (genre.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.brand,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDraft
                                ? const Color(0xFFF7E1B5)
                                : const Color(0xFFDCEFD9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDraft ? 'Draft' : statusText,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDraft
                                  ? const Color(0xFF8A5A00)
                                  : const Color(0xFF24613A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'chapter') onEditChapter();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit details')),
              PopupMenuItem(value: 'chapter', child: Text('Chapters')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            icon: const Icon(Icons.more_vert_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.analyticsSubTabs});

  final TabController analyticsSubTabs;

  static const List<double> _weeklyFollowers = [0, 0, 1, 0, 1, 2, 0];
  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: TabBar(
            controller: analyticsSubTabs,
            labelColor: AppTheme.brand,
            unselectedLabelColor: AppTheme.muted,
            indicatorColor: AppTheme.brand,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Stories'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: analyticsSubTabs,
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: _AnalyticsStatCard(
                          title: 'Total Followers',
                          value: '0',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _AnalyticsStatCard(
                          title: 'Total Words Published',
                          value: '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      Text(
                        'Weekly Followers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _FollowerBars(values: _weeklyFollowers),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _weekDays
                              .map(
                                (e) => Text(
                                  e,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      Text(
                        'Top Followers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 16, child: Text('U')),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Test User',
                              style: TextStyle(color: Color(0xFFBBBBBB)),
                            ),
                          ),
                          if (index < 3)
                            const Text(
                              'Follow user',
                              style: TextStyle(color: Color(0xFFBBBBBB)),
                            )
                          else
                            const Text(
                              'Not enough data.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 62,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Stories analytics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Write more stories to unlock story-level stats',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsStatCard extends StatelessWidget {
  const _AnalyticsStatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FollowerBars extends StatelessWidget {
  const _FollowerBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold(1.0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((value) {
        return Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barHeight = ((value / maxVal) * constraints.maxHeight)
                  .clamp(4.0, constraints.maxHeight);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(
                        alpha: value > 0 ? 0.75 : 0.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
