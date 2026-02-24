# Apple In-App Purchase (Subscription) Setup & Testing

The ANITA iOS app uses **Apple In-App Purchase (StoreKit 2)** for Pro and Ultimate subscriptions. Purchases are verified by your backend and stored in Supabase `user_subscriptions`.

## Product IDs

| Plan     | Product ID                 | Price (example) |
|----------|----------------------------|-----------------|
| Pro      | `com.anita.pro.monthly`    | $4.99/month     |
| Ultimate | `com.anita.ultimate.monthly` | $9.99/month   |

## Xcode environment vs TestFlight (important)

What you set in Xcode does **not** all apply to TestFlight or production:

| In Xcode | Applies to TestFlight? |
|----------|------------------------|
| **StoreKit Configuration** (Configuration.storekit in the scheme) | **No.** When it’s enabled, Xcode uses **local** StoreKit only (fake products, no Apple servers). TestFlight and production **always** use real Sandbox / App Store — they never see the .storekit file. So “subscription works in Xcode” with the config enabled only proves your code path; it does **not** prove real Sandbox works. |
| **Environment variables** (Edit Scheme → Run → Arguments → Environment Variables) | **No.** Scheme env vars (e.g. `BACKEND_URL`, `SUPABASE_URL`) are only used when you **run** from Xcode. Archive and TestFlight builds do **not** get them; the app uses the **hardcoded defaults** in `Config.swift` (e.g. production Railway URL). So TestFlight is fine as long as those defaults are correct. |

To be sure subscriptions work for real users:

1. **Test real Sandbox from Xcode** (optional): disable StoreKit Configuration in the scheme (see below), run on a **device**, sign in with **Settings → Developer → Sandbox Account**, then purchase. That uses Apple’s Sandbox.
2. **Test via TestFlight**: install the TestFlight build, sign in with **Settings → App Store → Sandbox Account** (scroll to bottom), then purchase. That’s the same path as production.

---

## Testing in Xcode (StoreKit Configuration – local only)

You can test purchases **without App Store Connect** using the included StoreKit Configuration file. This uses **local** StoreKit only (no real Sandbox).

### 1. Enable the StoreKit Configuration in your scheme

1. In Xcode: **Product → Scheme → Edit Scheme…** (or ⌘<)
2. Select **Run** in the left sidebar.
3. Open the **Options** tab.
4. Under **StoreKit Configuration**, choose **Configuration.storekit** (from the ANITA folder).
5. Close the scheme editor.

### 2. Run and test

1. Run the app in the **Simulator** or on a **device**.
2. Sign in, then open **Upgrade** (or the post-signup plans screen).
3. Tap **Upgrade to Pro** or **Upgrade to Ultimate**.
4. A **local purchase sheet** appears (from the StoreKit config, not the real App Store).
5. Confirm the purchase. The app will:
   - Call your backend `POST /api/v1/verify-ios-subscription` with `userId`, `transactionId`, `productId`.
   - Your backend writes/updates the row in `user_subscriptions`.
6. Use **Restore Purchases** to sync existing entitlements and refresh the subscription state.

### 3. Managing test transactions (Simulator)

- **StoreKit Transaction Manager**: While the app is running, use **Debug → StoreKit → Manage Transactions** to see, delete, or renew test transactions.
- **Accelerate time**: Use **Debug → StoreKit → Subscription Renewal Rate** to speed up renewal (e.g. 1 month in 1 minute) for testing.

### 4. Testing **real** Sandbox from Xcode (optional)

To hit Apple’s real Sandbox (same as TestFlight) while still running from Xcode:

1. **Edit Scheme** → **Run** → **Options**.
2. Under **StoreKit Configuration**, set to **None** (disable the .storekit file).
3. Run the app on a **physical device** (not Simulator).
4. On the device: **Settings → Developer → Sandbox Account** → sign in with a Sandbox tester from App Store Connect.
5. In the app, go to Upgrade and tap **Upgrade to Pro**. You should see the real Sandbox purchase sheet.

When you’re done, you can set StoreKit Configuration back to **Configuration.storekit** for quick local testing.

## Backend requirements

Your backend must:

1. **Expose** `POST /api/v1/verify-ios-subscription`  
   Body: `{ "userId": "<supabase-user-uuid>", "transactionId": "<string>", "productId": "com.anita.pro.monthly" | "com.anita.ultimate.monthly" }`  
   It should map `productId` to a plan (`pro` or `ultimate`) and upsert into `user_subscriptions` (e.g. `user_id`, `plan`, `status: "active"`, `transaction_id`).

