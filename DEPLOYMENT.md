# Deploying MyMoney for free (shared data across all devices)

This guide hosts the full app on free services so the **same data is visible on
every device**:

| Layer | Service | Cost |
|-------|---------|------|
| PostgreSQL database | **Supabase** | Free |
| FastAPI backend | **Render** | Free |
| Flutter web UI | **GitHub Pages** | Free |

Every device loads the UI from GitHub Pages and talks to one shared backend on
Render, which stores data in one shared Supabase database. No per-device silos.

> Why three services? GitHub Pages can only serve static files — it cannot run
> Python or a database. So the UI goes on Pages, while the backend and database
> run on hosts that can execute server code.

## Live deployment

The public web app URL follows the GitHub Pages pattern for your repo:

```
https://<your-github-username>.github.io/<repo>/
```

The backend runs on Render and the database on Supabase. Keep the concrete URLs,
Supabase project ref, and region in your own private notes (or the Render/GitHub
dashboards) rather than in this committed file — a public repo shouldn't
advertise the exact infrastructure to target.

The steps below document how it was set up so you can reproduce or maintain it.

---

## Prerequisites

- A GitHub account (and this project pushed to a GitHub repository).
- A Supabase account (sign up with GitHub).
- A Render account (sign up with GitHub).

---

## Step 1 — Create the database on Supabase

1. Go to https://supabase.com and create a new project.
2. Pick a strong database password and **save it** — you'll need it in Step 2.
3. Wait for the project to finish provisioning.
4. Click the green **Connect** button at the top of the dashboard.
5. In the dialog choose the **ORM** tab. It shows two connection strings:

   ```
   # Transaction pooler (port 6543) — has ?pgbouncer=true. DO NOT use this one.
   DATABASE_URL="postgresql://postgres.<ref>:[YOUR-PASSWORD]@aws-1-<region>.pooler.supabase.com:6543/postgres?pgbouncer=true"

   # Session pooler (port 5432) — use THIS one.
   DIRECT_URL="postgresql://postgres.<ref>:[YOUR-PASSWORD]@aws-1-<region>.pooler.supabase.com:5432/postgres"
   ```

   Use the **session pooler** string (port **5432**, the `DIRECT_URL`). Avoid
   the transaction pooler (`6543` / `?pgbouncer=true`) — its pgbouncer mode
   disables prepared statements and breaks SQLAlchemy.

6. Convert it to the driver form this backend uses by changing the scheme from
   `postgresql://` to `postgresql+psycopg://`, and fill in your real password.
   With your project ref and region filled in, the final
   `DATABASE_URL` looks like:

   ```
   postgresql+psycopg://postgres.<your-project-ref>:YOUR-PASSWORD@aws-1-<region>.pooler.supabase.com:5432/postgres
   ```

   Keep this final string handy — it's your `DATABASE_URL` for Render.

   > - Keep the dotted username exactly as shown
   >   (`postgres.<your-project-ref>`) — the pooler requires it.
   > - If your password contains special characters like `@`, `:`, `/`, `#`,
   >   `?`, `&`, URL-encode them (e.g. `@` → `%40`, `#` → `%23`).
   > - Note: the **Data API / PostgREST** URL
   >   (`https://<ref>.supabase.co/rest/v1/`) is a different thing and is NOT
   >   used here — this backend connects directly with SQLAlchemy.

---

## Step 2 — Deploy the backend on Render

