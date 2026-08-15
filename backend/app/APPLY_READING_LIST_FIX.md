# Backend fix: reading lists + explore counts

## Problems fixed
1. `GET /api/reading-lists/{id}` and `POST /api/reading-lists/{id}/items` returned **404** because routes were missing on main.
2. Explore / See all showed **wrong topic numbers** (stale seed values).
3. Need **SQLite and MySQL** both working via `DB_TYPE`.

## What to do on your PC

### Resolve merge conflict
```bat
cd C:\lakmal_code\novel_mobile_app
git status
```
If `backend/app/database.py` has conflict markers (`<<<<<<<`), accept the incoming fixed version:
```bat
git checkout --theirs backend/app/database.py
git add backend/app/database.py backend/app/main.py
git commit -m "Resolve merge: use fixed database and main"
```
Or pull again after this push lands:
```bat
git pull origin main
```

### Copy fixed files if pull still conflicts
Use the files from this repo after pull, or from artifacts if provided:
- `backend/app/main.py`
- `backend/app/database.py`

### .env (both databases supported)
```
DB_TYPE=sqlite
SQLITE_FILE=./novel_app.db
```
or for MySQL:
```
DB_TYPE=mysql
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=yourpassword
MYSQL_DATABASE=novel_app_db
MYSQL_SSL_DISABLED=true
```

### Restart backend
```bat
cd backend
.venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
On startup, migrations create `reading_list_items` and seed New/Popular/Fantasy tabs + stories.

### Verify
```
curl http://127.0.0.1:8000/api/bootstrap
```
Check `explore_topics` numbers match real books. After login, open a reading list — add/remove should return 200.
