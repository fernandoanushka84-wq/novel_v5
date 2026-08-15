# Admin panel — plan + install (Users / Authors moderation)

## Diagnosis (what was wrong)

| Area | Status |
|------|--------|
| Backend API | **OK** — ban/unban/suspend/unsuspend/delete/restore/author-active all write to `app_users` |
| DB columns | **OK** — `is_banned`, `is_suspended`, `is_deleted`, `suspended_until`, `is_author_active` |
| Flutter login block | **OK** — `_assert_user_can_login` blocks banned/suspended/deleted |
| Admin UI on GitHub | **Broken** — old pages with no Ban↔Unban toggle |
| Bulk checkboxes | **Missing** until this update |

Root cause: GitHub `admin_App.jsx` still had old Users/Authors pages (no toggle, no API calls).  
`moderation_pages.jsx` on GitHub was a placeholder.

## What this update fixes

### Toggle buttons (single row)
- **Ban** → after success becomes **Unban**, status badge **Banned**, DB `is_banned=1`
- **Unban** → becomes **Ban**, `is_banned=0`
- **Suspend** → becomes **Unsuspend**, `is_suspended=1`
- **Delete** → becomes **Recover account**, `is_deleted=1`
- Authors **Inactive** ↔ **Activate** via `is_author_active`

### Bulk actions (checkboxes)
- Row checkbox + **Select all** in header
- Bulk bar: Ban / Unban / Suspend / Unsuspend / Activate / Delete / Recover selected
- Same API calls as single-row actions (sequential, reliable)

### Pages that need this
- **Users** — full moderation + bulk
- **Authors** — full moderation + author active/inactive + bulk
- **Novels** — already has Publish/Delete (individual)

## Install (required)

Download **admin-panel-moderation-update.zip** from project artifacts.

```powershell
cd C:\lakmal_code\novel_v3\novel_mobile_app

# Extract zip, then copy these files into admin-panel\src\:
copy /Y App.jsx admin-panel\src\App.jsx
copy /Y admin_App.jsx admin-panel\src\admin_App.jsx
copy /Y moderation_pages.jsx admin-panel\src\moderation_pages.jsx
copy /Y styles.css admin-panel\src\styles.css

cd admin-panel
npm run dev
```

Hard-refresh browser: **Ctrl+Shift+R**

Confirm `.env` has:
```
VITE_API_BASE_URL=http://YOUR_PC_IP:8000
```

## How it connects to DB

1. Admin panel calls `GET /api/admin/users` → list with flags
2. Ban → `POST /api/admin/users/{id}/ban` → `UPDATE app_users SET is_banned=1`
3. UI reloads list → button flips to **Unban**
4. Flutter login blocked if banned/suspended/deleted

## Test checklist

1. **Users** → Ban test user → button **Unban**, badge **Banned**
2. Unban → button **Ban** again
3. Suspend → Unsuspend
4. Delete → **Recover account**
5. Checkboxes → select 2 users → **Ban selected**
6. Flutter login as banned user → blocked
7. **Authors** → same toggles + Inactive/Activate

## Backend routes (already live)

```
GET    /api/admin/users
POST   /api/admin/users/{id}/ban | unban | suspend | unsuspend | activate | restore | author-active
DELETE /api/admin/users/{id}
```
