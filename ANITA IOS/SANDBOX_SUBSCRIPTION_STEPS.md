# How to activate a subscription with Sandbox on your iPhone (step by step)

Use this when testing the ANITA app from **TestFlight** on your iPhone. Sandbox = test purchases that don’t charge real money.

---

## I don't see "Sandbox" or "Developer" on my iPhone

**iOS 16+ (including iOS 26):**  
- **Run from Xcode:** Turn on **Settings → Privacy & Security → Developer Mode** (device restarts). Then **Settings → Developer → Sandbox Account** → sign in with Sandbox tester. On iOS 26, Sandbox is here, not under App Store.  
- **TestFlight only:** **Settings → App Store** → scroll to the very bottom → **Sandbox Account** → sign in. If the section is missing, open the app, tap Upgrade once, then check Settings → App Store again.

**Checklist so subscription works:**  
1. **iPhone:** Signed in to Sandbox (Developer → Sandbox Account on iOS 26, or App Store → Sandbox Account on TestFlight).  
2. **App Store Connect:** Agreements, Tax & Banking complete; Paid Apps agreement; subscription `com.anita.pro.monthly` exists and is Ready to Submit or Approved.  
3. **Xcode:** Edit Scheme → Run → Options → StoreKit Configuration = **None**. Signing & Capabilities → add **In-App Purchase** if missing.  
4. **In app:** Upgrade → **Retry** if products don't load → **Upgrade to Premium**.

---

## If you already use your Sandbox account

- **Same account is fine.** You can keep using it. To test **Restore Purchases**, tap **Restore Purchases** on the Upgrade screen; the app will sync with Apple and your backend.
- **To test “buy again” (new subscription):**
  - **Option A:** In Sandbox, a 1‑month subscription renews ~every 5 minutes and stops after several renewals. Wait until it has expired (or use **Settings → App Store → Sandbox Account** and check subscription status), then in the app tap **Upgrade to Premium** again to simulate a new purchase.
  - **Option B:** Create a **second Sandbox tester** in App Store Connect (Users and Access → Sandbox → Testers → +). On the iPhone, sign out of the current Sandbox account (Settings → App Store → Sandbox Account) and sign in with the new one. Then in the app you can test a first-time purchase again.
- **Don’t use your real Apple ID** for TestFlight IAP testing; always use a Sandbox tester.

---

## Part 1: App Store Connect (on your computer)

Do this once before testing on the phone.

### Step 1.1 – Create a Sandbox tester account

