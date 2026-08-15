# Free hosting (no credit card)

Your Flutter app already falls back to:

`https://lakmasachith-novel-app-backend.hf.space`

That is **Hugging Face Spaces** — free, no payment required for a public Space.

## Recommended stack (free)

| Piece | Choice | Why |
|-------|--------|-----|
| Backend | Hugging Face Spaces (Docker) | Free, no CC for public apps |
| Database | **SQLite** file on the Space | No separate DB server, works with your code |
| Images | `backend/uploads` baked into image or Space storage | Simple |
| Local | Same code + `DB_TYPE=sqlite` | Identical API |

Avoid for "no card" requirement:
- Railway / Render / Fly.io / most cloud MySQL (often ask for card even on free tier)

Optional free DB later: **Turso** (SQLite cloud) or **Supabase** free Postgres (account email only; some regions need no card).

---

## 1) Local (your PC)

`backend/.env` (or `.env.local`):

```env
DB_TYPE=sqlite
SQLITE_FILE=./novel_app.db
UPLOAD_DIR=./uploads
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=Ux3@f=7x2
JWT_SECRET=dev-secret-change-me
```

Run:

```bat
cd backend
.venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Flutter (phone on same Wi‑Fi):

```bat
flutter run --dart-define=API_BASE_URL=http://192.168.1.4:8000
```

(Use your PC LAN IP.)

---

## 2) Live free — Hugging Face Spaces

### A. Create / open Space
1. Go to https://huggingface.co/spaces
2. New Space → SDK **Docker** → Public
3. Name e.g. `novel-app-backend`
4. Connect the Space to GitHub repo `tiklaka00-hub/novel_mobile_app` **or** push only the `backend/` folder as the Space root

### B. Space root must be the backend folder
HF builds from the Space root. Either:
- Set Space to use subdirectory `backend`, **or**
- Put `Dockerfile`, `requirements.txt`, `app/`, `sql/`, `uploads/` at Space root

Your repo already has `backend/Dockerfile` that exposes **7860** (HF default).

### C. Space variables (Settings → Variables)

```
DB_TYPE=sqlite
SQLITE_FILE=/data/novel_app.db
UPLOAD_DIR=/data/uploads
JWT_SECRET=<long-random-string>
ADMIN_USERNAME=admin_Supun
ADMIN_PASSWORD=<your-password>
```

Optional persistent disk on HF: mount `/data` if available on your plan so SQLite survives rebuilds.

### D. After deploy
Open: `https://<your-space>.hf.space/`
Should return: `{"message":"Novel Mobile backend is running."}`

Bootstrap: `https://<your-space>.hf.space/api/bootstrap`

### E. Flutter production URL
In `lib/data/services/api_service.dart` the production base is already:

```dart
static const String _productionApiBaseUrl =
    'https://lakmasachith-novel-app-backend.hf.space';
```

Update that string if your Space name differs. Release builds use it automatically when `API_BASE_URL` is not passed.

Debug with live backend:

```bat
flutter run --dart-define=API_BASE_URL=https://lakmasachith-novel-app-backend.hf.space
```

---

## 3) Both databases still supported

Same codebase:

- **Local / HF free:** `DB_TYPE=sqlite`
- **Paid/cloud MySQL later:** `DB_TYPE=mysql` + MYSQL_* vars

No code fork required.

---

## 4) Git: fix diverged branch (your current state)

You are **not** in a merge anymore. Branches diverged (4 local commits vs 1 remote).

**Safe path (keep your local work, then take remote fixes):**

```bat
cd C:\lakmal_code\novel_mobile_app
git status
git fetch origin

REM See what you have locally vs remote
git log --oneline --left-right main...origin/main

REM Rebase your commits on top of origin (preferred)
git pull --rebase origin main
```

If rebase conflicts in `backend/app/database.py` or `main.py`:

```bat
REM Prefer the fixed remote versions for backend
git checkout --theirs backend/app/database.py
git checkout --theirs backend/app/main.py
git add backend/app/database.py backend/app/main.py
git rebase --continue
```

If rebase is too messy and you want remote to win completely for backend only:

```bat
git fetch origin
git checkout origin/main -- backend/app/main.py backend/app/database.py
git add backend/app/main.py backend/app/database.py
git commit -m "Sync backend main/database from origin"
git pull --rebase origin main
git push origin main
```

**Only if you are OK discarding local commits** (destructive):

```bat
git fetch origin
git reset --hard origin/main
```

Then re-apply any local Flutter fixes you still need from stash:

```bat
git stash list
git stash pop
```

---

## 5) Still need reading-list 404 fix

After git is clean, ensure `backend/app/main.py` contains:

- `GET /api/reading-lists/{list_id}`
- `POST /api/reading-lists/{list_id}/items`
- `DELETE .../items/{item_id}`
- `DELETE /api/reading-lists/{list_id}`

and `database.py` creates table `reading_list_items` on startup.

If remote still lacks those, copy from a fixed package or ask to re-push the full fixed files.

Restart uvicorn after updating files.
