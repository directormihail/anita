# Apple In-App Purchase (Subscription) Setup & Testing

The ANITA iOS app uses **Apple In-App Purchase (StoreKit 2)** for Pro and Ultimate subscriptions. Purchases are verified by your backend and stored in Supabase `user_subscriptions`.

## Product IDs

| Plan     | Product ID                 | Price (example) |
|----------|----------------------------|-----------------|
| Pro      | `com.anita.pro.monthly`    | $4.99/month     |
| Ultimate | `com.anita.ultimate.monthly` | $9.99/month   |

## Testing in Xcode (StoreKit Configuration)

You can test purchases **without App Store Connect** using the included StoreKit Configuration file.

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
   - On device: **Settings → App Store → Sandbox Account** and sign in with a Sandbox tester.
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
