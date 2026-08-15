import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/app_bootstrap.dart';

class ApiService {
  ApiService();

  String? _authToken;

  String? get authTokenForPersistence => _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  static const String _productionApiBaseUrl =
      'https://lakmasachith-novel-app-backend.hf.space';

  static const String _overrideApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  String get _baseUrl {
    if (_overrideApiBaseUrl.isNotEmpty) {
      return _overrideApiBaseUrl;
    }

    if (kDebugMode) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const emulatorUrl = 'http://10.0.2.2:8000';
        debugPrint(
          'ApiService: Android debug default base URL is $emulatorUrl.\n'
          'If you are running on a physical device, pass --dart-define=API_BASE_URL=http://<PC_IP>:8000',
        );
        return emulatorUrl;
      }
      return 'http://127.0.0.1:8000';
    }

    return _productionApiBaseUrl;
  }

  Map<String, String> get _authHeaders {
    if (_authToken == null || _authToken!.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $_authToken'};
  }

  Future<http.Response> _requestWithHostFallback(
    Future<http.Response> Function(String baseUrl) request,
    Duration timeout,
  ) async {
    try {
      return await request(_baseUrl).timeout(timeout);
    } on http.ClientException {
      if (_baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    } on TimeoutException {
      if (_baseUrl == _productionApiBaseUrl) rethrow;
      return request(_productionApiBaseUrl).timeout(timeout);
    }
  }

  Future<http.Response> _get(
    String path, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  String resolveAssetUrl(String path) {
    if (path.isEmpty) return path;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // Strip query/hash noise if present
    final clean = trimmed.split('?').first.split('#').first;
    if (clean.contains('story_card_images/') ||
        clean.contains('/uploads/') ||
        clean.contains('\\uploads\\')) {
      final filename = clean.split('/').last.split('\\').last;
      if (filename.isNotEmpty) {
        return '$_baseUrl/uploads/$filename';
      }
    }
    if (!clean.startsWith('/')) {
      if (clean.startsWith('uploads/')) return '$_baseUrl/$clean';
      return '$_baseUrl/uploads/$clean';
    }
    // Absolute path like /uploads/foo.jpg
    if (clean.startsWith('/uploads/')) return '$_baseUrl$clean';
    final filename = clean.split('/').last;
    if (filename.contains('.') && !clean.contains('/api/')) {
      return '$_baseUrl/uploads/$filename';
    }
    return '$_baseUrl$clean';
  }

  Future<http.Response> _post(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _put(
    String path,
    Object body, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) => http.put(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json', ..._authHeaders},
        body: jsonEncode(body),
      ),
      timeout,
    );
  }

  Future<http.Response> _delete(
    String path, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _requestWithHostFallback(
      (baseUrl) =>
          http.delete(Uri.parse('$baseUrl$path'), headers: _authHeaders),
      timeout,
    );
  }

  void _ensureSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Backend request failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<AppBootstrap> fetchBootstrap() async {
    try {
      final response = await _get(
        '/api/bootstrap',
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        return AppBootstrap.fromMap(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return AppBootstrap.fromMap(_fallbackData);
  }

  Future<String> fetchContentVersion() async {
    try {
      final response = await _get(
        '/api/content/version',
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return payload['value']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final response = await _get(
        '/api/me',
        timeout: const Duration(seconds: 6),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  /// Raises on 401/403 so AuthService can force logout after ban/suspend.
  Future<Map<String, dynamic>> fetchMeStrict() async {
    final response = await _get('/api/me', timeout: const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_authErrorBody(response));
  }

  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    try {
      final response = await _get('/api/users/$userId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadWriterImage(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/write/upload-image'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadUserImage(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/me/upload-image'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/me',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(
    Uint8List bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/support/upload-attachment'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({String? tab}) async {
    try {
      final response = await _get(
        '/api/notifications${tab != null && tab.trim().isNotEmpty ? '?tab=${Uri.encodeComponent(tab)}' : ''}',
        timeout: const Duration(seconds: 7),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(
          payload['items'] as List<dynamic>,
        );
      }
    } catch (_) {}
    final fallback = (_fallbackData['notifications'] as List<dynamic>)
        .where((item) {
          if (tab == null || tab.trim().isEmpty) return true;
          return (item as Map<String, dynamic>)['tab'] == tab;
        })
        .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
        .toList();
    return fallback;
  }

  Future<void> submitSupportRequest(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/support/requests',
      payload,
      timeout: const Duration(seconds: 10),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to submit support request');
    }
  }

  Future<Map<String, dynamic>> verifyGoogleSignIn({
    String? idToken,
    String? accessToken,
  }) async {
    final response = await _post('/api/auth/google', {
      'id_token': idToken,
      'access_token': accessToken,
    }, timeout: const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _authErrorBody(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Authentication failed (${response.statusCode})';
  }

  Future<Map<String, dynamic>> verifyEmailSignIn(
    String email, {
    required String password,
    String mode = 'login',
    String? displayName,
  }) async {
    final response = await _post('/api/auth/email', {
      'email': email,
      'password': password,
      'mode': mode,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
    }, timeout: const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyGuestSignIn({String? deviceId}) async {
    final response = await _post(
      '/api/auth/guest',
      <String, dynamic>{
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      },
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_authErrorBody(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> searchStories({
    String query = '',
    String genre = '',
    double minRating = 0,
  }) async {
    try {
      final uri = Uri(
        path: '/api/search',
        queryParameters: {
          'query': query,
          'genre': genre,
          'min_rating': minRating.toString(),
        },
      );
      final response = await _get('${uri.path}?${uri.query}');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLibraryEntries() async {
    try {
      final response = await _get('/api/library');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchChatMessages() async {
    try {
      final response = await _get('/api/chat/messages');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyReviews() async {
    try {
      final response = await _get('/api/me/reviews');
      _ensureSuccessResponse(response);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['items'];
      if (items is! List) return const [];
      return items.map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final book = m['book'];
        if (book is Map) {
          final b = Map<String, dynamic>.from(book);
          m['book_id'] = m['book_id'] ?? b['id'];
          m['book_title'] = m['book_title'] ?? b['title'];
          m['book_author'] = m['book_author'] ?? b['author'];
          m['cover_path'] = m['cover_path'] ?? b['cover_path'];
        }
        return m;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addLibraryEntry(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/library',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> updateLibraryEntry(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/library/$id',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteLibraryEntry(int id) async {
    final response = await _delete(
      '/api/library/$id',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchReadingLists() async {
    try {
      final response = await _get('/api/reading-lists');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> createReadingList(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/reading-lists',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<Map<String, dynamic>> fetchReadingListDetail(int listId) async {
    final response = await _get('/api/reading-lists/$listId');
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Convenience: returns only the items array from a reading list detail.
  Future<List<Map<String, dynamic>>> fetchReadingListItems(int listId) async {
    final detail = await fetchReadingListDetail(listId);
    final items = detail['items'];
    if (items is List) {
      return List<Map<String, dynamic>>.from(items);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> addReadingListItem(int listId, int bookId) async {
    final response = await _post('/api/reading-lists/$listId/items', {
      'book_id': bookId,
    }, timeout: const Duration(seconds: 8));
    _ensureSuccessResponse(response);
  }

  Future<void> removeReadingListItem(int listId, int itemId) async {
    final response = await _delete(
      '/api/reading-lists/$listId/items/$itemId',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteReadingList(int listId) async {
    final response = await _delete(
      '/api/reading-lists/$listId',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchWriterStories() async {
    try {
      final response = await _get(
        '/api/write/stories',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> fetchStoryDetail(int storyId) async {
    final response = await _get('/api/books/$storyId');
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchBookReviews(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId/reviews');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> createBookReview(
    int bookId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/api/books/$bookId/reviews',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  /// Live chapter comments (Inkitt reader bottom-sheet).
  Future<List<Map<String, dynamic>>> fetchChapterComments({
    required int bookId,
    required int chapterNumber,
  }) async {
    try {
      final response = await _get(
        '/api/books/$bookId/chapters/$chapterNumber/comments',
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
        (payload['items'] as List<dynamic>? ?? const <dynamic>[]),
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> postChapterComment({
    required int bookId,
    required int chapterNumber,
    required String body,
  }) async {
    final response = await _post(
      '/api/books/$bookId/chapters/$chapterNumber/comments',
      {'body': body},
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['item'] is Map) {
      return Map<String, dynamic>.from(payload['item'] as Map);
    }
    return payload;
  }

  /// Chapter-end reaction counts + current user's selections.
  Future<Map<String, dynamic>> fetchChapterReactions({
    required int bookId,
    required int chapterNumber,
  }) async {
    try {
      final response = await _get(
        '/api/books/$bookId/chapters/$chapterNumber/reactions',
      );
      if (response.statusCode != 200) {
        return const <String, dynamic>{'counts': {}, 'mine': []};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'counts': {}, 'mine': []};
    }
  }

  /// Toggle a reaction label for the current user.
  Future<Map<String, dynamic>> toggleChapterReaction({
    required int bookId,
    required int chapterNumber,
    required String label,
  }) async {
    final response = await _post(
      '/api/books/$bookId/chapters/$chapterNumber/reactions',
      {'label': label},
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchUserStories(int userId) async {
    try {
      final response = await _get('/api/users/$userId/stories');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserReadingLists(int userId) async {
    try {
      final response = await _get('/api/users/$userId/reading-lists');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserReviews(int userId) async {
    try {
      final response = await _get('/api/users/$userId/reviews');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserWall(int userId) async {
    try {
      final response = await _get('/api/users/$userId/wall');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }


  Future<List<Map<String, dynamic>>> fetchUserActivity(int userId) async {
    try {
      final response = await _get('/api/users/$userId/activity');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> postUserWall(int userId, String body, {String? imagePath}) async {
    final response = await _post('/api/users/$userId/wall', {
      'body': body,
      if (imagePath != null && imagePath.isNotEmpty) 'image_path': imagePath,
    });
    _ensureSuccessResponse(response);
  }

  Future<Map<String, dynamic>> fetchBookLike(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId/like');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return const <String, dynamic>{'liked': false, 'likes_count': 0};
  }

  Future<Map<String, dynamic>> likeBook(int bookId) async {
    final response = await _post(
      '/api/books/$bookId/like',
      const <String, dynamic>{},
    );
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unlikeBook(int bookId) async {
    final response = await _delete('/api/books/$bookId/like');
    _ensureSuccessResponse(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> followAuthor(int authorId) async {
    final response = await _post(
      '/api/authors/$authorId/follow',
      const <String, dynamic>{},
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<Map<String, dynamic>> unfollowAuthor(int authorId) async {
    final response = await _delete('/api/authors/$authorId/follow');
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  Future<bool> fetchAuthorFollowing(int authorId) async {
    try {
      final response = await _get('/api/authors/$authorId/follow');
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return (payload['following'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch public book detail including tags and author_user_id.
  Future<Map<String, dynamic>?> fetchPublicBook(int bookId) async {
    try {
      final response = await _get('/api/books/$bookId');
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Distinct genres used across books (for genre dropdown).
  Future<List<String>> fetchGenres() async {
    try {
      final response = await _get('/api/genres');
      if (response.statusCode != 200) return const <String>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final items = payload['items'];
      if (items is! List) return const <String>[];
      return items
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  /// Create a genre so it appears in the shared dropdown for everyone.
  Future<String> createGenre(String name) async {
    final response = await _post(
      '/api/genres',
      {'name': name.trim()},
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final n = (body['name'] as String?)?.trim();
      if (n != null && n.isNotEmpty) return n;
    } catch (_) {}
    return name.trim();
  }

  /// Publish a writer story (sets status_text to Published).
  Future<void> publishWriterStory(int storyId) async {
    final response = await _post(
      '/api/write/stories/$storyId/publish',
      const <String, dynamic>{},
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  /// Report a story. After 3 unique reporters, it surfaces in Admin → Reports.
  Future<Map<String, dynamic>> reportBook(int bookId, {String reason = ''}) async {
    final response = await _post(
      '/api/books/$bookId/report',
      {'reason': reason},
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{'ok': true};
    }
  }

  /// List admin-managed hashtags (optional search query).
  Future<List<Map<String, dynamic>>> fetchTags({String? query}) async {
    try {
      final path = (query == null || query.trim().isEmpty)
          ? '/api/tags'
          : '/api/tags?q=${Uri.encodeQueryComponent(query.trim())}';
      final response = await _get(path);
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Books that have the given hashtag.
  Future<List<Map<String, dynamic>>> fetchBooksByTag(String tagName) async {
    try {
      final encoded = Uri.encodeComponent(tagName.trim().replaceFirst('#', ''));
      final response = await _get('/api/tags/$encoded/books');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Other public books by the same author (for "More Stories by Author").
  Future<List<Map<String, dynamic>>> fetchAuthorBooks(
    int authorId, {
    int? excludeBookId,
  }) async {
    try {
      final qs = excludeBookId != null ? '?exclude_id=$excludeBookId' : '';
      final response = await _get('/api/authors/$authorId/books$qs');
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<int, bool>> fetchAuthorsFollowing(List<int> authorIds) async {
    if (authorIds.isEmpty) return <int, bool>{};
    final idsParam = authorIds.join(',');
    try {
      final response = await _get('/api/authors/follow?ids=$idsParam');
      if (response.statusCode != 200) return <int, bool>{};
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = Map<String, dynamic>.from(
        payload['following'] as Map<String, dynamic>? ?? {},
      );
      final Map<int, bool> out = {};
      raw.forEach((k, v) {
        final key = int.tryParse(k);
        if (key != null) out[key] = (v as bool?) ?? false;
      });
      return out;
    } catch (_) {
      return <int, bool>{};
    }
  }

  Future<int> createWriterStory(Map<String, dynamic> payload) async {
    final response = await _post(
      '/api/write/stories',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['id'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateWriterStory(int id, Map<String, dynamic> payload) async {
    final response = await _put(
      '/api/write/stories/$id',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<void> deleteWriterStory(int id) async {
    final response = await _delete(
      '/api/write/stories/$id',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapters(int storyId) async {
    try {
      final response = await _get(
        '/api/write/stories/$storyId/chapters',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<int?> createStoryChapter(
    int storyId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '/api/write/stories/$storyId/chapters',
      payload,
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as int?;
  }

  Future<void> updateStoryChapter(
    int chapterId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _put(
      '/api/write/chapters/$chapterId',
      payload,
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  Future<List<Map<String, dynamic>>> fetchStoryChapterRevisions(
    int chapterId,
  ) async {
    try {
      final response = await _get(
        '/api/write/chapters/$chapterId/revisions',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(payload['items'] as List<dynamic>);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> deleteStoryChapter(int chapterId) async {
    final response = await _delete(
      '/api/write/chapters/$chapterId',
      timeout: const Duration(seconds: 8),
    );
    _ensureSuccessResponse(response);
  }

  static final Map<String, dynamic> _fallbackData = <String, dynamic>{
    'discover_tabs': ['New', 'Popular', 'Fantasy', 'Fanfiction', 'Newsfeed'],
    'recently_updated': [],
    'recently_completed': [],
    'discover_books': [],
    'featured_book': {
      'id': 1,
      'title': 'Loading...',
      'author': '',
      'description': '',
      'status_text': '',
      'rating': 0,
      'genre': '',
      'cta': 'Read now',
    },
    'explore_topics': [],
    'library_entries': [],
    'write_screen': {
      'manage_tabs': ['Manage Stories', 'Analytics'],
      'story_tabs': ['Submitted', 'Drafts'],
      'filter_label': 'All stories',
      'sort_label': 'Recently Updated',
      'empty_title': "You haven't submitted any story yet",
      'empty_cta': 'Submit Stories',
    },
    'notifications': [],
    'menu_sections': [],
    'profile': {
      'display_name': 'Reader',
      'username': '@reader',
      'following': 0,
      'followers': 0,
      'blocked': 0,
      'chapters_read': 0,
      'social_karma': 0,
      'day_streak': 0,
      'reading_lists': [],
    },
    'achievements': [],
  };


  // ---------------------------------------------------------------------------
  // Wingsaga feature APIs
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> checkUsername(String q) async {
    final response = await _get('/api/username/check?q=${Uri.encodeQueryComponent(q)}');
    if (response.statusCode >= 400) return {'available': false};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setUsername(String username) async {
    final response = await _requestWithHostFallback(
      (base) => http.put(
        Uri.parse('$base/api/me/username'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      ),
      const Duration(seconds: 12),
    );
    if (response.statusCode >= 400) {
      throw Exception((jsonDecode(response.body) is Map ? (jsonDecode(response.body)['detail'] ?? response.body) : response.body).toString());
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchSocialLinks(int userId) async {
    final response = await _get('/api/users/$userId/social-links');
    if (response.statusCode >= 400) {
      return {'instagram': '', 'twitter': '', 'facebook': '', 'tiktok': '', 'youtube': '', 'website': ''};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> updateSocialLinks(Map<String, String> links) async {
    final response = await _requestWithHostFallback(
      (base) => http.put(
        Uri.parse('$base/api/me/social-links'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(links),
      ),
      const Duration(seconds: 12),
    );
    if (response.statusCode >= 400) {
      throw Exception((jsonDecode(response.body) is Map ? (jsonDecode(response.body)['detail'] ?? response.body) : response.body).toString());
    }
  }

  Future<Map<String, dynamic>> fetchShareProfile(int userId) async {
    final response = await _get('/api/users/$userId/share');
    if (response.statusCode >= 400) {
      throw Exception((jsonDecode(response.body) is Map ? (jsonDecode(response.body)['detail'] ?? response.body) : response.body).toString());
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchContinueReading() async {
    final response = await _get('/api/home/continue-reading');
    if (response.statusCode >= 400) return <Map<String, dynamic>>[];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchLatestBooks({int limit = 20}) async {
    final response = await _get('/api/home/latest-books?limit=$limit');
    if (response.statusCode >= 400) return <Map<String, dynamic>>[];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveReadingProgress({
    required int bookId,
    required int chapterNumber,
    int progressPercent = 0,
  }) async {
    final response = await _requestWithHostFallback(
      (base) => http.post(
        Uri.parse('$base/api/home/reading-progress'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_id': bookId,
          'chapter_number': chapterNumber,
          'progress_percent': progressPercent,
        }),
      ),
      const Duration(seconds: 12),
    );
    if (response.statusCode >= 400) {
      // Non-fatal for guests / offline
      debugPrint('saveReadingProgress failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchGuestRecommendations({String country = ''}) async {
    final q = country.isEmpty ? '' : '?country=${Uri.encodeQueryComponent(country)}';
    final response = await _get('/api/guest/recommendations$q');
    if (response.statusCode >= 400) {
      return {'items': <dynamic>[], 'languages': <dynamic>['English']};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> submitDeveloperHelp({
    required String title,
    required String description,
    String category = 'feature',
    String email = '',
  }) async {
    final response = await _requestWithHostFallback(
      (base) => http.post(
        Uri.parse('$base/api/developer-help'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          'email': email,
        }),
      ),
      const Duration(seconds: 12),
    );
    if (response.statusCode >= 400) {
      throw Exception((jsonDecode(response.body) is Map ? (jsonDecode(response.body)['detail'] ?? response.body) : response.body).toString());
    }
  }

  Future<List<Map<String, dynamic>>> fetchWriterAchievements(int userId) async {
    final response = await _get('/api/users/$userId/writer-achievements');
    if (response.statusCode >= 400) return <Map<String, dynamic>>[];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

}
