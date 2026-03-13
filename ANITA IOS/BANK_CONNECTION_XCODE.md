# See the Stripe Bank Connection Window in Xcode

Follow these steps so that when you tap **"Test bank connection"** in the app (running from Xcode), the Stripe Financial Connections window opens and you can choose a bank.

## 1. Backend: add Stripe key

The backend must return a `client_secret` so the app can show the Stripe sheet. That requires a Stripe secret key.

- Open **`ANITA backend/.env`** (create from `.env.example` if needed).
- Set **`STRIPE_SECRET_KEY`** to your Stripe secret key, e.g.:
  - Test: `STRIPE_SECRET_KEY=sk_test_...` (from [Stripe Dashboard → Developers → API keys](https://dashboard.stripe.com/test/apikeys))
  - Live: `STRIPE_SECRET_KEY=sk_live_...`
- Ensure **`SUPABASE_URL`** and **`SUPABASE_SERVICE_ROLE_KEY`** are also set (needed to create/link the Stripe customer).

## 2. Run the backend

In a terminal:

```bash
cd "ANITA backend"
npm run dev
```

Leave it running. You should see: `Running on http://localhost:3001` and no "Stripe secret key not configured" error.

## 3. Run the app from Xcode

- Open the ANITA project in Xcode.
- Choose the **iPhone 17** (or any) **simulator** as the run destination.
- Run the app (⌘R).

In **DEBUG** builds the app uses **`http://localhost:3001`** by default, so you don’t need to change anything in Settings.

## 4. Sign in

The bank connection flow needs a signed-in user. Sign in or sign up in the app.

## 5. Tap "Test bank connection"

On the welcome screen, tap **"Test bank connection"**. The Stripe Financial Connections window should open; you can select a bank or cancel.

---

## If the Stripe window doesn’t open

| What you see | What to do |
|--------------|------------|
| "Please sign in first to connect your bank" | Sign in, then tap again. |
| "Stripe is not configured" or "Missing client_secret" | Set `STRIPE_SECRET_KEY` in `ANITA backend/.env` and restart the backend. |
| "Backend route not found" / "this server doesn't have the financial-connections route" | Backend isn’t running or app isn’t hitting it. In DEBUG the app uses `http://localhost:3001`; run `npm run dev` in `ANITA backend`. |
| Running on a **physical device** from Xcode | Simulator uses `localhost`; a device cannot. In the app go to **Settings → Backend URL** and set `http://YOUR_MAC_IP:3001` (same Wi‑Fi as the Mac). |

## Optional: change backend URL (e.g. device or custom URL)

- In the app: **Settings** tab → **Preferences** → **Backend URL**.
- Enter the base URL (e.g. `http://localhost:3001` or `http://192.168.1.x:3001`) and save.
