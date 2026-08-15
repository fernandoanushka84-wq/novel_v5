// // Paste these methods into api_service.dart (before followAuthor).
// // Then change followAuthor/unfollowAuthor to return Future<Map<String, dynamic>>.









//   Future<Map<String, dynamic>> fetchBookLike(int bookId) async {
//     try {
//       final response = await _get('/api/books/$bookId/like');
//       if (response.statusCode == 200) {
//         return jsonDecode(response.body) as Map<String, dynamic>;
//       }
//     } catch (_) {}
//     return const <String, dynamic>{'liked': false, 'likes_count': 0};
//   }

//   Future<Map<String, dynamic>> likeBook(int bookId) async {
//     final response = await _post(
//       '/api/books/$bookId/like',
//       const <String, dynamic>{},
//     );
//     _ensureSuccessResponse(response);
//     return jsonDecode(response.body) as Map<String, dynamic>;
//   }

//   Future<Map<String, dynamic>> unlikeBook(int bookId) async {
//     final response = await _delete('/api/books/$bookId/like');
//     _ensureSuccessResponse(response);
//     return jsonDecode(response.body) as Map<String, dynamic>;
//   }
