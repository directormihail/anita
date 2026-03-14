# Stripe webhook endpoint – receive data & test

Your backend **already has** the endpoint that receives Stripe Financial Connections data:

- **URL:** `POST /api/v1/stripe/webhook`
- **Full URL (local):** `http://localhost:3001/api/v1/stripe/webhook`
- **Full URL (Railway):** `https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook` — use this as the **Endpoint URL** in Stripe Dashboard when you want events sent to production.

Stripe sends `financial_connections.account.created` and `financial_connections.account.refreshed` to this URL; the handler stores accounts in `bank_accounts` and transactions in `bank_transactions`.

---

## 1. Create the endpoint in Stripe (test mode)

1. Open [Stripe Dashboard](https://dashboard.stripe.com) and turn **Test mode** ON (top-right).
2. Go to **Developers** → **Webhooks** → **Add endpoint**.
3. **Endpoint URL:**
   - **Local testing:** use Stripe CLI (step 3 below) to get a forwarding URL, or use a tunnel (e.g. ngrok: `https://YOUR_SUBDOMAIN.ngrok.io/api/v1/stripe/webhook`).
   - **Deployed backend:**  
     `https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook`
4. Click **Select events** and add:
   - `financial_connections.account.created`
   - `financial_connections.account.refreshed`
5. Click **Add endpoint**.
6. Open the new endpoint → **Reveal** under **Signing secret** → copy the value (starts with `whsec_`).
7. In **`ANITA backend/.env`** set:
   ```env
   STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxx
   ```
   (Paste the value you copied.) Restart the backend so it picks up the variable.

---

## 2. Test with Stripe CLI (local)

This forwards Stripe events to your local server and gives you a temporary signing secret.

1. Install Stripe CLI: https://stripe.com/docs/stripe-cli  
   (e.g. `brew install stripe/stripe-cli/stripe` on macOS.)

2. Log in and start forwarding to your webhook route:
   ```bash
   stripe login
   stripe listen --forward-to localhost:3001/api/v1/stripe/webhook
   ```
   Leave this running. It will print a **webhook signing secret** like `whsec_...`.

3. In **`.env`** set that value:
   ```env
   STRIPE_WEBHOOK_SECRET=whsec_xxxx   # from "stripe listen" output
   ```
   Restart your backend (e.g. `npm run dev`).

4. In **another terminal**, trigger a test event:
   ```bash
   stripe trigger financial_connections.account.created
   ```
   In the first terminal you should see the event being forwarded. Your handler will run; if it can’t find a matching Stripe customer in `profiles.stripe_customer_id`, it will log a warning but still receive the event.

5. To test the full flow (so data lands in your DB), create a Financial Connections session with a **test** user, link a **test institution** in the Stripe UI, then check:
   - **Bank accounts:** `GET /api/v1/bank-accounts?userId=YOUR_USER_ID`
   - **Bank transactions:** `GET /api/v1/bank-transactions?userId=YOUR_USER_ID&from=2020-01-01&to=2030-12-31`

---

## 3. Test with a real test bank connection (app or API)

1. Ensure **test** keys are in `.env` (you’re using test secret/publishable).
2. Ensure `STRIPE_WEBHOOK_SECRET` is set (from Dashboard or from `stripe listen`).
3. Create a session:
   ```bash
   curl -X POST http://localhost:3001/api/v1/financial-connections/session \
     -H "Content-Type: application/json" \
     -d '{"userId":"YOUR_SUPABASE_USER_UUID","userEmail":"you@example.com"}'
   ```
4. Use the returned `client_secret` in your app (or Stripe’s hosted link) and go through the Connect flow. Choose a **test institution** (e.g. “Test (Non-OAuth)” or “Bank (Non-OAuth)” with username/password `test`/`test`).
5. After linking, Stripe sends events to `POST /api/v1/stripe/webhook`; your backend fills `bank_accounts` and `bank_transactions`. Verify with:
   - `GET /api/v1/bank-accounts?userId=YOUR_USER_ID`
   - `GET /api/v1/bank-transactions?userId=YOUR_USER_ID&from=...&to=...`

---

## Quick checklist

- [ ] **Test mode** ON in Stripe Dashboard.
- [ ] Webhook endpoint added in Dashboard with URL pointing to your backend (or Stripe CLI).
- [ ] Events selected: `financial_connections.account.created`, `financial_connections.account.refreshed`.
- [ ] `STRIPE_WEBHOOK_SECRET` set in `.env` and backend restarted.
- [ ] For local receive: `stripe listen --forward-to localhost:3001/api/v1/stripe/webhook` and trigger with `stripe trigger financial_connections.account.created`, or run full flow with test institution.
