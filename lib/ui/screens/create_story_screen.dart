import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
    required this.apiService,
    this.story,
    this.authorDisplayName,
  });

  final ApiService apiService;
  final Map<String, dynamic>? story;
  final String? authorDisplayName;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _authorController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _warningsController = TextEditingController();
  final _tagFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;
  String _coverPath = '';
  final List<String> _selectedTags = [];
  List<String> _availableTags = const [];
  bool _loadingTags = false;

  static const List<String> _defaultGenres = [
    'Romance', 'Fantasy', 'Fanfiction', 'Mystery', 'Thriller', 'Horror',
    'Sci-Fi', 'Young Adult', 'Adventure', 'Drama', 'Humor', 'Erotica',
    'Paranormal', 'Werewolves', 'LGBTQ+', 'Historical', 'Contemporary',
    'Action', 'Other',
  ];
  List<String> _genres = List<String>.from(_defaultGenres);
  String? _selectedGenre;
  bool _loadingGenres = false;

  bool get _isEditing => widget.story != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.story!['title']?.toString() ?? '';
      _summaryController.text = widget.story!['description']?.toString() ?? '';
      _warningsController.text = (widget.story!['content_warnings'] ?? widget.story!['contentWarnings'] ?? '').toString();
      final g = (widget.story!['genre'] ?? widget.story!['primary_genre'] ?? '').toString().trim();
      if (g.isNotEmpty) {
        _selectedGenre = g;
        if (!_genres.any((x) => x.toLowerCase() == g.toLowerCase())) {
          _genres = [..._genres, g];
        }
      }
      _coverPath = widget.story!['cover_path']?.toString() ?? '';
      final existing = (widget.story!['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      _selectedTags.addAll(existing.take(3));
    }
    _resolveAuthorName();
    _loadAvailableTags();
    _loadGenres();
  }

  Future<void> _resolveAuthorName() async {
    String name = (widget.authorDisplayName ?? '').trim();
    if (name.isEmpty) {
      try {
        final me = await widget.apiService.fetchMe();
        name = (me['display_name'] ?? me['username'] ?? me['name'] ?? '').toString().trim();
      } catch (_) {}
    }
    if (name.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        name = (prefs.getString('auth_display_name') ?? '').trim();
      } catch (_) {}
    }
    if (name.isEmpty && _isEditing) {
      name = widget.story!['author']?.toString().trim() ?? '';
    }
    if (name.isEmpty) name = 'Author';
    if (!mounted) return;
    setState(() => _authorController.text = name);
  }

  Future<void> _loadAvailableTags() async {
    setState(() => _loadingTags = true);
    try {
      final items = await widget.apiService.fetchTags();
      if (!mounted) return;
      setState(() {
        _availableTags = items
            .map((e) => (e['name'] ?? e['tag'] ?? e['label'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .map((t) => t.startsWith('#') ? t.substring(1) : t)
            .toList();
        _loadingTags = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTags = false);
    }
  }

  Future<void> _loadGenres() async {
    setState(() => _loadingGenres = true);
    try {
      final remote = await widget.apiService.fetchGenres();
      if (!mounted) return;
      final merged = <String>{..._defaultGenres};
      for (final g in remote) {
        final s = g.trim();
        if (s.isNotEmpty) merged.add(s);
      }
      if (_selectedGenre != null && _selectedGenre!.isNotEmpty) merged.add(_selectedGenre!);
      final list = merged.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _genres = list;
        _loadingGenres = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGenres = false);
    }
  }

  Future<void> _promptNewGenre() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New genre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Dark Romance', border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    var name = result.trim();
    try {
      name = await widget.apiService.createGenre(name);
    } catch (_) {
      // Still allow local use even if API fails
    }
    if (!mounted) return;
    final exists = _genres.any((g) => g.toLowerCase() == name.toLowerCase());
    setState(() {
      if (!exists) {
        _genres = [..._genres, name]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
      _selectedGenre = _genres.firstWhere(
        (g) => g.toLowerCase() == name.toLowerCase(),
        orElse: () => name,
      );
    });
  }

  void _addTag(String raw) {
    var name = raw.trim();
    if (name.startsWith('#')) name = name.substring(1);
    if (name.isEmpty) return;
    final match = _availableTags.firstWhere(
      (t) => t.toLowerCase() == name.toLowerCase(),
      orElse: () => '',
    );
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only hashtags created by admin can be used. Pick from suggestions.')),
      );
      return;
    }
    if (_selectedTags.any((t) => t.toLowerCase() == match.toLowerCase())) return;
    if (_selectedTags.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 hashtags per story')));
      return;
    }
    setState(() {
      _selectedTags.add(match);
      _tagInputController.clear();
    });
  }

  void _removeTag(String name) => setState(() => _selectedTags.remove(name));

  Future<void> _pickCover() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final result = await widget.apiService.uploadWriterImage(bytes, picked.name);
      final path = (result['path'] ?? result['cover_path'] ?? result['url'] ?? '').toString();
      if (!mounted) return;
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover upload returned empty path')));
        return;
      }
      setState(() => _coverPath = path);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover image uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cover upload failed: $e')));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _warningsController.dispose();
    _authorController.dispose();
    _tagInputController.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  Future<void> _save({bool publish = false}) async {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final author = _authorController.text.trim();
    final genre = (_selectedGenre ?? '').trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one hashtag is required to create a story')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final warnings = _warningsController.text.trim();
      final payload = {
        'title': title,
        'description': summary,
        'author': author.isEmpty ? 'Author' : author,
        'genre': genre,
        'content_warnings': warnings,
        'tags': List<String>.from(_selectedTags.take(3)),
        if (_coverPath.isNotEmpty) 'cover_path': _coverPath,
        if (publish) 'status_text': 'Published',
      };
      if (_isEditing) {
        final id = (widget.story!['id'] as num).toInt();
        await widget.apiService.updateWriterStory(id, payload);
        if (publish) await widget.apiService.publishWriterStory(id);
      } else {
        final id = await widget.apiService.createWriterStory(payload);
        // Ensure live publish even if backend ignored status_text
        if (publish && id > 0) {
          try {
            await widget.apiService.publishWriterStory(id);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _tagSuggestions(String query) {
    final q = query.trim().toLowerCase().replaceFirst('#', '');
    return _availableTags
        .where((t) => !_selectedTags.any((s) => s.toLowerCase() == t.toLowerCase()))
        .where((t) => q.isEmpty || t.toLowerCase().contains(q))
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Story' : 'New Story'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(publish: false),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickCover,
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _coverPath.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            widget.apiService.resolveAssetUrl(_coverPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(child: Icon(Icons.image_outlined, size: 40)),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                              child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36),
                            SizedBox(height: 6),
                            Text('Add cover', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Cover preview — shown on Draft & Submitted lists',
              style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
          ),
          const SizedBox(height: 20),
          _field('TITLE', TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(hintText: 'Story title', hintStyle: TextStyle(color: AppTheme.muted), border: InputBorder.none),
          )),
          const Divider(height: 1),
          _field('AUTHOR (from your account)', TextField(
            controller: _authorController,
            readOnly: true,
            enabled: false,
            style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
            decoration: const InputDecoration(hintText: 'Your username', border: InputBorder.none, disabledBorder: InputBorder.none),
          )),
          const Divider(height: 1),
          _field('SUMMARY', TextField(
            controller: _summaryController,
            maxLines: 4,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(hintText: 'Short description of your story...', hintStyle: TextStyle(color: AppTheme.muted), border: InputBorder.none),
          )),
          const Divider(height: 1),
          _field(
            'GENRE',
            _loadingGenres
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2))
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedGenre != null && _genres.contains(_selectedGenre) ? _selectedGenre : null,
                            hint: const Text('Select genre', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
                            items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 15)))).toList(),
                            onChanged: (v) => setState(() => _selectedGenre = v),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _promptNewGenre,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.brand),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          _field(
            'CONTENT WARNINGS (optional)',
            TextField(
              controller: _warningsController,
              maxLines: 2,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'e.g. violence, strong language, drug use',
                hintStyle: TextStyle(color: AppTheme.muted),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'HASHTAGS (max 3) — type to search admin tags',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 8),
          if (_loadingTags) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2)),
          if (_selectedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedTags
                    .map((t) => InputChip(
                          label: Text(t.startsWith('#') ? t : '#$t'),
                          onDeleted: () => _removeTag(t),
                          backgroundColor: const Color(0xFFFFF0EE),
                          labelStyle: const TextStyle(color: Color(0xFFE85D4C), fontWeight: FontWeight.w600),
                        ))
                    .toList(),
              ),
            ),
          if (_availableTags.isEmpty && !_loadingTags)
            const Text('No hashtags available yet. Ask an admin to create some in the admin panel.', style: TextStyle(color: AppTheme.muted, fontSize: 13))
          else
            RawAutocomplete<String>(
              textEditingController: _tagInputController,
              focusNode: _tagFocus,
              optionsBuilder: (v) => _tagSuggestions(v.text),
              onSelected: _addTag,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type #tag…',
                    prefixIcon: const Icon(Icons.tag, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (v) {
                    _addTag(v);
                    onFieldSubmitted();
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(dense: true, title: Text('#$option'), onTap: () => onSelected(option));
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          const Text(
            'You can only use hashtags already created by an admin. New tags cannot be invented here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(publish: true),
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publish story'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.brand),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Publishing makes the story live. After 3 reports from different accounts it appears in Admin → Reports.',
              style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Color(0xFF888888))),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
