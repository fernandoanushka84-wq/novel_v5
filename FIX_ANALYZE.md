# Fix flutter analyze errors

## 1. DELETE this broken local-only file (not on GitHub)

```
del lib\ui\screens\discover_search.dart
```

Or:
```
Remove-Item lib\ui\screens\discover_search.dart
```

`SearchScreen` already lives inside `discover_screen.dart`. The orphan file has no Flutter imports and causes 100+ errors.

## 2. Pull fixed files from GitHub

```
git pull origin main
```

## 3. Re-analyze

```
flutter clean
flutter pub get
flutter analyze
```

## Verbose run (to see runtime errors)

```
flutter run -d A201SH -v --dart-define=API_BASE_URL=http://192.168.1.4:8000 --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID
```

Or:
```
flutter run -d A201SH --verbose --dart-define=API_BASE_URL=http://192.168.1.4:8000 --dart-define=GOOGLE_CLIENT_ID=YOUR_CLIENT_ID
```

## Admin panel

```
cd admin-panel
copy .env.example .env
# Edit VITE_API_BASE_URL=http://192.168.1.4:8000  (or your HF URL)
npm install
npm run dev
```

Open the URL Vite prints (usually http://localhost:5173).

Login: values from backend `.env` (`ADMIN_USERNAME` / `ADMIN_PASSWORD`). Check `backend/.env` or server env.

## Author name on write

Create Story now auto-fills author from logged-in `display_name` and locks the field.

## Hashtags

Type in the text box; only admin-created tags from the database are suggested. Users cannot invent tags.