1. Push this project to GitHub (see Step 4 if you haven't created the repo yet).
2. Go to https://render.com → **New → Blueprint**.
3. Connect your GitHub repo. Render detects `render.yaml` at the repo root and
   proposes a **mymoney-backend** web service.
4. When prompted for environment variables, set:
   - `DATABASE_URL` → the `postgresql+psycopg://...` string from Step 1.
   - `CORS_ALLOW_ORIGINS` → your GitHub Pages origin, which is just the host
     **without** the repo path. For this project:

     ```
     https://<your-github-username>.github.io
     ```

   - `APP_PASSWORD` → the single shared password you want to protect the app
     with. Anyone who opens the site must enter this to get in. Choose a strong
     value and keep it out of git.
   - `JWT_SECRET` → leave Render to auto-generate it (the blueprint sets
     `generateValue: true`), or provide your own long random string. This signs
     login tokens.
   - `JWT_TTL_DAYS` → optional; how many days a login stays valid before the
     user must re-enter the password (default `30`).

   > Auth note: if `APP_PASSWORD` is left unset, the app runs with **no**
   > password (any input is accepted) — convenient for local dev, but be sure
   > to set it in production.

5. Click **Apply** / **Create**. Render builds the Docker image and deploys.
6. When it's live, note the service URL. For this project it is:

   ```
   https://<your-backend>.onrender.com
   ```

7. Verify it works by visiting
   `https://<your-backend>.onrender.com/api/health` — you should see
   `{"status":"healthy",...}`. Also check
   `/api/health/db` returns `{"database":"PostgreSQL","status":"connected"}` to
   confirm the Supabase connection. On first request the free instance may take
   ~30–60s to wake from sleep.

The database tables, the default user, and the default categories are created
automatically on first startup.

> **Free-tier note:** Render's free web service sleeps after inactivity and
> wakes on the next request (one slow load, then fast). Supabase stays free.

---

## Step 3 — Point the web app at the backend (GitHub repo variable)

1. In your GitHub repo: **Settings → Secrets and variables → Actions →
   Variables** tab → **New repository variable**.
2. Name: `API_BASE_URL`
   Value: your Render URL **without a trailing slash**. For this project:
   `https://<your-backend>.onrender.com`

This value is baked into the web build so the UI knows where the API lives.
Changing it requires re-running the Pages workflow (push a commit, or use the
**Actions** tab → "Run workflow").

---

## Step 4 — Publish the UI on GitHub Pages

1. Create a GitHub repo and push this project (if you haven't):

   ```bash
   git init
   git add .
   git commit -m "MyMoney: deployable build"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
   git push -u origin main
   ```

2. In the repo: **Settings → Pages → Build and deployment → Source =
   GitHub Actions**.
3. The workflow at `.github/workflows/deploy-pages.yml` runs automatically on
   every push to `main` (you can also trigger it from the **Actions** tab via
   "Run workflow"). It:
   - builds the Flutter web app,
   - sets the correct `base href` from your repo name automatically,
   - injects `API_BASE_URL`,
   - adds an SPA `404.html` fallback and `.nojekyll`,
   - deploys to Pages.
4. When the Action finishes, your site is live. For this project:

   ```
   https://<your-github-username>.github.io/mymoney/
   ```

Open that URL on your laptop and your phone — both talk to the same Render
backend, so you'll see the same data everywhere.

---

## Updating `CORS_ALLOW_ORIGINS` later

If you change your Pages URL or add a custom domain, update
`CORS_ALLOW_ORIGINS` on Render (comma-separate multiple origins):

```
https://<your-github-username>.github.io,https://app.example.com
```

Use the scheme + host only — **no path, no trailing slash**. So
`https://<your-github-username>.github.io` is correct; `https://<your-github-username>.github.io/mymoney/`
is wrong.

---

## Changing the app password

The whole app is gated by one shared password (`APP_PASSWORD`).

- **To change it:** Render dashboard → service → **Environment** → edit
  `APP_PASSWORD` → Save. Render redeploys. Everyone must log in again with the
  new password.
- **Log out everyone immediately:** also change `JWT_SECRET` (or let Render
  regenerate it). That invalidates all existing login tokens on every device.
- Logins last `JWT_TTL_DAYS` days (default 30) before the password is needed
  again. There's also a **Log out** button in the app's top bar.

---

## Login rate limiting (brute-force protection)

Repeated wrong-password attempts from the same IP are blocked:

- After `LOGIN_MAX_FAILURES` (default 5) failed attempts within
  `LOGIN_WINDOW_SECONDS` (default 900 = 15 min), that IP is locked out for
  `LOGIN_LOCKOUT_SECONDS` (default 900) and gets HTTP 429.
- A successful login clears the counter for that IP.
- The limiter is in-memory per backend instance; it resets on restart (fails
  open, never locks out a legitimate user permanently). Adjust the thresholds
  via the env vars on Render.

## Activity monitoring

The app has an **Activity** page (sidebar) showing:

- **Active now** — distinct sessions seen in the last 5 minutes.
- **Successful / failed login** totals, and failed attempts in the last 24h.
- **Login history** — recent attempts with time, device/browser, and IP.

Because the app uses one shared password, this tracks *sessions and devices*,
not named individuals. The real client IP is read from `X-Forwarded-For` (set
by Render/Cloudflare). Login events are stored in the `login_events` table in
your database.

---

## Local development (unchanged)

Nothing about local dev changes. You can still run everything locally:

```bash
docker compose up -d --build
cd frontend && flutter run -d chrome
```

Locally the app defaults to `http://localhost:8000`, and CORS already allows
localhost on any port.

---

## Native Linux desktop app

The same Flutter codebase also builds a native Linux desktop app. The UI,
login, and all features are identical to the web app — only the API endpoint
differs by how you build it.

### Prerequisites (one time)

```bash
flutter config --enable-linux-desktop
# Build tools: CMake, Ninja, Clang, pkg-config, and GTK3 dev headers.
# On Debian/Ubuntu:
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Run / build

Point the app at your hosted backend with `--dart-define` (same mechanism the
web build uses). Replace the URL with your Render backend:

```bash
cd frontend

# Run in dev against the cloud backend:
flutter run -d linux --dart-define=API_BASE_URL=https://<your-backend>.onrender.com

# Or build a release binary:
flutter build linux --release --dart-define=API_BASE_URL=https://<your-backend>.onrender.com
```

The release bundle is written to:

```
frontend/build/linux/x64/release/bundle/
```

Run it with `./frontend/build/linux/x64/release/bundle/mymoney`. The whole
`bundle/` folder is the distributable — copy it as a unit (the `mymoney`
binary needs the adjacent `lib/` and `data/` folders).

### Notes

- If you omit `--dart-define`, the app defaults to `http://localhost:8000`
  (useful when running the backend locally via `docker compose`).
- The desktop app stores its login token on disk via `shared_preferences`
  (under the app's config dir), so you stay logged in between launches.
- `CORS_ALLOW_ORIGINS` does **not** apply to the desktop app — CORS is a
  browser concept. The native app calls the API directly.
- The `frontend/linux/` folder is committed; `frontend/build/` is gitignored.

---

## Troubleshooting

- **UI loads but every page shows a connection error.**
  `API_BASE_URL` repo variable is missing/wrong, or the backend is asleep.
  Check `https://<backend>/api/health` loads, and that the variable is set, then
  re-run the Pages workflow.

- **Browser console shows a CORS error.**
  `CORS_ALLOW_ORIGINS` on Render must exactly match your Pages origin
  (`https://<your-github-username>.github.io`, no path). Update it and wait for Render to
  redeploy.

- **Page is blank / assets 404 on GitHub Pages.**
  The `base href` must match the repo name. The workflow sets this
  automatically; make sure you're visiting the `/mymoney/` URL (with the
  trailing slash).

- **Backend fails to start on Render.**
  Check the `DATABASE_URL` uses the `postgresql+psycopg://` scheme and the
  password is correct and URL-encoded if it has special characters.

- **Login always says "Incorrect password".**
  The entered password must exactly match `APP_PASSWORD` on Render. Update it in
  the dashboard if unsure, and remember changing it logs everyone out.

- **App keeps bouncing back to the login screen.**
  The token is being rejected (expired, or `JWT_SECRET` changed). Just log in
  again. If it happens immediately every time, confirm `JWT_SECRET` is stable
  (not regenerating on each deploy).
