# Updates (2026-08-13)

## 1. Read-only without login
- Discover works with **no account**.
- Library / Write / Notifications / More require sign-in.
- Login screen: "Browse stories only (read-only, no account)" + Guest + Google + Email.

## 2. Google Sign-In
- Clearer backend errors for audience mismatch / missing tokens.
- If `GOOGLE_CLIENT_IDS` is empty, tokens are accepted (dev mode) with a warning log.
- Production: set `GOOGLE_CLIENT_ID` or comma-separated `GOOGLE_CLIENT_IDS` in `backend/.env`.

## 3. Library Current Reads + History
- Bootstrap no longer dumps all users' library entries.
- Personal library loads via authenticated `GET /api/library`.
- Flutter already splits Current (not completed) vs History (completed).

## 4. Discover slider
- Selected book **scales up** (~1.12); others shrink + fade + **blur**.

## 5. Admin panel
- Dark blue theme with orange/green accents.
- Login reads credentials from backend `.env` (`ADMIN_USERNAME` / `ADMIN_PASSWORD`).
- Existing CRUD for books, categories, notifications, menus, reading lists, achievements, support remains.

## Admin login
```
ADMIN_USERNAME=admin_Supun   # from backend/.env
ADMIN_PASSWORD=<your value>  # from backend/.env
```
Admin panel `.env`: `VITE_API_BASE_URL=<your backend URL>`
