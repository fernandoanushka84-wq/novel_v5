class AppBootstrap {
  const AppBootstrap({
    required this.discoverTabs,
    required this.recentlyUpdated,
    required this.recentlyCompleted,
    required this.discoverBooks,
    required this.featuredBook,
    required this.exploreTopics,
    required this.libraryEntries,
    required this.writeScreen,
    required this.notifications,
    required this.menuSections,
    required this.profile,
    required this.achievements,
  });

  final List<String> discoverTabs;
  final List<BookCardModel> recentlyUpdated;
  final List<BookCardModel> recentlyCompleted;
  final List<BookCardModel> discoverBooks;
  final BookDetailModel featuredBook;
  final List<ExploreTopicModel> exploreTopics;
  final List<LibraryEntryModel> libraryEntries;
  final WriteScreenModel writeScreen;
  final List<NotificationModel> notifications;
  final List<MenuSectionModel> menuSections;
  final ProfileModel profile;
  final List<AchievementGroupModel> achievements;

  factory AppBootstrap.fromMap(Map<String, dynamic> map) {
    return AppBootstrap(
      discoverTabs: List<String>.from(map['discover_tabs'] as List<dynamic>),
      recentlyUpdated: (map['recently_updated'] as List<dynamic>)
          .map((item) => BookCardModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      recentlyCompleted: (map['recently_completed'] as List<dynamic>)
          .map((item) => BookCardModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      discoverBooks: (map['discover_books'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => BookCardModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      featuredBook: BookDetailModel.fromMap(
        map['featured_book'] as Map<String, dynamic>,
      ),
      exploreTopics: (map['explore_topics'] as List<dynamic>)
          .map(
            (item) => ExploreTopicModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
      libraryEntries: (map['library_entries'] as List<dynamic>)
          .map(
            (item) => LibraryEntryModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
      writeScreen: WriteScreenModel.fromMap(
        map['write_screen'] as Map<String, dynamic>,
      ),
      notifications: (map['notifications'] as List<dynamic>)
          .map(
            (item) => NotificationModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
      menuSections: (map['menu_sections'] as List<dynamic>)
          .map((item) => MenuSectionModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      profile: ProfileModel.fromMap(map['profile'] as Map<String, dynamic>),
      achievements: (map['achievements'] as List<dynamic>)
          .map(
            (item) =>
                AchievementGroupModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class BookCardModel {
  const BookCardModel({
    required this.id,
    required this.title,
    required this.author,
    this.authorUserId,
    required this.coverPath,
    required this.accentHex,
    required this.description,
    required this.statusText,
    required this.rating,
    required this.primaryGenre,
    required this.secondaryGenre,
    required this.sectionName,
    required this.isCompleted,
    required this.cta,
  });

  final int id;
  final String title;
  final String author;
  final int? authorUserId;
  final String coverPath;
  final String accentHex;
  final String description;
  final String statusText;
  final double rating;
  final String primaryGenre;
  final String secondaryGenre;
  final String sectionName;
  final bool isCompleted;
  final String cta;

  factory BookCardModel.fromMap(Map<String, dynamic> map) {
    return BookCardModel(
      id: map['id'] as int,
      title: map['title'] as String,
      author: map['author'] as String? ?? '',
      authorUserId: (map['author_user_id'] as num?)?.toInt(),
      coverPath: map['cover_path'] as String? ?? '',
      accentHex: map['accent_hex'] as String? ?? '#A1A1A1',
      description: map['description'] as String? ?? '',
      statusText: map['status_text'] as String? ?? '',
      rating: ((map['rating'] as num?) ?? 0).toDouble(),
      primaryGenre:
          map['primary_genre'] as String? ?? map['genre'] as String? ?? '',
      secondaryGenre: map['secondary_genre'] as String? ?? '',
      sectionName: map['section_name'] as String? ?? '',
      isCompleted: (map['is_completed'] as num?) == 1,
      cta: map['cta_label'] as String? ?? map['cta'] as String? ?? 'Read now',
    );
  }
}

class BookDetailModel {
  const BookDetailModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.statusText,
    required this.rating,
    required this.genre,
    required this.cta,
    this.coverPath = '',
    this.tags = const [],
    this.authorUserId,
    this.contentWarnings = '',
    this.lastUpdated = '',
  });

  final int id;
  final String title;
  final String author;
  final String description;
  final String statusText;
  final double rating;
  final String genre;
  final String cta;
  final String coverPath;
  final List<String> tags;
  final int? authorUserId;
  /// Free-text content warnings, e.g. "child abuse, drug use overdose".
  final String contentWarnings;
  final String lastUpdated;

  factory BookDetailModel.fromMap(Map<String, dynamic> map) {
    final warningsRaw = map['content_warnings'] ??
        map['content_warning'] ??
        map['warnings'] ??
        '';
    String warnings = '';
    if (warningsRaw is List) {
      warnings = warningsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).join(', ');
    } else {
      warnings = warningsRaw.toString();
    }
    return BookDetailModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? 'Untitled',
      author: map['author'] as String? ?? '',
      description: map['description'] as String? ?? '',
      statusText: map['status_text'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      genre: map['genre'] as String? ?? map['primary_genre'] as String? ?? '',
      cta: map['cta'] as String? ?? map['cta_label'] as String? ?? 'Read now',
      coverPath: map['cover_path'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? <dynamic>[]),
      authorUserId: (map['author_user_id'] as num?)?.toInt() ??
          (map['user_id'] as num?)?.toInt(),
      contentWarnings: warnings,
      lastUpdated: (map['last_updated'] ?? map['updated_at'] ?? map['updated_text'] ?? '').toString(),
    );
  }
}

class ExploreTopicModel {
  const ExploreTopicModel({required this.name, required this.topicCount});

  final String name;
  final int topicCount;

  factory ExploreTopicModel.fromMap(Map<String, dynamic> map) {
    return ExploreTopicModel(
      name: map['name'] as String,
      topicCount: map['topic_count'] as int,
    );
  }
}

class LibraryEntryModel {
  const LibraryEntryModel({
    required this.id,
    required this.book,
    required this.readingStatus,
    required this.updatedText,
    required this.chapters,
    required this.primaryGenre,
    required this.secondaryGenre,
  });

  final int id;
  final BookCardModel book;
  final String readingStatus;
  final String updatedText;
  final int chapters;
  final String primaryGenre;
  final String secondaryGenre;

  factory LibraryEntryModel.fromMap(Map<String, dynamic> map) {
    final bookMap = Map<String, dynamic>.from(
      (map['book'] as Map?) ?? const <String, dynamic>{},
    );
    // Ensure book id is present for navigation
    if (bookMap['id'] == null && map['book_id'] != null) {
      bookMap['id'] = map['book_id'];
    }
    return LibraryEntryModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      book: BookCardModel.fromMap(bookMap),
      readingStatus: (map['reading_status'] ?? 'Reading').toString(),
      updatedText: (map['updated_text'] ?? '').toString(),
      chapters: (map['chapters'] as num?)?.toInt() ?? 0,
      primaryGenre: (map['primary_genre'] ?? '').toString(),
      secondaryGenre: (map['secondary_genre'] ?? '').toString(),
    );
  }
}

class WriteScreenModel {
  const WriteScreenModel({
    required this.manageTabs,
    required this.storyTabs,
    required this.filterLabel,
    required this.sortLabel,
    required this.emptyTitle,
    required this.emptyCta,
  });

  final List<String> manageTabs;
  final List<String> storyTabs;
  final String filterLabel;
  final String sortLabel;
  final String emptyTitle;
  final String emptyCta;

  factory WriteScreenModel.fromMap(Map<String, dynamic> map) {
    return WriteScreenModel(
      manageTabs: List<String>.from(map['manage_tabs'] as List<dynamic>),
      storyTabs: List<String>.from(map['story_tabs'] as List<dynamic>),
      filterLabel: map['filter_label'] as String,
      sortLabel: map['sort_label'] as String,
      emptyTitle: map['empty_title'] as String,
      emptyCta: map['empty_cta'] as String,
    );
  }
}

class NotificationModel {
  const NotificationModel({
    required this.tab,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String tab;
  final String title;
  final String message;
  final String createdAt;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      tab: map['tab'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

class MenuSectionModel {
  const MenuSectionModel({required this.section, required this.items});

  final String section;
  final List<MenuItemModel> items;

  factory MenuSectionModel.fromMap(Map<String, dynamic> map) {
    return MenuSectionModel(
      section: map['section'] as String,
      items: (map['items'] as List<dynamic>)
          .map((item) => MenuItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MenuItemModel {
  const MenuItemModel({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final String icon;
  final String route;

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      label: map['label'] as String,
      icon: map['icon'] as String,
      route: map['route'] as String,
    );
  }
}

class ProfileModel {
  const ProfileModel({
    this.id,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.coverUrl,
    required this.following,
    required this.followers,
    required this.blocked,
    required this.chaptersRead,
    required this.socialKarma,
    required this.dayStreak,
    required this.readingLists,
  });

  final int? id;
  final String displayName;
  final String username;
  final String photoUrl;
  final String coverUrl;
  final int following;
  final int followers;
  final int blocked;
  final int chaptersRead;
  final int socialKarma;
  final int dayStreak;
  final List<ReadingListModel> readingLists;

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] as num?)?.toInt(),
      displayName: map['display_name'] as String,
      username: map['username'] as String,
      photoUrl: map['photo_url'] as String? ?? '',
      coverUrl: map['cover_url'] as String? ?? '',
      following: map['following'] as int,
      followers: map['followers'] as int,
      blocked: map['blocked'] as int,
      chaptersRead: map['chapters_read'] as int,
      socialKarma: map['social_karma'] as int,
      dayStreak: map['day_streak'] as int,
      readingLists: (map['reading_lists'] as List<dynamic>)
          .map((item) => ReadingListModel.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReadingListModel {
  const ReadingListModel({
    required this.id,
    required this.name,
    required this.storyCount,
    required this.coverPath,
  });

  final int id;
  final String name;
  final int storyCount;
  final String coverPath;

  factory ReadingListModel.fromMap(Map<String, dynamic> map) {
    return ReadingListModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] as String,
      storyCount: (map['story_count'] as num?)?.toInt() ?? 0,
      coverPath: map['cover_path'] as String? ?? '',
    );
  }
}

class AchievementGroupModel {
  const AchievementGroupModel({required this.groupName, required this.items});

  final String groupName;
  final List<AchievementItemModel> items;

  factory AchievementGroupModel.fromMap(Map<String, dynamic> map) {
    return AchievementGroupModel(
      groupName: map['group_name'] as String,
      items: (map['items'] as List<dynamic>)
          .map(
            (item) =>
                AchievementItemModel.fromMap(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AchievementItemModel {
  const AchievementItemModel({
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.badgeValue,
    required this.style,
  });

  final String title;
  final String subtitle;
  final String progressLabel;
  final String badgeValue;
  final String style;

  factory AchievementItemModel.fromMap(Map<String, dynamic> map) {
    return AchievementItemModel(
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      progressLabel: map['progress_label'] as String,
      badgeValue: map['badge_value'] as String,
      style: map['style'] as String,
    );
  }
}
