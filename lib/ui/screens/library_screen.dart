import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Temporary working Library screen.
/// For the full private-list detail UI (add/remove stories), copy
/// artifacts/fixes/library_screen.dart over this file.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.data,
    required this.apiService,
    required this.onOpenDiscover,
  });

  final AppBootstrap data;
  final ApiService apiService;
  final VoidCallback onOpenDiscover;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LibraryEntryModel> _entries = [];
  List<ReadingListModel> _readingLists = [];
  bool _loading = false;
  bool _listsLoading = false;

  bool _isCompleted(LibraryEntryModel e) {
    final s = e.readingStatus.toLowerCase().trim();
    return s == 'completed' ||
        s == 'complete' ||
        s == 'finished' ||
        s == 'done';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load only from API — do not seed fake bootstrap lists/entries
    _entries = [];
    _readingLists = [];
    _loadEntries();
    _loadLists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.apiService.fetchLibraryEntries();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(LibraryEntryModel.fromMap).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLists() async {
    setState(() => _listsLoading = true);
    try {
      final rows = await widget.apiService.fetchReadingLists();
      if (!mounted) return;
      setState(() {
        _readingLists = rows.map(ReadingListModel.fromMap).toList();
        _listsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _listsLoading = false);
    }
  }

  Future<void> _createList() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New List'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final created = await widget.apiService.createReadingList({
        'name': name,
        'story_count': 0,
        'cover_path': '',
        'sort_order': _readingLists.length + 1,
      });
      await _loadLists();
      if (!mounted) return;
      final newId = (created['id'] as num?)?.toInt();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newId != null
                ? 'Created "$name"'
                : 'Created "$name". Pull to refresh if it is not visible.',
          ),
        ),
      );
      // If list still empty after create, force another fetch shortly after
      if (_readingLists.isEmpty ||
          !_readingLists.any((l) => l.name == name)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _loadLists();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') || e.toString().contains('403')
                  ? 'Please sign in to create a reading list'
                  : 'Could not create list: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openList(ReadingListModel list) async {
    if (list.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pull to refresh lists first')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ListDetail(
          listId: list.id,
          listName: list.name,
          api: widget.apiService,
        ),
      ),
    );
    if (!mounted) return;
    await _loadLists();
  }

  Future<void> _toggle(LibraryEntryModel e) async {
    final next = _isCompleted(e) ? 'Reading' : 'Completed';
    try {
      await widget.apiService.updateLibraryEntry(e.id, {
        'reading_status': next,
        'updated_text': e.updatedText,
        'chapters': e.chapters,
        'primary_genre': e.primaryGenre,
        'secondary_genre': e.secondaryGenre,
      });
      await _loadEntries();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  Future<void> _delete(LibraryEntryModel e) async {
    try {
      await widget.apiService.deleteLibraryEntry(e.id);
      await _loadEntries();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _entries.where((e) => !_isCompleted(e)).toList();
    final history = _entries.where(_isCompleted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Text(
            'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          tabs: const [
            Tab(text: 'Current Reads'),
            Tab(text: 'Reading Lists'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EntriesList(
                entries: current,
                loading: _loading,
                api: widget.apiService,
                onToggle: _toggle,
                onDelete: _delete,
                onRefresh: () async {
                  await _loadEntries();
                  await _loadLists();
                },
                onDiscover: widget.onOpenDiscover,
              ),
              _ListsPane(
                lists: _readingLists,
                loading: _listsLoading,
                onCreate: _createList,
                onOpen: _openList,
                onRefresh: () async {
                  await _loadEntries();
                  await _loadLists();
                },
              ),
              _EntriesList(
                entries: history,
                loading: _loading,
                api: widget.apiService,
                onToggle: _toggle,
                onDelete: _delete,
                onRefresh: () async {
                  await _loadEntries();
                  await _loadLists();
                },
                onDiscover: widget.onOpenDiscover,
                history: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({
    required this.entries,
    required this.loading,
    required this.api,
    required this.onToggle,
    required this.onDelete,
    required this.onRefresh,
    required this.onDiscover,
    this.history = false,
  });

  final List<LibraryEntryModel> entries;
  final bool loading;
  final ApiService api;
  final ValueChanged<LibraryEntryModel> onToggle;
  final ValueChanged<LibraryEntryModel> onDelete;
  final Future<void> Function() onRefresh;
  final VoidCallback onDiscover;
  final bool history;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        children: [
          Text(
            history ? 'Reading History' : 'My Books',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (history) ...[
            const SizedBox(height: 8),
            Text(
              'Mark Completed from Current Reads to sync here.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 18),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (entries.isEmpty)
            Center(
              child: Text(
                history ? 'No completed books yet' : 'No books yet',
                style: const TextStyle(color: AppTheme.muted),
              ),
            )
          else
            ...entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoryDetailScreen(
                        apiService: api,
                        book: BookDetailModel(
                          id: e.book.id,
                          title: e.book.title,
                          author: e.book.author,
                          description: e.book.description,
                          statusText: e.book.statusText,
                          rating: e.book.rating,
                          genre: e.book.primaryGenre,
                          cta: e.book.cta,
                          coverPath: e.book.coverPath,
                          authorUserId: e.book.authorUserId,
                        ),
                      ),
                    ),
                  );
                },
                leading: SizedBox(
                  width: 48,
                  height: 64,
                  child: e.book.coverPath.isNotEmpty
                      ? Image.network(
                          api.resolveAssetUrl(e.book.coverPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFFE4E4E4)),
                        )
                      : const ColoredBox(color: Color(0xFFE4E4E4)),
                ),
                title: Text(
                  e.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${e.readingStatus} · ${e.primaryGenre}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'status') onToggle(e);
                    if (v == 'delete') onDelete(e);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        history ? 'Mark as Reading' : 'Mark as Completed',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          if (!history) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Discover more stories'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListsPane extends StatelessWidget {
  const _ListsPane({
    required this.lists,
    required this.loading,
    required this.onCreate,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<ReadingListModel> lists;
  final bool loading;
  final Future<void> Function() onCreate;
  final ValueChanged<ReadingListModel> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
        children: [
          Text(
            'Private Reading Lists',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a list to open, add, or remove stories.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (lists.isEmpty)
            const Center(
              child: Text(
                'No lists yet',
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          else
            ...lists.map(
              (l) => Card(
                child: ListTile(
                  onTap: () => onOpen(l),
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(l.name),
                  subtitle: Text('${l.storyCount} stories'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => onCreate(),
            icon: const Icon(Icons.add),
            label: const Text('Create New List'),
          ),
        ],
      ),
    );
  }
}

class _ListDetail extends StatefulWidget {
  const _ListDetail({
    required this.listId,
    required this.listName,
    required this.api,
  });

  final int listId;
  final String listName;
  final ApiService api;

  @override
  State<_ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<_ListDetail> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _name = '';

  @override
  void initState() {
    super.initState();
    _name = widget.listName;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.fetchReadingListDetail(widget.listId);
      if (!mounted) return;
      setState(() {
        _name = data['name']?.toString() ?? widget.listName;
        _items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final rows = await widget.api.searchStories(query: '');
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ListView(
        children: rows
            .map(
              (r) => ListTile(
                title: Text('${r['title']}'),
                subtitle: Text('${r['author']}'),
                onTap: () => Navigator.pop(ctx, r),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    final id = (picked['id'] as num?)?.toInt();
    if (id == null) return;
    await widget.api.addReadingListItem(widget.listId, id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _add),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              try {
                await widget.api.deleteReadingList(widget.listId);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final it = _items[i];
                return ListTile(
                  title: Text('${it['title']}'),
                  subtitle: Text('by ${it['author']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () async {
                      final itemId = (it['id'] as num?)?.toInt();
                      if (itemId == null) return;
                      await widget.api.removeReadingListItem(
                        widget.listId,
                        itemId,
                      );
                      await _load();
                    },
                  ),
                );
              },
            ),
    );
  }
}
