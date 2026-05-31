# Inventory Tracker — Setup Guide

This turns your inventory tracker into a cloud-synced app: log in from any device (phone, laptop, tablet) and see the same live inventory everywhere.

You'll use two free services:

- **Supabase** — stores your data and handles login
- **GitHub Pages** — hosts the app at a web address you can open anywhere

The whole thing takes about 15 minutes and costs nothing for personal use. No coding required — just copying and pasting.

---

## Part 1 — Set up Supabase (the database)

**1. Create an account and project**

- Go to [supabase.com](https://supabase.com) and sign up (free).
- Click **New project**. Give it a name like `inventory`, set a database password (save it somewhere), pick a region near you, and create it.
- Wait a minute or two for it to finish setting up.

**2. Create the database tables**

- In the left sidebar, click **SQL Editor**, then **New query**.
- Open the included `schema.sql` file, copy everything in it, and paste it into the editor.
- Click **Run**. You should see a success message. This creates your `products` and `history` tables, locks them down so only you can see your data, and turns on live sync.

**3. Get your two keys**

- In the left sidebar, go to **Settings** (gear icon) → **API**.
- You need two values:
  - **Project URL** — looks like `https://abcdxyz.supabase.co`
  - **anon public** key (also labeled "publishable") — a long string of characters
- Keep this tab open; you'll paste these in Part 2.

> The "anon public" key is safe to put in a public web page — it only works alongside the security rules from `schema.sql`, which restrict every account to its own data. Never use the **service_role** key here; that one is secret.

---

## Part 2 — Get your Supabase keys ready

You'll paste your project's URL and anon key into the app the first time you open it (via a one-time setup screen). Have these two values handy from your Supabase dashboard:

- **Project URL** — `Settings → API`, looks like `https://abcdxyz.supabase.co`
- **anon public key** — same screen, a long string starting with `eyJ...`

No text-editor surgery needed. The keys are stored in your browser the first time you enter them, and persist across every future app update.

---

## Part 3 — Put it online with GitHub Pages

This gives the app a web address so your other devices can reach it.

**1. Create a GitHub account** at [github.com](https://github.com) if you don't have one (free).

**2. Create a repository**

- Click the **+** in the top right → **New repository**.
- Name it something like `inventory` and set it to **Public** (Pages is free for public repos).
- Click **Create repository**.

**3. Rename the app file — this step is critical**

Before uploading anything, rename `inventory-tracker.html` on your computer to exactly **`index.html`** (lowercase, no extra extension like `.html.html`).

GitHub Pages serves the page at your bare URL (`yourname.github.io/inventory/`) **only** if a file named `index.html` exists. If you skip this rename, the URL will return a "404 — File not found" error on every device.

**4. Upload the files**

- On the new repo page, click **uploading an existing file**.
- Drag in **all five** of these files together:
  - `index.html` (the renamed app — double-check it's not still called `inventory-tracker.html`)
  - `manifest.json`
  - `sw.js`
  - `icon-192.png`
  - `icon-512.png`
- Keep them all at the top level of the repo — don't put them in a folder.
- Click **Commit changes**.
- On your repo's main page, confirm you can see `index.html` listed (not `inventory-tracker.html`).

**5. Turn on GitHub Pages**

- In the repo, go to **Settings** → **Pages** (left sidebar).
- Under **Branch**, pick `main` and the `/ (root)` folder, then **Save**.
- Wait 1–2 minutes. The page will then show your live address, something like:
  `https://yourname.github.io/inventory/`

**6. Verify it actually works — do this before moving on**

- Open the live URL in your browser. You should see either the inventory app's login screen or the "Almost there" setup screen (if you forgot Part 2). Both are fine — they mean the deployment is working.
- If you instead get a **404 page**, the two usual causes are: (a) your file isn't named exactly `index.html` — go back to step 3 and rename it in the repo; or (b) you're typing the URL with the wrong capitalization. GitHub Pages is **case-sensitive**: `yourname.github.io/Inventory/` and `yourname.github.io/inventory/` are different URLs. Copy the URL straight from the Settings → Pages screen and use it exactly.
- Try the same URL on a second device (phone, another computer) to make sure it loads everywhere. If it loads on one device but 404s on another, check the capitalization first, then try the failing device in a private/incognito window to rule out cache.

Bookmark the URL on every device once it loads cleanly.

---

## Part 4 — First login

- Open your GitHub Pages URL.
- The very first time on each device, you'll see a **Welcome** screen asking for your Supabase URL and anon key. Paste them in and click **Save & continue**. (You can later reconfigure them from the link on the sign-in screen.)
- Click **Create an account**, enter an email and password.
- Supabase sends a confirmation email by default — click the link in it, then come back and sign in.
- Add a product on one device, then open the URL on another device, sign in with the same account, and confirm the inventory and sales appear there too.

> **Want to skip the confirmation email?** In Supabase, go to **Authentication → Sign In / Providers → Email** and turn off "Confirm email". Fine for a personal-use app.

---

## Part 5 — Install it as an app (one-tap launch)

Once it's hosted, you can install the app so it lives as an icon on your home screen or desktop — tap it and it opens fullscreen, with no browser bar, just like a normal app. It also launches instantly and shows your last-synced data even with no connection.

**On Android / Chrome / Edge (phone or computer)**

- Open your GitHub Pages URL and sign in.
- An **⬇ Install app** button appears in the top toolbar — tap it and confirm.
- (Your browser may also show its own install icon in the address bar.)

**On iPhone / iPad (Safari)**

- Safari doesn't show an in-app button, so install it manually: open the URL, tap the **Share** button, then **Add to Home Screen**, then **Add**.

That's it — the crate icon is now on your home screen or desktop. Open it once a day with a single tap; you stay signed in between visits, so there's no logging in each time.

---

## Part 6 — Keep the project awake (so it's always fast)

A free Supabase project pauses itself after 7 days with no database activity. Your data is never lost — a paused project just needs a one-click restore and takes about 30 seconds to wake up — but for daily use it's nicer to avoid the pause entirely. This step adds a small automated task that pings the database once a day.

**1. The heartbeat table is already set up.** The `keep_alive` table was created when you ran `schema.sql` in Part 1. (If you ran an earlier version of that file, just re-run the whole `schema.sql` now — it's safe to run again and won't touch your products.)

**2. Add the workflow file to your repo**

- In your GitHub repo, click **Add file** → **Create new file**.
- In the filename box, type exactly: `.github/workflows/keep-alive.yml`
  (typing the slashes automatically creates the folders).
- Open the included `keep-alive.yml` file, copy everything in it, and paste it in.
- Click **Commit changes**.

**3. Give the workflow your Supabase keys**

The `keep-alive.yml` file in your repo is public — anyone visiting your repo can read it. So you can't paste your Supabase URL and key directly into it. Instead, GitHub stores those values privately as **repository secrets**, and the workflow looks them up by name when it runs (you'll see `${{ secrets.SUPABASE_URL }}` and `${{ secrets.SUPABASE_KEY }}` inside the yml — those are placeholders).

You need to add **two** secrets, one at a time:

- Open your repo on GitHub. Click **Settings** at the top of the repo.
- In the left sidebar, find **Secrets and variables** and click it. A small menu opens underneath — click **Actions**.
- Click the green **New repository secret** button.
  - In the **Name** field, type exactly: `SUPABASE_URL` (uppercase, with an underscore).
  - In the **Value** field, paste your Supabase project URL (the same `https://abcdxyz.supabase.co` from Part 2).
  - Click **Add secret**.
- You'll be back on the secrets page. Click **New repository secret** again to add the second one.
  - In the **Name** field, type exactly: `SUPABASE_KEY`.
  - In the **Value** field, paste your anon public key (the long string from Part 2).
  - Click **Add secret**.

When you're done, the secrets page will list both names. The values themselves are hidden — that's expected and means it worked.

**4. Test it**

- Go to the **Actions** tab in your repo, click **Keep Supabase Awake**, then **Run workflow**.
- After a few seconds it should show a green check. You can also open the `keep_alive` table in Supabase and watch the `last_ping` time update.

From now on it runs by itself every day. The pause timer never reaches zero, so the app is always instant.

> **One caveat:** GitHub automatically disables scheduled workflows in a repo that gets **no commits for 60 days**. If you go that long without updating the app, the daily ping stops. Easy fixes: it re-enables the moment you commit anything, or you can just open the **Actions** tab and click **Run workflow** by hand. And even in the worst case, a paused project is one click to restore — no data is lost.

---

## Updating the app later

If you ever want to change the app, edit the file and upload the new `index.html` (and `sw.js` if it changed) to the repo. Pages refreshes within a minute and the installed app updates itself next time you open it. Your data and your stored Supabase keys are untouched — they live in Supabase and your browser, not in the file. **No more re-pasting keys after each update.**

**When an update changes the database** (for example, the POS upgrade added new tables and a `record_sale` function), re-run the latest `schema.sql` in the Supabase SQL Editor first, then upload the new HTML. The schema file is safe to re-run — it only adds anything new and won't touch existing data.

## Backups

Your data is safely stored in Supabase, but the **Export CSV** button is still there for your own backup copies. Export occasionally and keep the file somewhere safe. **Import CSV** brings those rows back in if you ever need to restore.

## Cost

Supabase's free tier and GitHub Pages are both free and far more than enough for a personal inventory tracker. Supabase pauses a free project after about a week of zero activity — if that happens, just log into the Supabase dashboard once to wake it up.

---

## Quick troubleshooting

- **404 / "File not found" on the live URL** — the file in your repo isn't named `index.html`. On GitHub, open the repo, click the file (probably called `inventory-tracker.html`), click the pencil icon to edit, and change the name in the filename box to `index.html`. Commit, wait a minute, and reload.
- **Works on one device but 404s on another** — almost always browser cache on the device that "works". Try opening the URL in a private/incognito window on the working device — if it 404s there too, fix the rename above. If it still works in incognito, check that you're typing the exact same URL on both devices (capitalization matters: `Inventory` and `inventory` are different to GitHub).
- **"Almost there" setup screen won't go away** — your `SUPABASE_URL` or `SUPABASE_KEY` is blank or has a typo. Recheck Part 2.
- **Can't sign in / "Invalid login credentials"** — confirm your email first (Part 4), or double-check the password.
- **Data doesn't load** — make sure you ran `schema.sql` successfully (Part 1, step 2).
- **Changes don't sync live between devices** — the `schema.sql` file already enables this; re-run it if you skipped that step. A page refresh always pulls the latest either way.
