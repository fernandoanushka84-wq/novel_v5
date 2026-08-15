# Apply remaining novel app fixes

## Already on GitHub (main)

- `lib/data/models/app_bootstrap.dart` — `ReadingListModel` now has `id`
- `lib/data/services/api_service.dart` — reading list detail/add/remove/delete methods

## Copy these from the fix package / local artifacts

Your AI session saved a full zip and individual files under `artifacts/fixes/`:

| Source file | Destination in repo |
|-------------|---------------------|
| `library_screen.dart` | `lib/ui/screens/library_screen.dart` |
| `discover_screen.dart` | `lib/ui/screens/discover_screen.dart` |
| `edit_chapter_screen.dart` | `lib/ui/screens/edit_chapter_screen.dart` |
| `database.py` | `backend/app/database.py` |
| `main.py` | `backend/app/main.py` |
| `api_service.dart` | already updated on GitHub |
| `app_bootstrap.dart` | already updated on GitHub |

Or unzip `novel_app_fixes.zip` and copy into place.

## After copy

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Flutter: hot restart (full restart)
flutter run
```

## What you get

1. **Private reading lists** — tap list → detail → add/remove stories, delete list
2. **Discover tabs** — New / Popular / Fantasy (seeded on backend start)
3. **Richer story seed + cover image fallbacks** from existing uploads
4. **Chapter save** fixed for SQLite
5. **Reading history** via Mark as Completed on Current Reads