1. Go to [App Store Connect](https://appstoreconnect.apple.com) and sign in.
2. Click **Users and Access** (top menu).
3. Open the **Sandbox** tab.
4. Click **Testers** (under Sandbox).
5. Click the **+** button to add a tester.
6. Fill in:
   - **First name / Last name** – any (e.g. Test, User).
   - **Email** – use a **new, fake email** that is not a real Apple ID (e.g. `anita.sandbox.test1@gmail.com` or `test1@example.com`). Apple will treat it as a Sandbox account.
   - **Password** – choose a password (you’ll use it on the iPhone).
   - **Country or region** – pick one (e.g. United States).
7. Click **Create**. You now have a **Sandbox Apple ID** (that email + password).

### Step 1.2 – Check the subscription product

1. In App Store Connect go to **My Apps** → select **ANITA**.
2. Open the **Subscriptions** or **In-App Purchases** section (depending on your layout).
3. Make sure you have an **Auto-Renewable Subscription** with product ID **exactly**: `com.anita.pro.monthly`.
4. Its status should be **Ready to Submit** or **Approved** (not “Missing metadata” or “Rejected”).
5. Under **Agreements, Tax, and Banking** (in App Store Connect, not in the app), make sure you have a valid **Paid Apps** agreement and banking/tax set up. Otherwise Sandbox purchases can fail.

---

## Part 2: iPhone – Sign in to Sandbox

Do this on the **iPhone** where you’ll test (with the TestFlight build of ANITA installed).

### Step 2.1 – Open Sandbox account settings

1. Open **Settings**.
2. Scroll down and tap **App Store**.
3. Scroll down again until you see **Sandbox Account** (near the bottom).
4. Tap **Sandbox Account**.

### Step 2.2 – Sign in with your Sandbox Apple ID

1. If it says “Sign in”, tap it.
2. Enter the **email** of the Sandbox tester you created (Step 1.1).
3. Enter the **password** you set for that tester.
4. Complete sign-in (and any prompts). You should see the Sandbox account email shown under **Sandbox Account**.

Important:  
- Use **only** the Sandbox tester account here for IAP testing.  
- Do **not** use your real Apple ID for TestFlight subscription tests.

---

## Part 3: In the ANITA app (TestFlight) – Buy the subscription

### Step 3.1 – Open the app and go to Upgrade

1. Open **TestFlight** on your iPhone.
2. Open **ANITA**.
3. In ANITA, sign in or use your test account (the one that should be on the **Free** plan).
4. Go to the screen where you can upgrade (e.g. **Upgrade** / **Premium** or the plan screen after signup). In the app this is usually: open the menu/sidebar → **Upgrade**, or tap an “Upgrade to Premium” / “Pro” offer.

### Step 3.2 – Tap the upgrade button

1. On the upgrade screen you should see a **Free** plan and a **Premium** (Pro) plan.
2. If you see **“Current Plan”** on the Premium card and no button, the app thinks you’re already subscribed. Then either:
   - Use **Restore Purchases** to sync, or  
   - Use a different in-app account / a different Sandbox Apple ID that hasn’t bought yet.
3. If you see **“Upgrade to Premium”** (or similar), tap that button.
4. If you see **“Subscription options could not be loaded”** and a **Retry** button:
   - Check that you’re signed in to the **Sandbox Account** in Settings → App Store (Part 2).
   - Tap **Retry**, or close the upgrade screen and open it again.

### Step 3.3 – Confirm the purchase in the Apple sheet

1. After tapping **Upgrade to Premium**, a **system dialog** (from Apple) appears asking to confirm the subscription.
2. It may say **“[Environment: Sandbox]”** – that’s correct for testing.
3. Tap **Subscribe** / **Confirm** (or the equivalent). In Sandbox, **no real money** is charged.
4. If asked for a password, use the **Sandbox account** password (the one from Step 1.1).

### Step 3.4 – Success in the app

1. The sheet closes and the app should show something like **“Purchase Successful”** or the Premium card as **“Current Plan”**.
2. Your backend is called to activate the subscription for your user; the app then shows you as Premium.

---

## Part 4: How renewal works in Sandbox

- In **Sandbox**, a **1‑month** subscription renews about **every 5 minutes** (not every real month).
- So you can see “renewal” and “active subscription” without waiting.
- After several renewals (e.g. 6 for a monthly), Sandbox may **stop** renewing so you can test “subscription expired”.
- To test again with a “new” purchase, you can use another Sandbox tester or wait until the Sandbox subscription is expired and buy again.

---

## Quick checklist

- [ ] Sandbox tester created in App Store Connect (Users and Access → Sandbox → Testers).
- [ ] On iPhone: Settings → App Store → Sandbox Account → signed in with that Sandbox email/password.
- [ ] In App Store Connect: subscription `com.anita.pro.monthly` exists and is Ready/Approved; Agreements, Tax, and Banking are complete.
- [ ] In ANITA (TestFlight): open Upgrade, tap **Upgrade to Premium**, confirm in the Apple dialog.
- [ ] If the button doesn’t work or products don’t load: tap **Retry** and/or re-check Sandbox sign-in and App Store Connect setup.

That’s how you activate and test the subscription with Sandbox on your iPhone, step by step.

---

## If purchase says "Fail" or "Purchase failed" in TestFlight

The app now shows **Apple’s exact error** plus a hint. Check these in order:

1. **Sandbox account (TestFlight)**  
   For TestFlight, Sandbox is **Settings → App Store** → scroll to the **very bottom** → **Sandbox Account** → sign in with your Sandbox tester (from App Store Connect).  
   **Not** Settings → Developer (that’s for Xcode builds only).

2. **Same Apple ID on device**  
   The iPhone must be signed into the **Sandbox** account in **Settings → App Store → Sandbox Account**. If that section isn’t there, try: open the app → Upgrade → tap Upgrade to Premium once → then check Settings → App Store again and scroll to the bottom.

3. **App Store Connect**  
   - Subscription **com.anita.pro.monthly** exists and status is **Ready to Submit** or **Approved**.  
   - **Agreements, Tax, and Banking** are complete (required for IAP).  
   - The app in App Store Connect has the **same Bundle ID** as the Xcode project (e.g. `com.anita.app`).

4. **Region**  
   Sandbox tester’s country in App Store Connect should match the App Store region (or be supported for that subscription).

5. **Restore**  
   If you already “bought” in Sandbox before, tap **Restore Purchases** on the Upgrade screen; the app may then show you as Premium.

After you fix the cause, tap **Retry** on the Upgrade screen (or reopen Upgrade) and try again. The red error text will show the latest message from the system so you can see what’s still wrong.
