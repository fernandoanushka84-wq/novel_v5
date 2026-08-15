# Novel Mobile App

Inkitt-style Flutter reader and writer app with a FastAPI backend, MySQL storage, image uploads, and a React admin panel.

## What is included

- Flutter mobile app in `lib/`
- FastAPI backend in `backend/app/`
- React admin panel in `admin-panel/`
- Seed cover images in `story_card_images/`

## Backend startup behavior

When the backend starts, it now does this automatically:

- creates missing tables
- runs lightweight migrations
- seeds extra discover and explore categories
- copies images from `story_card_images/` into the served upload folder
- creates a content version key so Flutter and the admin panel can refresh when content changes

Because of that, you do not need to re-run SQL manually for normal local development if your database is reachable.

## Backend setup

1. Start MySQL.
2. Create your backend env file.

```powershell
cd c:\lakmal_code\novel_mobile_app\backend
Copy-Item .env.example .env
```

3. Replace these values in `.env` with your real production values later:

- `MYSQL_HOST`
- `MYSQL_PORT`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_DATABASE`
- `JWT_SECRET`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `UPLOAD_DIR`
- `GOOGLE_CLIENT_ID` if you want backend-verified Google sign-in

4. Install and run the backend.

```powershell
cd c:\lakmal_code\novel_mobile_app\backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

> Note: The backend can run on Python 3.11, 3.12, or 3.13 with `pydantic==2.13.4`.

Default admin login:

- username: `admin_Supun`
- password: `Ux3@f=7x2`

## Flutter app setup

```powershell
cd c:\lakmal_code\novel_mobile_app\novel_mobile_app
flutter pub get
flutter run
```

If you are using a physical phone or a different backend host:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Android emulator local backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Admin panel setup

1. Configure the admin panel API URL.

```powershell
cd c:\lakmal_code\novel_mobile_app\novel_mobile_app\admin-panel
Copy-Item .env.example .env
```

2. Set `VITE_API_BASE_URL` to your backend URL.

3. Install and run the panel.

```powershell
cd c:\lakmal_code\novel_mobile_app\novel_mobile_app\admin-panel
npm install
npm run dev
```

The admin panel can now manage:

- stories
- story covers
- categories
- notifications
- menu items
- write-screen content
- profile stats
- reading lists
- achievements
- support request status

## Deploy admin panel to Vercel

1. Push the repository to GitHub.
2. In Vercel, import the repository.
3. Set the root directory to `admin-panel`.
4. Add environment variable `VITE_API_BASE_URL` with your deployed backend URL.
5. Leave the build command as `npm run build`.
6. Leave the output directory as `dist`.
7. Deploy.

The existing `admin-panel/vercel.json` is already compatible with this setup.

## Deploy backend

Your backend host must support:

- Python FastAPI
- persistent file storage or object storage for uploads
- MySQL access

Minimum backend env values to set in production:

- `MYSQL_HOST`
- `MYSQL_PORT`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `MYSQL_DATABASE`
- `MYSQL_SSL_DISABLED`
- `JWT_SECRET`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `UPLOAD_DIR`

For backend-verified Google login, also set:

- `GOOGLE_CLIENT_ID`

The Flutter app now sends the Google token to the backend, and the backend verifies it with Google before creating or updating the app user record.

## Real-time content updates

The admin panel and Flutter app both poll the backend content-version endpoint. After an admin change:

- backend bumps the content version
- admin panel refreshes its data
- Flutter app refreshes its bootstrap data

That gives near-real-time updates without restarting the mobile app.

## Android release build issue

If you see this Gradle error:

`Unable to delete directory ... merged_native_libs ...`

it is usually a Windows file lock. Close Android Studio, Explorer windows opened inside `build/`, and any running emulator using that APK, then run:

```powershell
cd c:\lakmal_code\novel_mobile_app\novel_mobile_app
flutter clean
Remove-Item -Recurse -Force .\build\app\intermediates\merged_native_libs -ErrorAction SilentlyContinue
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_BACKEND_URL
```

If it still fails, restart Windows once to release the lock and rebuild.
