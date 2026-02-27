# Cabrera Harvest — Deployment & Setup

## Part 1: Supabase (login + cloud saves)

### 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → **New project**
2. Pick a name (e.g. `cabrera-harvest`), set a strong DB password, choose a region close to you.
3. Wait ~2 minutes for the project to spin up.

### 2. Run the database SQL

1. In your project: **SQL Editor → New query**
2. Paste the contents of `supabase_setup.sql` and click **Run**.
3. You should see the `save_slots` table in **Table Editor**.

### 3. (Recommended) Disable email confirmation

For a family game you don't want to confirm email every signup:

1. **Authentication → Providers → Email**
2. Toggle **"Confirm email"** OFF.
3. Save.

### 4. Get your API credentials

1. **Project Settings → API**
2. Copy:
   - **Project URL** — looks like `https://abcdefgh.supabase.co`
   - **anon / public** key — long JWT string

### 5. Add them to the game

Open `autoload/supabase.gd` and replace the two constants at the top:

```gdscript
const SUPABASE_URL      = "https://YOUR_PROJECT_REF.supabase.co"
const SUPABASE_ANON_KEY = "YOUR_ANON_KEY"
```

---

## Part 2: Web export (iOS + Desktop browser)

### 1. Export from Godot

1. Open the project in Godot 4.
2. **Project → Export → Add → Web**
3. Set **Export Path** to `deploy/web_export/index.html`
4. Click **Export Project**.

> If Godot says "Export templates not installed": **Editor → Manage Export Templates → Download**.

### 2. Build the Docker image

```bash
cd deploy/
docker build -t cabrera-harvest:latest .
```

### 3. Deploy on Dokploy

1. In Dokploy, create a new **Docker** service.
2. Point it at this repo or upload the image.
3. Port mapping: **container 80 → host port** (e.g. 3080).
4. Add your Cloudflare Tunnel route to that port.
5. Deploy.

### 4. Play on iPhone / iPad

1. Open the game URL in **Safari** (not Chrome — iOS Chrome doesn't support PWA add-to-home).
2. Tap the **Share** button → **"Add to Home Screen"**.
3. The game opens fullscreen like a native app.

---

## How it works

| Action | What happens |
|---|---|
| First time | Parent creates an account on the login screen |
| Sign in | JWT session cached locally — stays logged in across app restarts |
| Start screen | Downloads all 3 save slots from Supabase, updates local cache |
| Save (sleep, pause → exit) | Writes local file instantly, pushes to Supabase in background |
| Offline | Local cache is used; cloud push is skipped silently; syncs next session |
| New device | Sign in → cloud slots download automatically |
| Sign out | JWT deleted locally; next person logs in with their own account |

## Notes

- **One family account, 3 player slots.** Slot 1 = kid 1, Slot 2 = kid 2, Slot 3 = kid 3.
- **Migrating old local saves**: if you played before adding Supabase, local saves show up automatically. The first time you sleep/save in-game, that slot gets pushed to the cloud.
- The nginx `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers are **required** by Godot 4 web exports — don't remove them.
