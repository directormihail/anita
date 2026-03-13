# Get the Stripe Bank Connection Window Working

Follow **either** Option A (local) or Option B (Railway). Option A is fastest to test.

---

## Option A: Test with local backend (recommended first)

### 1. Start the backend on your Mac

```bash
cd "ANITA backend"
npm run dev
```

Leave this terminal open. You should see: `Running on http://localhost:3001` and no "Stripe secret key not configured" error. If you see that error, check that `.env` exists in `ANITA backend` and contains your Stripe secret key (from Stripe Dashboard → API keys). Do not commit `.env`.

### 2. Point the app to your Mac

- **Simulator:** In the ANITA app open **Settings** and set **Backend URL** to:  
  `http://localhost:3001`  
  Save (e.g. tap Save or Done).
- **Physical iPhone:** Use your Mac’s IP instead, e.g. `http://192.168.1.100:3001` (same Wi‑Fi as the Mac). Find the IP in **System Settings → Network → Wi‑Fi → Details**.

### 3. Open the Stripe window in the app

1. Go to the welcome screen (or restart the app to get there).
2. Tap **“Test bank connection”**.
3. The Stripe Financial Connections window should open (connect a bank, or cancel). If you see an alert, read the message: it usually means the app couldn’t reach the backend or the route isn’t available.

### 4. Test a few times

Tap **“Test bank connection”** again: you should get a new session and the Stripe window again. Cancel or complete the flow as you like.

---

## Option B: Use Railway (production)

### 1. Deploy the latest backend to Railway

Your backend code already has the route `POST /api/v1/financial-connections/session`. Deploy the current **ANITA backend** to your Railway project (e.g. `anita-production-bb9a`):

- Push the latest code to the repo that Railway deploys from, **or**
- In the Railway dashboard, open your backend service and use **Redeploy** (or trigger a new deploy from the connected repo).

Ensure the deployed service has these variables set in Railway: `STRIPE_SECRET_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (and any others your app needs).

### 2. Use the default backend in the app

In the ANITA app, open **Settings** and **clear** the **Backend URL** field (leave it empty) and save. The app will then use the default Railway URL (e.g. `https://anita-production-bb9a.up.railway.app`).

### 3. Open the Stripe window

On the welcome screen tap **“Test bank connection”**. After a successful deploy, the Stripe window should open. If you still see “Backend route not found”, the deploy may not include the financial-connections route or the service may not have finished redeploying; wait a minute and try again.

---

## TestFlight / production build

- **You must be signed in.** The "Test bank connection" button requires a logged-in user (userId). If you tap it before signing in, the app shows: "Please sign in first to connect your bank."
- **Backend must be deployed.** TestFlight uses the production backend URL (`https://anita-production-bb9a.up.railway.app`). That deployment must include `POST /api/v1/financial-connections/session` and have `STRIPE_SECRET_KEY` (and Supabase) set in Railway. If the route is missing or old, you get "Backend route not found" — redeploy the latest ANITA backend to Railway.

## Quick checks

| What you see | What to do |
|--------------|------------|
| Alert: “Backend route not found” | Backend doesn’t have the route or app can’t reach it. Use Option A with local backend, or deploy with Option B and use default Backend URL. |
| Alert: “Missing client_secret” or Stripe error | Backend is reached but Stripe isn’t configured. Set `STRIPE_SECRET_KEY` in `.env` (local) or in Railway variables. |
| Stripe window opens | Flow is working. You can connect a bank or cancel; test again by tapping the button once more. |

---

## Summary

- **Local:** Run `npm run dev` in `ANITA backend`, set Backend URL in the app to `http://localhost:3001` (or your Mac IP on device), then tap “Test bank connection” and test a few times.
- **Railway:** Deploy the latest backend to Railway, clear Backend URL in the app, then tap “Test bank connection”.

Reply in English as requested.
