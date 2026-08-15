# Backend / Flutter fixes (followers, likes, chapter cover)

## Issues fixed
1. `/api/me` always returned followers=0, following=0 — now counts `author_follows`.
2. Follow/unfollow returns live `followers` count so profile UI can update.
3. Story likes: new `book_likes` table UNIQUE(user_id, book_id) — one like per user.
   - GET/POST/DELETE `/api/books/{book_id}/like`
4. Story detail + chapter reader call like API (no infinite local increment).
5. Chapter list (`reader_screen`) no longer shows cover image when opening chapters.

## Install
Copy from zip / artifacts:
- `backend/app/main.py` (patched)
- `backend/app/startup_tasks.py` (book_likes table)
- `lib/data/services/api_service.dart`
- `lib/ui/screens/story_detail_screen.dart`
- `lib/ui/screens/chapter_reader_screen.dart`
- `lib/ui/screens/reader_screen.dart`
- `lib/ui/screens/profile_screen.dart` (Galatea UI)

Restart backend so startup_tasks creates `book_likes`.
