# ANITA Backend & Bank Connection – Config Checklist

Use this to confirm everything is set so the app and bank connection (Stripe Financial Connections) work.

---

## 1. Backend `.env` (ANITA backend/.env)

| Variable | Required for | Notes |
|----------|--------------|--------|
| **SUPABASE_URL** | All | Your Supabase project URL (e.g. `https://xxx.supabase.co`) |
| **SUPABASE_SERVICE_ROLE_KEY** | All | From Supabase → Settings → API → service_role key |
| **STRIPE_SECRET_KEY** | Bank connection, checkout | From Stripe Dashboard → Developers → API keys (`sk_live_...` or `sk_test_...`) |
| **STRIPE_WEBHOOK_SECRET** | Bank connection (webhook) | From Stripe → Developers → Webhooks → your endpoint → Signing secret (`whsec_...`) |
| OPENAI_API_KEY | Chat, transcription | For AI features |
| PORT | Optional | Default 3001; Railway sets this |

- No quotes needed around values; if you use quotes, the backend trims them.
- Run the backend from the **ANITA backend** folder so `.env` is loaded from there.

---

## 2. Supabase – Bank tables

Run **`ANITA backend/create_bank_tables.sql`** in Supabase SQL Editor once. This adds:

- **profiles.stripe_customer_id** – links Stripe Customer to ANITA user
- **bank_accounts** – linked bank accounts from Stripe Financial Connections
- **bank_transactions** – transactions synced from linked accounts

If these are missing, the financial-connections session still works, but the webhook cannot store accounts/transactions.

---

## 3. Stripe Dashboard – Webhook (for syncing accounts/transactions)

1. **Developers** → **Webhooks** → **Add endpoint**
2. **Endpoint URL:** `https://YOUR_BACKEND_URL/api/v1/stripe/webhook`  
   (e.g. `https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook` for production)
3. **Events:**  
   - `financial_connections.account.created`  
   - `financial_connections.account.refreshed`
4. Copy the **Signing secret** (`whsec_...`) into **STRIPE_WEBHOOK_SECRET** in `.env` (and Railway Variables for production).

Without this, users can connect a bank in the app, but accounts and transactions are not saved to Supabase.

---

## 4. iOS app (ANITA IOS)

- **Config.swift** – `stripePublishableKey` is set (publishable key only; safe in the app).
- **Backend URL** – In DEBUG the app uses `http://localhost:3001`. For a physical device, set **Settings → Backend URL** to `http://YOUR_MAC_IP:3001`. For TestFlight/release it uses the production URL in `Config.productionBackendURL`.

---

## 5. Quick verification

| Check | How |
|-------|-----|
| Backend runs | `cd "ANITA backend" && npm run dev` → no “Stripe secret key not configured” (if STRIPE_SECRET_KEY is set). |
| Session endpoint | `curl -X POST http://localhost:3001/api/v1/financial-connections/session -H "Content-Type: application/json" -d '{"userId":"ANY_UUID","userEmail":"a@b.com"}'` → 200 and `client_secret` in JSON. |
| Stripe window in app | Run app from Xcode (simulator), sign in, tap “Test bank connection” → Stripe sheet opens. |
| Webhook (production) | In Stripe Dashboard → Webhooks → your endpoint, send a test event or connect a bank and check that events are received (200). |

---

## 6. Production (Railway / TestFlight)

- Set the same variables in **Railway** (or your host) as in `.env`.
- Deploy the latest backend so it includes `POST /api/v1/financial-connections/session` and the Stripe webhook route.
- Webhook URL in Stripe must use your production backend URL (e.g. `https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook`).

Once this checklist is done, you can work on the app and bank connection flow with everything configured correctly.
