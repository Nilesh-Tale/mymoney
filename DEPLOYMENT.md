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
4. Open **Project Settings → Database → Connection string → URI**. You'll see a
   URL like:

   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.abcdefgh.supabase.co:5432/postgres
   ```

5. Convert it to the driver form this backend uses by changing the scheme from
   `postgresql://` to `postgresql+psycopg://`, and replace `[YOUR-PASSWORD]`
   with your actual password:

   ```
   postgresql+psycopg://postgres:YOUR-PASSWORD@db.abcdefgh.supabase.co:5432/postgres
   ```

   Keep this final string handy — it's your `DATABASE_URL`.

   > Tip: if your password contains special characters like `@`, `:`, or `/`,
   > URL-encode them (e.g. `@` → `%40`).

---

## Step 2 — Deploy the backend on Render

1. Push this project to GitHub (see Step 4 if you haven't created the repo yet).
2. Go to https://render.com → **New → Blueprint**.
3. Connect your GitHub repo. Render detects `render.yaml` at the repo root and
   proposes a **mymoney-backend** web service.
4. When prompted for environment variables, set:
   - `DATABASE_URL` → the `postgresql+psycopg://...` string from Step 1.
   - `CORS_ALLOW_ORIGINS` → your GitHub Pages origin, which is just the host
     **without** the repo path:

     ```
     https://YOUR-USERNAME.github.io
     ```

5. Click **Apply** / **Create**. Render builds the Docker image and deploys.
6. When it's live, note the service URL, e.g.:

   ```
   https://mymoney-backend.onrender.com
   ```

7. Verify it works by visiting `https://mymoney-backend.onrender.com/api/health`
   — you should see `{"status":"healthy",...}`. On first request the free
   instance may take ~30–60s to wake from sleep.

The database tables, the default user, and the default categories are created
automatically on first startup.

> **Free-tier note:** Render's free web service sleeps after inactivity and
> wakes on the next request (one slow load, then fast). Supabase stays free.

---

## Step 3 — Point the web app at the backend (GitHub repo variable)

1. In your GitHub repo: **Settings → Secrets and variables → Actions →
   Variables** tab → **New repository variable**.
2. Name: `API_BASE_URL`
   Value: your Render URL **without a trailing slash**, e.g.
   `https://mymoney-backend.onrender.com`

This value is baked into the web build so the UI knows where the API lives.

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
4. When the Action finishes, your site is live at:

   ```
   https://YOUR-USERNAME.github.io/YOUR-REPO/
   ```

Open that URL on your laptop and your phone — both talk to the same Render
backend, so you'll see the same data everywhere.

---

## Updating `CORS_ALLOW_ORIGINS` later

If you change your Pages URL or add a custom domain, update
`CORS_ALLOW_ORIGINS` on Render (comma-separate multiple origins):

```
https://YOUR-USERNAME.github.io,https://app.example.com
```

Use the scheme + host only — **no path, no trailing slash**.

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

## Troubleshooting

- **UI loads but every page shows a connection error.**
  `API_BASE_URL` repo variable is missing/wrong, or the backend is asleep.
  Check `https://<backend>/api/health` loads, and that the variable is set, then
  re-run the Pages workflow.

- **Browser console shows a CORS error.**
  `CORS_ALLOW_ORIGINS` on Render must exactly match your Pages origin
  (`https://YOUR-USERNAME.github.io`, no path). Update it and redeploy.

- **Page is blank / assets 404 on GitHub Pages.**
  The `base href` must match the repo name. The workflow sets this
  automatically; make sure you're visiting the `/YOUR-REPO/` URL.

- **Backend fails to start on Render.**
  Check the `DATABASE_URL` uses the `postgresql+psycopg://` scheme and the
  password is correct and URL-encoded if it has special characters.
