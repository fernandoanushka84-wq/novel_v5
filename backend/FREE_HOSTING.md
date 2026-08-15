# Free hosting (no credit card / no payment) — 2026

## Does this app use SQLite or MySQL?

**Both.** The same code works with either:

| Mode | When | Config |
|------|------|--------|
| **SQLite** | Local + free cloud | `DB_TYPE=sqlite` |
| **MySQL** | Local MySQL or paid cloud DB | `DB_TYPE=mysql` + MYSQL_* vars |

Startup creates tables, seeds stories, and runs migrations for both.
You only change env vars — no code switch.

---

## Hugging Face Spaces (what changed)

As of 2026, **creating Gradio/Docker Spaces needs a paid plan** (PRO ~$9/mo).
Static Spaces stay free, but our FastAPI backend needs Docker → **not free anymore**.
If you already have an old Space running, it may keep working until you rebuild.

---

## Best free stack for this project (no card)

| Part | Free option | Notes |
|------|-------------|--------|
| Backend | **Render** free Web Service | No credit card. Sleeps after ~15 min idle; wakes in ~30–60s |
| Database | **SQLite** on the same service | Set `DB_TYPE=sqlite` — no second account |
| Optional DB | **Neon** free Postgres | Only if you later add Postgres; not required now |
| Flutter | APK / debug with `API_BASE_URL` | Point at your Render URL |

Other no-card options: **Koyeb** (limited free), **PythonAnywhere** (not ideal for FastAPI/ASGI).

**Avoid if you refuse any card:** Railway / Fly.io (card or trial-only).

---

## Local (SQLite) — keep using this daily

`backend/.env` or `.env.local`:

```env
DB_TYPE=sqlite
SQLITE_FILE=./novel_app.db
UPLOAD_DIR=./uploads
JWT_SECRET=change-me-locally
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=Ux3@f=7x2
```

```bat
cd backend
.venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Flutter:

```bat
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

---

## Live free: Render + SQLite (recommended)

### 1. Create account
https://render.com — sign up with GitHub. **No credit card** for free tier.

### 2. New Web Service
- Connect repo: `tiklaka00-hub/novel_mobile_app`
- Root directory: `backend`
- Runtime: **Docker** (uses `backend/Dockerfile`)  
  **or** Python: Build `pip install -r requirements.txt`  
  Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

If using **Python** (not Docker), set start command:

```
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

### 3. Environment variables (Render → Environment)

```
DB_TYPE=sqlite
SQLITE_FILE=./novel_app.db
UPLOAD_DIR=./uploads
JWT_SECRET=<long-random-string>
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=<strong-password>
```

### 4. Important free-tier limits
- Service **sleeps after ~15 minutes** with no traffic.
- First request after sleep can take **30–60 seconds** (cold start).
- Disk is **ephemeral**: SQLite + uploads can reset on redeploy.
  For demos this is OK. For lasting data later: Turso / Neon free, or paid disk.

### 5. After deploy
API URL looks like:

```
https://novel-mobile-app-xxxx.onrender.com
```

Test: open that URL in a browser → should return backend health JSON.

### 6. Flutter → live API

Debug:

```bat
flutter run --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Release: update production fallback in `lib/data/services/api_service.dart`:

```dart
static const String _productionApiBaseUrl =
    'https://YOUR-SERVICE.onrender.com';
```

---

## Optional: free Postgres later (not required)

If you outgrow SQLite on free hosts:

1. Create free DB at [Neon](https://neon.tech) (no card for free tier).
2. This project currently has **MySQL** drivers, not Postgres.
   To use Neon you’d need a small adapter or stick with **MySQL** on a free/cheap host.
3. Simplest path: stay on **SQLite** for free hosting.

---

## Same code, local + live

| Setting | Local | Render free |
|---------|-------|-------------|
| `DB_TYPE` | `sqlite` | `sqlite` |
| App code | same | same |
| Port | 8000 | `$PORT` / 7860 in Docker |
| Data file | `./novel_app.db` | `./novel_app.db` (ephemeral on free) |

Reading lists, bootstrap, seeds, and uploads all work on both.

---

## Git status check

If your PC is clean:

```bat
git status
git pull origin main
```

You should see: **up to date with origin/main**, working tree clean.
