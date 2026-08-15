import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/app_bootstrap.dart';
import '../../data/services/api_service.dart';
import 'story_detail_screen.dart';

/// Galatea-style profile: cover + overlapping avatar, stats, About/Stories/Wall/Activity/Reviews.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.apiService,
    required this.achievements,
    this.viewingUserId,
  });

  final ProfileModel profile;
  final ApiService apiService;
  final List<AchievementGroupModel> achievements;
  final int? viewingUserId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;

  Map<String, dynamic>? _userProfile;
  bool _loadingProfile = true;
  bool _isFollowing = false;
  bool _isOwnProfile = true;

  List<Map<String, dynamic>> _stories = const [];
  List<Map<String, dynamic>> _wall = const [];
  List<Map<String, dynamic>> _activity = const [];
  List<Map<String, dynamic>> _reviews = const [];
  List<Map<String, dynamic>> _readingLists = const [];
  String _storyQuery = '';
  String _storySort = 'Recently Updated';
  String _storyFilter = 'All stories';

  static const Color brand = Color(0xFF00A88E);
  static const Color muted = Color(0xFF8A8F98);
  static const Color cardBg = Color(0xFFF7F8FA);
  static const Color border = Color(0xFFE8EAED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingProfile = true);
    try {
      final me = await widget.apiService.fetchMe();
      final meId = _asInt(me['id'] ?? me['user_id']);
      final viewId = widget.viewingUserId;
      _isOwnProfile = viewId == null || (meId != 0 && viewId == meId);

      final int targetId = _isOwnProfile
          ? (meId != 0 ? meId : (widget.profile.id ?? 0))
          : (viewId ?? 0);

      if (_isOwnProfile) {
        _userProfile = me.isNotEmpty ? me : {
          'id': widget.profile.id,
          'display_name': widget.profile.displayName,
          'username': widget.profile.username,
          'following': widget.profile.following,
          'followers': widget.profile.followers,
          'chapters_read': widget.profile.chaptersRead,
          'social_karma': widget.profile.socialKarma,
          'day_streak': widget.profile.dayStreak,
          'photo_url': widget.profile.photoUrl,
          'cover_url': widget.profile.coverUrl,
        };
      } else {
        _userProfile = await widget.apiService.fetchProfile(viewId!);
        try {
          _isFollowing = await widget.apiService.fetchAuthorFollowing(viewId);
        } catch (_) {
          _isFollowing = false;
        }
      }

      // Always load from backend — never use bootstrap fake lists/stories
      List stories = const [];
      List wall = const [];
      List activity = const [];
      List reviews = const [];
      List lists = const [];

      if (targetId > 0) {
        final results = await Future.wait([
          (_isOwnProfile
                  ? widget.apiService.fetchWriterStories()
                  : widget.apiService.fetchUserStories(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
          widget.apiService.fetchUserWall(targetId).catchError((_) => <Map<String, dynamic>>[]),
          widget.apiService.fetchUserActivity(targetId).catchError((_) => <Map<String, dynamic>>[]),
          (_isOwnProfile
                  ? widget.apiService.fetchMyReviews()
                  : widget.apiService.fetchUserReviews(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
          (_isOwnProfile
                  ? widget.apiService.fetchReadingLists()
                  : widget.apiService.fetchUserReadingLists(targetId))
              .catchError((_) => <Map<String, dynamic>>[]),
        ]);
        stories = List<Map<String, dynamic>>.from(results[0] as List);
        wall = List<Map<String, dynamic>>.from(results[1] as List);
        activity = List<Map<String, dynamic>>.from(results[2] as List);
        reviews = List<Map<String, dynamic>>.from(results[3] as List);
        lists = List<Map<String, dynamic>>.from(results[4] as List);
      }

      if (!mounted) return;
      setState(() {
        _stories = stories.cast<Map<String, dynamic>>();
        _wall = wall.cast<Map<String, dynamic>>();
        _activity = activity.cast<Map<String, dynamic>>();
        _reviews = reviews.cast<Map<String, dynamic>>();
        _readingLists = lists.cast<Map<String, dynamic>>();
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  String _s(dynamic v) => v == null ? '' : '$v'.trim();
  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  String get _displayName {
    final n = _s(_userProfile?['display_name']);
    if (n.isNotEmpty) return n;
    if (widget.profile.displayName.trim().isNotEmpty) {
      return widget.profile.displayName;
    }
    return widget.profile.username;
  }

  String get _username {
    final u = _s(_userProfile?['username']);
    if (u.isNotEmpty) return u.replaceAll('@', '');
    return widget.profile.username.replaceAll('@', '');
  }

  String get _bio {
    final b = _s(_userProfile?['bio']);
    if (b.isNotEmpty) return b;
    return 'Just a reader turning pages into worlds.';
  }

  String get _aboutLong {
    final a = _s(_userProfile?['about'] ?? _userProfile?['bio']);
    return a.isNotEmpty
        ? a
        : _bio;
  }

  int get _following =>
      _asInt(_userProfile?['following'] ?? widget.profile.following);
  int get _followers =>
      _asInt(_userProfile?['followers'] ?? widget.profile.followers);
  int get _chaptersRead =>
      _asInt(_userProfile?['chapters_read'] ?? widget.profile.chaptersRead);
  int get _karma =>
      _asInt(_userProfile?['social_karma'] ?? widget.profile.socialKarma);
  int get _streak =>
      _asInt(_userProfile?['day_streak'] ?? widget.profile.dayStreak);

  String get _avatarUrl {
    final p = _s(_userProfile?['avatar_url'] ?? _userProfile?['photo_url']);
    if (p.isEmpty) return '';
    return widget.apiService.resolveAssetUrl(p);
  }

  String get _coverUrl {
    final p = _s(_userProfile?['cover_url'] ?? _userProfile?['banner_url']);
    if (p.isEmpty) return '';
    return widget.apiService.resolveAssetUrl(p);
  }

  Future<void> _toggleFollow() async {
    final id = widget.viewingUserId ?? widget.profile.id;
    if (id == null || _isOwnProfile) return;
    final wasFollowing = _isFollowing;
    try {
      final dynamic res = wasFollowing
          ? await widget.apiService.unfollowAuthor(id)
          : await widget.apiService.followAuthor(id);
      if (!mounted) return;
      int? followers;
      if (res is Map) {
        followers = (res['followers'] as num?)?.toInt();
      }
      setState(() {
        _isFollowing = !wasFollowing;
        if (_userProfile != null) {
          if (followers != null) {
            _userProfile = {..._userProfile!, 'followers': followers};
          } else {
            final cur = _asInt(_userProfile!['followers']);
            _userProfile = {
              ..._userProfile!,
              'followers': _isFollowing ? cur + 1 : (cur > 0 ? cur - 1 : 0),
            };
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Share profile', style: TextStyle(color: Color(0xFF2B6CB0))),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Block user', style: TextStyle(color: Color(0xFF2B6CB0))),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Report user', style: TextStyle(color: Color(0xFF2B6CB0))),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              title: const Text('Cancel', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    if (!_isOwnProfile) return;
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);
    String photoUrl = _s(_userProfile?['photo_url'] ?? _userProfile?['avatar_url']);
    String coverUrl = _s(_userProfile?['cover_url']);
    bool uploading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Edit profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display name')),
                  TextField(controller: bioCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () async {
                                  final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                                  if (picked == null) return;
                                  setModal(() => uploading = true);
                                  try {
                                    final bytes = await picked.readAsBytes();
                                    final res = await widget.apiService.uploadUserImage(bytes, picked.name);
                                    final path = (res['path'] ?? res['photo_url'] ?? '').toString();
                                    if (path.isNotEmpty) setModal(() => photoUrl = path);
                                  } finally {
                                    setModal(() => uploading = false);
                                  }
                                },
                          icon: const Icon(Icons.person),
                          label: Text(uploading ? 'Uploading…' : 'Profile photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () async {
                                  final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                                  if (picked == null) return;
                                  setModal(() => uploading = true);
                                  try {
                                    final bytes = await picked.readAsBytes();
                                    final res = await widget.apiService.uploadUserImage(bytes, picked.name);
                                    final path = (res['path'] ?? res['cover_url'] ?? '').toString();
                                    if (path.isNotEmpty) setModal(() => coverUrl = path);
                                  } finally {
                                    setModal(() => uploading = false);
                                  }
                                },
                          icon: const Icon(Icons.image),
                          label: const Text('Cover'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white),
                    onPressed: () async {
                      try {
                        await widget.apiService.updateMe({
                          'display_name': nameCtrl.text.trim(),
                          'bio': bioCtrl.text.trim(),
                          if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
                          if (coverUrl.isNotEmpty) 'cover_url': coverUrl,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadAll();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredStories {
    var list = List<Map<String, dynamic>>.from(_stories);
    final q = _storyQuery.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) {
        final title = _s(s['title']).toLowerCase();
        final desc = _s(s['description']).toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList();
    }
    bool isCompleted(Map<String, dynamic> s) {
      final st = _s(s['status_text']).toLowerCase();
      final flag = s['is_completed'];
      if (flag == true || flag == 1 || '$flag' == '1') return true;
      return st.contains('complete') || st.contains('finished') || st == 'published';
    }
    if (_storyFilter == 'Completed') {
      list = list.where(isCompleted).toList();
    } else if (_storyFilter == 'In progress') {
      list = list.where((s) => !isCompleted(s)).toList();
    }
    if (_storySort == 'Name') {
      list.sort((a, b) => _s(a['title']).toLowerCase().compareTo(_s(b['title']).toLowerCase()));
    } else if (_storySort == 'Last Read') {
      list.sort((a, b) => _s(b['updated_at'] ?? b['created_at']).compareTo(_s(a['updated_at'] ?? a['created_at'])));
    }
    // Recently Updated: keep API order (already newest-first when possible)
    return list;
  }

  void _showStorySortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final opt in ['Recently Updated', 'Name', 'Last Read'])
                RadioListTile<String>(
                  dense: true,
                  activeColor: brand,
                  title: Text(opt),
                  value: opt,
                  groupValue: _storySort,
                  onChanged: (v) {
                    setState(() => _storySort = v!);
                    Navigator.pop(ctx);
                  },
                ),
              const Text('Filter', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final opt in ['All stories', 'Completed', 'In progress'])
                RadioListTile<String>(
                  dense: true,
                  activeColor: brand,
                  title: Text(opt),
                  value: opt,
                  groupValue: _storyFilter,
                  onChanged: (v) {
                    setState(() => _storyFilter = v!);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: brand))
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 168,
                    pinned: true,
                    backgroundColor: const Color(0xFF1A2030),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: _showMoreMenu,
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_coverUrl.isNotEmpty)
                            Image.network(
                              _coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _defaultCover(),
                            )
                          else
                            _defaultCover(),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildIdentityBlock()),
                  // Sticky tabs
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: brand,
                        unselectedLabelColor: muted,
                        indicatorColor: brand,
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        tabs: const [
                          Tab(text: 'About'),
                          Tab(text: 'Stories'),
                          Tab(text: 'Wall'),
                          Tab(text: 'Activity'),
                          Tab(text: 'Reviews'),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(),
                  _buildStoriesTab(),
                  _buildWallTab(),
                  _buildActivityTab(),
                  _buildReviewsTab(),
                ],
              ),
            ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2030), Color(0xFF2D3A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, size: 64, color: Colors.white24),
      ),
    );
  }

  /// Avatar overlaps cover; name / bio / stats / Follow sit on white below.
  Widget _buildIdentityBlock() {
    return Transform.translate(
      offset: const Offset(0, -36),
      child: Column(
        children: [
          // Avatar centered, overlapping cover
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
              child: _avatarUrl.isEmpty
                  ? Text(
                      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: muted),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          // Name + verified
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: brand, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('@$_username', style: const TextStyle(fontSize: 14, color: muted)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _bio,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFF4A4A4A)),
            ),
          ),
          const SizedBox(height: 14),
          // Following | Followers
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _countCol('$_following', 'Following'),
              Container(width: 1, height: 28, color: border, margin: const EdgeInsets.symmetric(horizontal: 20)),
              _countCol('$_followers', 'Followers'),
            ],
          ),
          const SizedBox(height: 14),
          // Follow / Edit button
          OutlinedButton(
            onPressed: _isOwnProfile ? _editProfile : _toggleFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text(
              _isOwnProfile ? 'Edit profile' : (_isFollowing ? 'Following' : 'Follow'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _countCol(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }

  // ─── About ───────────────────────────────────────────────
  Widget _buildAboutTab() {
    final lists = _readingLists.isNotEmpty
        ? _readingLists
        : widget.profile.readingLists
            .map((l) => {
                  'name': l.name,
                  'story_count': l.storyCount,
                  'cover_path': l.coverPath,
                })
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // Stat cards — 2 top + 1 full width (video layout)
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF9B59B6),
                label: 'CHAPTERS READ',
                value: '$_chaptersRead',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.campaign_outlined,
                iconColor: brand,
                label: 'SOCIAL KARMA',
                value: '$_karma',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _statCard(
          icon: Icons.blur_on,
          iconColor: const Color(0xFF5B9BD5),
          label: 'DAY READING STREAK',
          value: '$_streak',
        ),
        const SizedBox(height: 22),
        Text(
          'About $_displayName',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _aboutLong,
          style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF3A3A3A)),
        ),
        const SizedBox(height: 24),
        const Text('Reading Lists', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Public Reading Lists', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        if (lists.isEmpty)
          const Text('No public reading lists yet.', style: TextStyle(color: muted))
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lists.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final list = lists[i];
                final name = _s(list['name'] ?? list['title']);
                final count = _asInt(list['story_count'] ?? list['count']);
                // Multi-cover collage (Inkitt-style stacked book covers)
                final List<String> coverList = [];
                final dynamic rawCovers = list['covers'];
                if (rawCovers is List) {
                  for (final c in rawCovers) {
                    final s = _s(c);
                    if (s.isNotEmpty) coverList.add(s);
                  }
                }
                if (coverList.isEmpty) {
                  final single = _s(list['cover_path'] ?? list['cover_url']);
                  if (single.isNotEmpty) coverList.add(single);
                }
                final listId = _asInt(list['id']);
                return GestureDetector(
                  onTap: listId > 0
                      ? () async {
                          try {
                            final detail = await widget.apiService.fetchReadingListDetail(listId);
                            if (!context.mounted) return;
                            final items = detail['items'];
                            final itemList = items is List
                                ? List<Map<String, dynamic>>.from(items)
                                : <Map<String, dynamic>>[];
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (ctx) {
                                return DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.7,
                                  maxChildSize: 0.95,
                                  minChildSize: 0.4,
                                  builder: (_, scrollCtrl) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 40, height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name.isEmpty ? 'Reading List' : name,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                                ),
                                              ),
                                              Text('$count Stories', style: const TextStyle(color: muted, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: itemList.isEmpty
                                              ? const Center(child: Text('No stories in this list yet.'))
                                              : ListView.builder(
                                                  controller: scrollCtrl,
                                                  itemCount: itemList.length,
                                                  itemBuilder: (_, i) {
                                                    final it = itemList[i];
                                                    final book = it['book'] is Map
                                                        ? Map<String, dynamic>.from(it['book'] as Map)
                                                        : it;
                                                    final title = _s(book['title']);
                                                    final author = _s(book['author']);
                                                    final cPath = _s(book['cover_path'] ?? book['cover_url']);
                                                    final bookId = _asInt(book['id'] ?? it['book_id']);
                                                    return ListTile(
                                                      leading: cPath.isNotEmpty
                                                          ? ClipRRect(
                                                              borderRadius: BorderRadius.circular(4),
                                                              child: Image.network(
                                                                widget.apiService.resolveAssetUrl(cPath),
                                                                width: 40, height: 56, fit: BoxFit.cover,
                                                                errorBuilder: (_, _, _) => const Icon(Icons.menu_book),
                                                              ),
                                                            )
                                                          : const Icon(Icons.menu_book),
                                                      title: Text(title.isEmpty ? 'Story' : title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      subtitle: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      onTap: bookId > 0
                                                          ? () {
                                                              Navigator.pop(ctx);
                                                              Navigator.of(context).push(
                                                                MaterialPageRoute<void>(
                                                                  builder: (_) => StoryDetailScreen(
                                                                    apiService: widget.apiService,
                                                                    book: BookDetailModel(
                                                                      id: bookId,
                                                                      title: title,
                                                                      author: author,
                                                                      description: _s(book['description']),
                                                                      statusText: _s(book['status_text']),
                                                                      rating: (book['rating'] as num?)?.toDouble() ?? 0,
                                                                      genre: _s(book['genre'] ?? book['primary_genre']),
                                                                      cta: 'Read',
                                                                      coverPath: cPath,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          : null,
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
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open list: $e')),
                            );
                          }
                        }
                      : null,
                  child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: coverList.isEmpty
                              ? Container(
                                  color: cardBg,
                                  child: const Icon(Icons.collections_bookmark_outlined, color: muted),
                                )
                              : _ReadingListCollage(
                                  covers: coverList
                                      .map((c) => widget.apiService.resolveAssetUrl(c))
                                      .toList(),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name.isEmpty ? 'List' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        '$count Stories',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                );
              },
            ),
          ),
        const SizedBox(height: 28),
        const Text('Achievements', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildAchievementsGrid(),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    final groups = widget.achievements;
    if (groups.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    final items = <Widget>[];
    for (final g in groups) {
      for (final a in g.items) {
        items.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        );
      }
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: items.take(8).toList(),
    );
  }

  // ─── Stories ─────────────────────────────────────────────
  Widget _buildStoriesTab() {
    final list = _filteredStories;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _storyQuery = v),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: muted),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              _filterChip(_storyFilter, onTap: _showStorySortSheet),
              const SizedBox(width: 8),
              _filterChip(_storySort, onTap: _showStorySortSheet),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No stories yet', style: TextStyle(color: muted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, i) => _storyRow(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.contains('All') || label.contains('Completed') || label.contains('progress'))
              const Icon(Icons.filter_list, size: 14, color: muted)
            else
              const SizedBox.shrink(),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const Icon(Icons.chevron_right, size: 16, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _storyRow(Map<String, dynamic> s) {
    final title = _s(s['title']);
    final desc = _s(s['description']);
    final genre = _s(s['genre'] ?? s['primary_genre']);
    final rating = s['rating'];
    final status = _s(s['status_text']);
    final chapters = _asInt(s['chapter_count'] ?? s['chapters']);
    final cover = _s(s['cover_path'] ?? s['cover_url']);
    final completed = status.toLowerCase().contains('complete') || status.toLowerCase().contains('publish');

    return InkWell(
      onTap: () {
        final id = _asInt(s['id']);
        if (id <= 0) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoryDetailScreen(
              apiService: widget.apiService,
              book: BookDetailModel(
                id: id,
                title: title,
                author: _s(s['author']),
                description: desc,
                statusText: status,
                rating: (rating is num) ? rating.toDouble() : double.tryParse('$rating') ?? 0,
                genre: genre,
                cta: _s(s['cta_label']).isEmpty ? 'Read now' : _s(s['cta_label']),
                coverPath: cover,
                authorUserId: _asInt(s['author_user_id'] ?? s['user_id']),
              ),
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: cover.isNotEmpty
                ? Image.network(
                    widget.apiService.resolveAssetUrl(cover),
                    width: 72,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(width: 72, height: 100, color: cardBg),
                  )
                : Container(width: 72, height: 100, color: cardBg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const Icon(Icons.bookmark_border, size: 20, color: muted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc.isEmpty ? 'No description' : desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: muted, height: 1.3),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Color(0xFFF5A623)),
                            const SizedBox(width: 2),
                            Text('$rating', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (genre.isNotEmpty)
                      _tagChip(genre),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      completed ? Icons.check_circle : Icons.timelapse,
                      size: 14,
                      color: completed ? brand : muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      completed
                          ? 'Completed${chapters > 0 ? ' · $chapters Chapters' : ''}'
                          : (chapters > 0 ? '$chapters Chapters' : status),
                      style: TextStyle(fontSize: 11, color: completed ? brand : muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF4A4A4A))),
    );
  }


  Future<void> _composeWallPost() async {
    // Wall target = profile being viewed (other user or self)
    int resolvedId = widget.viewingUserId ?? 0;
    if (resolvedId == 0) {
      resolvedId = _asInt(_userProfile?['id']);
    }
    if (resolvedId == 0) {
      resolvedId = widget.profile.id ?? 0;
    }
    if (resolvedId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to post on the wall')),
      );
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Write something to $_username',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Say something…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brand,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || text.isEmpty) return;
    try {
      await widget.apiService.postUserWall(resolvedId, text);
      if (!mounted) return;
      // Reload wall posts only (keep other tabs)
      final wall = await widget.apiService.fetchUserWall(resolvedId);
      if (!mounted) return;
      setState(() {
        _wall = wall;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted to wall')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post: $e')),
      );
    }
  }

  // ─── Wall ────────────────────────────────────────────────
  Widget _buildWallTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Composer — posts to backend wall
        InkWell(
          onTap: _composeWallPost,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cardBg,
                backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                child: _avatarUrl.isEmpty
                    ? Text(_displayName.isNotEmpty ? _displayName[0] : '?', style: const TextStyle(color: muted))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Write something to $_username',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.image_outlined, color: muted),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_wall.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No wall posts yet', style: TextStyle(color: muted))),
          )
        else
          ..._wall.map((m) {
            final name = _s(m['sender_name'] ?? m['username'] ?? m['display_name'] ?? 'User');
            final body = _s(m['message'] ?? m['body'] ?? m['text']);
            final when = _s(m['created_at'] ?? m['time'] ?? '');
            final img = _s(m['image_url'] ?? m['image_path'] ?? m['attachment_path'] ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cardBg,
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            if (when.isNotEmpty)
                              Text(when, style: const TextStyle(fontSize: 11, color: muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz, color: muted, size: 18),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(body, style: const TextStyle(fontSize: 14, height: 1.35)),
                  ],
                  if (img.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.apiService.resolveAssetUrl(img),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.favorite_border, size: 18, color: muted),
                      SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline, size: 18, color: muted),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─── Activity ────────────────────────────────────────────
  Widget _buildActivityTab() {
    if (_activity.isEmpty) {
      return const Center(child: Text('No recent activity', style: TextStyle(color: muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _activity.length,
      itemBuilder: (context, i) {
        final n = _activity[i];
        final title = _s(n['title']);
        final msg = _s(n['message']);
        final when = _s(n['created_at'] ?? '');
        final cover = _s(n['cover_path']);
        final bookId = _asInt(n['book_id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cardBg,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty
                        ? Text(_displayName.isNotEmpty ? _displayName[0] : '?', style: const TextStyle(fontSize: 12))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? _displayName : title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (when.isNotEmpty)
                          Text(when, style: const TextStyle(fontSize: 11, color: muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, color: muted, size: 18),
                ],
              ),
              if (msg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(msg, style: const TextStyle(fontSize: 14, height: 1.35)),
              ],
              if (cover.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: bookId > 0
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoryDetailScreen(
                                apiService: widget.apiService,
                                book: BookDetailModel(
                                  id: bookId,
                                  title: title,
                                  author: _displayName,
                                  description: msg,
                                  statusText: '',
                                  rating: 0,
                                  genre: '',
                                  cta: 'Read now',
                                  coverPath: cover,
                                ),
                              ),
                            ),
                          );
                        }
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.apiService.resolveAssetUrl(cover),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Reviews ─────────────────────────────────────────────
  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('No reviews yet', style: TextStyle(color: muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const Divider(height: 28),
      itemBuilder: (context, i) {
        final r = _reviews[i];
        final bookTitle = _s(r['book_title'] ?? r['title'] ?? 'Story');
        final author = _s(r['book_author'] ?? r['author'] ?? '');
        final cover = _s(r['cover_path'] ?? r['book_cover'] ?? '');
        final stars = _asInt(r['rating'] ?? r['stars'] ?? 0);
        final plot = _asInt(r['plot_score'] ?? r['plot'] ?? stars);
        final writing = _asInt(r['writing_score'] ?? r['writing_style'] ?? stars);
        final grammar = _asInt(r['grammar_score'] ?? r['grammar'] ?? stars);
        final headline = _s(r['headline'] ?? '');
        final body = _s(r['body'] ?? r['comment'] ?? r['review'] ?? r['text'] ?? '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: cover.isNotEmpty
                      ? Image.network(
                          widget.apiService.resolveAssetUrl(cover),
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(width: 40, height: 56, color: cardBg),
                        )
                      : Container(width: 40, height: 56, color: cardBg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bookTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (author.isNotEmpty)
                        Text('by $author', style: const TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final bid = _asInt(r['book_id']);
                    if (bid <= 0) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: widget.apiService,
                          book: BookDetailModel(
                            id: bid,
                            title: bookTitle,
                            author: author,
                            description: body,
                            statusText: '',
                            rating: stars.toDouble(),
                            genre: '',
                            cta: 'Read now',
                            coverPath: cover,
                          ),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: const Size(0, 32),
                    side: const BorderSide(color: border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Read', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.bookmark_border, size: 20, color: muted),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (j) {
                return Icon(
                  j < stars ? Icons.star : Icons.star_border,
                  size: 18,
                  color: const Color(0xFFF5A623),
                );
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                _scoreChip('Plot $plot'),
                _scoreChip('Writing Style $writing'),
                _scoreChip('Grammar & Punctuation $grammar'),
              ],
            ),
            if (headline.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(headline, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF3A3A3A))),
            ],
          ],
        );
      },
    );
  }

  Widget _scoreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}


/// Inkitt-style multi-cover collage for reading list cards (2x2 grid of covers).
class _ReadingListCollage extends StatelessWidget {
  const _ReadingListCollage({required this.covers});

  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    final urls = covers.take(4).toList();
    if (urls.length == 1) {
      return Image.network(
        urls.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFFF1F5F9)),
      );
    }
    // 2x2 grid
    while (urls.length < 4) {
      urls.add('');
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(urls[0])),
              const SizedBox(width: 2),
              Expanded(child: _cell(urls[1])),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cell(urls[2])),
              const SizedBox(width: 2),
              Expanded(child: _cell(urls[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(String url) {
    if (url.isEmpty) {
      return Container(color: const Color(0xFFE8EEF5));
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFFE8EEF5)),
    );
  }
}
