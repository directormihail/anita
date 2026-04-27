# Stripe Financial Connections (bank linking)

Use **either** Option A (local backend) or Option B (Railway). Option A is fastest to validate the flow.

---

## Option A — Local backend

### 1. Run the API on your Mac

```bash
cd "ANITA backend"
npm run dev
```

Leave this terminal running. Expect something like `http://localhost:3001`. If you see Stripe secret errors, ensure `ANITA backend/.env` exists with `STRIPE_SECRET_KEY` from the Stripe Dashboard → API keys. Do not commit `.env`.

### 2. Point the app at your Mac

- **Simulator:** Settings → Backend URL → `http://localhost:3001`
- **Physical device:** Same Wi‑Fi as the Mac; use your Mac’s LAN IP, e.g. `http://192.168.1.100:3001`

### 3. Open the Stripe window in the app

From the welcome flow, use **Test bank connection** (wording may vary by build). The Financial Connections sheet should appear. Alerts usually mean no route / no network — check Backend URL.

### 4. Repeat

Trigger the flow again to confirm new sessions work.

---

## Option B — Railway (deployed backend)

Deploy **ANITA backend** so `POST /api/v1/financial-connections/session` is live. Railway (or your host) needs at least: `STRIPE_SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` where applicable.

In the iOS app: clear **Backend URL** in Settings so the default production URL applies (see your `Config` / deployment).

---

## TestFlight / production

- User must be **signed in** (flows need `userId`).
- Production build must hit a backend that exposes the financial-connections route and valid Stripe + Supabase env vars.

---

## Quick checks

| Symptom | Likely fix |
|--------|------------|
| “Backend route not found” | Old deploy, wrong URL, or backend not running |
| Stripe / `client_secret` errors | Missing or wrong `STRIPE_SECRET_KEY` locally or on Railway |
| Sheet opens | Flow is OK |

---

## Summary

- **Local:** `npm run dev` in `ANITA backend`, Backend URL → `localhost` or Mac IP, test from the app.
- **Railway:** Deploy latest backend, clear custom Backend URL, test again.
