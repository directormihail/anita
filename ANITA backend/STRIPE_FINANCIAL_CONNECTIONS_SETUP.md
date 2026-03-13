# Stripe Financial Connections (SFC) – Step-by-step setup

Follow these steps so ANITA can link user bank accounts and sync transactions.

---

## Step 1: Create the database tables (Supabase)

1. Open **Supabase** → your project → **SQL Editor**.
2. Open the file **`ANITA backend/create_bank_tables.sql`** from this repo.
3. Copy its full contents into the SQL Editor and **Run**.
4. Confirm that `profiles` has a new column `stripe_customer_id`, and that tables **`bank_accounts`** and **`bank_transactions`** exist.

---

## Step 2: Add the webhook endpoint in Stripe Dashboard

1. Go to [Stripe Dashboard](https://dashboard.stripe.com) → **Developers** → **Webhooks**.
2. Click **Add endpoint**.
3. **Endpoint URL** – paste this (replace with your real backend URL if different):

   **Production (Railway):**
   ```text
   https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook
   ```

   If your backend is elsewhere, use: `https://YOUR_BACKEND_URL/api/v1/stripe/webhook`
4. Click **Select events** and add:
   - `financial_connections.account.created`
   - `financial_connections.account.refreshed`
5. Click **Add endpoint**.
6. Open the new endpoint and click **Reveal** under **Signing secret**.
7. Copy the value (starts with `whsec_`).

---

## Step 3: Set the webhook secret in your backend

1. **Local:** In **`ANITA backend/.env`** add (or update):
   ```env
   STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxx
   ```
   Use the value you copied in Step 2.
2. **Railway (production):** In your Railway project → **Variables** add:
   - **Name:** `STRIPE_WEBHOOK_SECRET`
   - **Value:** the same `whsec_...` signing secret.
3. Redeploy the backend on Railway if it’s already running so the new variable is picked up.

---

## Step 4: Deploy and test the backend

1. From the **ANITA backend** folder run:
   ```bash
   npm run build
   npm start
   ```
2. (Optional) Test creating a Financial Connections session:
   ```bash
   curl -X POST http://localhost:3001/api/v1/financial-connections/session \
     -H "Content-Type: application/json" \
     -d '{"userId":"YOUR_SUPABASE_USER_UUID","userEmail":"you@example.com"}'
   ```
   You should get JSON with `client_secret` and `session_id`.

---

## Step 5: Use the endpoints from the iOS app

- **Create session (onboarding “Connect bank”):**  
  `POST /api/v1/financial-connections/session`  
  Body: `{ "userId": "<Supabase auth user id>", "userEmail": "<optional>" }`  
  Response: `{ "client_secret": "...", "session_id": "..." }`  
  Use `client_secret` with the Stripe iOS SDK (e.g. Financial Connections flow) or Stripe’s hosted link.

- **List connected accounts:**  
  `GET /api/v1/bank-accounts?userId=<user_id>`

- **List transactions:**  
  `GET /api/v1/bank-transactions?userId=<user_id>&from=YYYY-MM-DD&to=YYYY-MM-DD&limit=100`

---

## Quick checklist

- [ ] Ran **create_bank_tables.sql** in Supabase.
- [ ] Added webhook endpoint in Stripe with URL **`https://anita-production-bb9a.up.railway.app/api/v1/stripe/webhook`** (or your backend URL).
- [ ] Subscribed to **financial_connections.account.created** and **financial_connections.account.refreshed**.
- [ ] Set **STRIPE_WEBHOOK_SECRET** in `.env` (local) and in Railway Variables (production).
- [ ] Backend builds and starts; session endpoint returns `client_secret`.

After this, when a user completes the Financial Connections flow, Stripe will send events to your webhook and the backend will store accounts and transactions in **bank_accounts** and **bank_transactions** for the app to display.
