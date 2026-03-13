# Stripe Financial Connections & PostHog

## How to see the Stripe connection window

The **“Test bank connection”** button opens the Stripe Financial Connections sheet only when the backend returns **200** with a `client_secret`. If you see an alert like **“Not found”**, the app is getting **404** — the backend the app is calling doesn’t have the route yet.

### Option A: Use local backend (fastest way to test)

1. **Run the backend** with Stripe configured:
   ```bash
   cd "ANITA backend"
   # Ensure .env has STRIPE_SECRET_KEY and SUPABASE_* set
   npm run dev
   ```
2. **In the iOS app:** open **Settings** and set **Backend URL** to:
   - **Simulator:** `http://localhost:3001`
   - **Physical device:** `http://YOUR_MAC_IP:3001` (same Wi‑Fi as the Mac).
3. **Tap “Test bank connection”** on the welcome screen. The Stripe Financial Connections window should appear.

### Option B: Deploy backend to Railway

Deploy the current **ANITA backend** (including `POST /api/v1/financial-connections/session`) to Railway. After deploy, the production URL will return 200 and the app will show the Stripe window without changing Settings.

### Summary

- **Stripe iOS SDK** is linked (StripeFinancialConnections).
- **Backend** must respond to `POST /api/v1/financial-connections/session` with `client_secret`.
- **Return URL** is `anita://stripe-redirect` (scheme `anita` in Info.plist).
- **Backend URL** in Settings is used when set; otherwise the app uses the production Railway URL.

---

## PostHog keys – where to set them

If you added or changed keys in the PostHog dashboard, update them here so the app and backend use the same project.

| Place | What to set |
|-------|-------------|
| **iOS app** | `ANITA IOS/ANITA/Utils/Config.swift` — `posthogAPIKey`, `posthogHost`. The app uses these at runtime (or Xcode scheme env vars `POSTHOG_KEY`, `POSTHOG_HOST`). |
| **iOS reference** | `ANITA IOS/.env` — same values for reference; Xcode does not load this file automatically. |
| **Backend (local)** | `ANITA backend/.env` — `POSTHOG_KEY`, `POSTHOG_PROJECT_ID`, `POSTHOG_HOST`. |
| **Backend (Railway)** | Project → Service → Variables: same names and values (see `ANITA backend/RAILWAY_POSTHOG_SETUP.md`). |

**Check:**

- **Config.swift**: `posthogAPIKey` = Project API key (starts with `phc_`), `posthogHost` = `https://us.i.posthog.com`, `posthogProjectID` = `318843` (or your project ID).
- **Backend .env**: `POSTHOG_KEY`, `POSTHOG_HOST`, `POSTHOG_PROJECT_ID` match the same PostHog project.
- Only the **iOS app** sends events to PostHog today; the backend only has the vars for future use.