2. **Expose** `GET /api/v1/subscription?userId=<id>`  
   So the app can refresh the current plan after purchase or restore.

3. Use the **same Supabase project** and `user_subscriptions` table the app expects.

For local testing, ensure the app’s **backend URL** (e.g. in `Config.swift` for Debug) points to your running backend (e.g. `http://localhost:3001`).

## Production (App Store Connect)

Before submitting to the App Store:

1. **App Store Connect**
   - Create an **In-App Purchase** → **Auto-Renewable Subscription**.
   - Create a **Subscription Group** (e.g. “ANITA Premium”) and add both subscriptions to it.
   - Use the **exact** product IDs: `com.anita.pro.monthly` and `com.anita.ultimate.monthly`.
   - Set pricing (e.g. $4.99 and $9.99) and localization.

2. **Agreements & banking**
   - In App Store Connect: **Agreements, Tax, and Banking** must be complete so subscriptions can be sold.

3. **Sandbox testers**
   - **Users and Access → Sandbox → Testers**: create Sandbox Apple IDs.
   - On device: **iOS 26**: **Settings → Developer → Sandbox Account**. **Older iOS**: **Settings → App Store → Sandbox Account** (scroll to bottom). Sign in with a Sandbox tester.
   - Run the app on the **device** (not Simulator), with the StoreKit Configuration **disabled** in the scheme, so the app uses the real App Store and Sandbox.

4. **Capabilities**
   - The app target must have **In-App Purchase** capability enabled (Xcode → Signing & Capabilities).

## Flow summary

1. User taps **Upgrade to Pro** or **Ultimate** → `StoreKitService.purchase(product)`.
2. StoreKit shows the pay sheet (local config in dev, real App Store in production).
3. On success, the app calls your backend **verify-ios-subscription** with `userId`, `transactionId`, `productId`.
4. Backend updates Supabase `user_subscriptions`.
5. App refreshes subscription (e.g. `GET /api/v1/subscription`) and shows “Purchase Successful” / updated plan.

**Restore Purchases** uses `AppStore.sync()` and `Transaction.currentEntitlements`, then the app refreshes subscription from the backend so the UI matches the database.

---

## TestFlight: “Upgrade” button not active or subscriptions not loading

In TestFlight, in-app purchases use **Sandbox**, not the StoreKit Configuration file. If the upgrade button is greyed out or nothing happens when you tap it:

### 1. “Current Plan” instead of “Upgrade”

If you see **Current Plan** on the Pro card (and no **Upgrade to Premium** button), the app thinks you already have an active subscription (from the database or a previous Sandbox purchase). To test buying again:

- **Restore Purchases** will re-sync; if you want to test a fresh purchase, use a **different Sandbox Apple ID** that has never purchased, or clear the app data / use a new test account in your app.

### 2. Products never load (button stays loading or “Retry” appears)

- **Sandbox account on the device**  
  On your iPhone: **Settings → App Store → Sandbox Account** → sign in with a **Sandbox** Apple ID (from App Store Connect → Users and Access → Sandbox → Testers). Do **not** use your real Apple ID for TestFlight IAP testing.

- **App Store Connect**  
  - The subscription product **com.anita.pro.monthly** must exist and be **Approved** (or at least ready for sale).  
  - **Agreements, Tax, and Banking** must be complete.  
  - The app’s **Bundle ID** in Xcode must match the app in App Store Connect.

- **Scheme**  
  For TestFlight builds, **do not** use a StoreKit Configuration file in the Run scheme (that’s for local Xcode runs only). TestFlight always uses the real Sandbox environment.

- In the app, if you see **“Subscription options could not be loaded”** and a **Retry** button, tap **Retry** after confirming the Sandbox account and App Store Connect setup above. Opening the Upgrade screen again also triggers a reload.

### 3. How Sandbox renewal works

In **Sandbox**, subscription durations are shortened so you can test renewals and expiry without waiting a real month:

| Real duration | Sandbox duration (approx.) |
|---------------|----------------------------|
| 1 week        | 3 minutes                  |
| 1 month       | 5 minutes                  |
| 2 months      | 10 minutes                 |
| 3 months      | 15 minutes                |
| 6 months      | 30 minutes                 |
| 1 year        | 1 hour                     |

So a **1‑month** subscription will auto‑renew every **about 5 minutes** in Sandbox. After several renewals (e.g. 6 for a monthly), Sandbox may stop renewing so you can test “subscription expired” and **Restore Purchases** again later.
