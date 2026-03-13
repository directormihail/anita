# SFC – What you need to configure

Supabase is already set up (tables `bank_accounts`, `bank_transactions`, and `profiles.stripe_customer_id` are in place). Do the following for Stripe Financial Connections.

---

## 1. Add the webhook in Stripe

1. Go to **[Stripe Dashboard](https://dashboard.stripe.com) → Developers → Webhooks**.
2. Click **Add endpoint**.
3. **Endpoint URL** – paste exactly:
   ```text
   https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook
   ```
   (If your backend URL is different, use: `https://YOUR_BACKEND_URL/api/v1/stripe/webhook`.)
4. Click **Select events** and add:
   - `financial_connections.account.created`
   - `financial_connections.account.refreshed`
5. Click **Add endpoint**.
6. Open the new endpoint and click **Reveal** under **Signing secret**.
7. Copy the value (it starts with `whsec_`).

---

## 2. Set the webhook secret

- **Local (ANITA backend):** In **`.env`** add or update:
  ```env
  STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxx
  ```
  (paste the value you copied).

- **Production (Railway):** In your Railway project → **Variables** add:
  - **Name:** `STRIPE_WEBHOOK_SECRET`
  - **Value:** the same `whsec_...` value.
  If the app is already deployed, redeploy so it picks up the new variable.

---

## 3. Deploy and test (optional)

- Deploy the backend to Railway (or run it locally with `npm run build && npm start`).
- To test the session endpoint:
  ```bash
  curl -X POST https://anita-production-bb9a.up.railway.app/api/v1/financial-connections/session \
    -H "Content-Type: application/json" \
    -d '{"userId":"YOUR_SUPABASE_USER_UUID","userEmail":"you@example.com"}'
  ```
  You should get JSON with `client_secret` and `session_id`.

---

## Summary

| Step | Where | What to do |
|------|--------|------------|
| 1 | Stripe Dashboard → Webhooks | Add endpoint with the URL above; select the two `financial_connections.*` events; copy **Signing secret**. |
| 2 | Backend `.env` + Railway Variables | Set `STRIPE_WEBHOOK_SECRET` to the `whsec_...` value. |
| 3 | Railway / local | Deploy or run backend so it uses the new env. |

After this, when users connect a bank via your app, Stripe will call your webhook and the backend will store accounts and transactions in Supabase. Use **GET /api/v1/bank-accounts** and **GET /api/v1/bank-transactions** from the app to show the data.
