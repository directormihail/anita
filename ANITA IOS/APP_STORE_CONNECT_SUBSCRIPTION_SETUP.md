# App Store Connect – Subscription setup (step by step)

Do these in order. Your app uses **one** subscription: product ID **com.anita.pro.monthly** (Premium). Bundle ID in Xcode: **com.anita.app**.

---

## Step 1: Agreements, Tax, and Banking (required first)

Without this, Sandbox and real purchases will not work.

1. Go to [App Store Connect](https://appstoreconnect.apple.com) and sign in.
2. In the top bar, click **your name / account** (top right) or go to the main dashboard.
3. Open **Agreements, Tax, and Banking** (from the main App Store Connect page or under **Users and Access** → **Agreements, Tax, and Banking** depending on your layout).
4. Under **Agreements**:
   - If **Paid Applications** (or **Paid Apps**) shows **Action needed** or is missing → click it and **accept** the agreement. Fill any required fields.
   - If there is **Banking** or **Tax** with **Action needed** → open each and complete the forms (bank details, tax forms, contact info).
5. When **Paid Applications** (and Banking/Tax if shown) show **Active** or **Complete**, you’re done. Leave this page.

---

## Step 2: Open your app and go to Subscriptions

1. In App Store Connect, click **Apps** (or **My Apps**) in the top navigation.
2. Click your app (**Anita Finance** / **ANITA** – the one with Bundle ID **com.anita.app**).
3. In the left sidebar, under **Distribution** or **Monetization**, click **Subscriptions** (or **In-App Purchases** → **Subscriptions**).

You should see either:
- A list of subscription groups, or  
- A button like **Create** / **+** to create a subscription or group.

---

## Step 3: Create or open the subscription group

Subscriptions must sit inside a **subscription group**. You might already have one (e.g. “Anita Premium”).

- **If you already have a group** (e.g. “Anita Premium”): click it and go to **Step 4**.
- **If you need to create a group:**
  1. Click **Create** / **+** or **Subscription Group** (wording may be “Create subscription group” or similar).
  2. **Reference name** (internal): e.g. `Anita Premium`.
  3. **Group name** (for App Store): e.g. `Anita Premium` or `Premium`.
  4. Save / Create. Then open that group.

---

## Step 4: Create or edit the subscription (product)

You need **one** auto‑renewable subscription with this **exact** product ID: **com.anita.pro.monthly**.

- **If it already exists:** click the subscription and go to **Step 5** to check pricing and localization.
- **If you need to create it:**
  1. Inside the subscription group, click **Create** / **+** or **Create subscription**.
  2. **Subscription type:** **Auto-Renewable Subscription**.
  3. **Reference name** (internal): e.g. `Premium` or `Pro Monthly`.
  4. **Product ID:** type exactly:  
     **com.anita.pro.monthly**  
     (only letters, numbers, dots, underscores – no spaces).
  5. **Subscription duration:** e.g. **1 month** (or whatever your app expects).
  6. Save / Create. Then open that subscription.

---

## Step 5: Subscription pricing

1. Open the subscription **com.anita.pro.monthly** (from the group).
2. Find the **Pricing** or **Subscription Prices** section.
3. Click **Add price** / **Add subscription price** (or edit the existing one).
4. Choose a **price tier** (e.g. Tier 3 ≈ $2.99, or the tier that matches your desired price, e.g. $4.99).
5. Choose **base country/region** (e.g. United States).
6. Save. Other regions can use the same tier or be set later.

---

## Step 6: Subscription localization (name and description)

1. Still on the subscription **com.anita.pro.monthly**.
2. Find **App Store localization** or **Localization** (or **Subscription localizations**).
3. Click **Add localization** (or the **+** next to localizations).
4. **Language:** e.g. **English (U.S.)**.
5. **Display name:** e.g. `Premium` (what users see).
6. **Description:** e.g. `Unlock all Premium ANITA features.` (required; keep under the character limit shown).
7. Save. Add more languages (e.g. German) the same way if you want.

---

## Step 7: Subscription status

1. On the same subscription page, find **Status** or **App Store status**.
2. Resolve any **Missing metadata** or **Errors** (missing price, missing localization, etc.).
3. Goal: status **Ready to Submit** (or **Approved** after review).  
   Sandbox works when the subscription is **Ready to Submit**; you don’t have to submit the app first to test.

---

## Step 8: (Optional) Link subscription to an app version for submission

Only needed when you **submit the app** to the App Store:

1. In the left sidebar, click **App Store** (or your app’s main page).
2. Under **iOS App**, select the version you’re submitting (e.g. **1.0**).
3. Scroll to **In-App Purchases** or **In-App Purchases and Subscriptions**.
4. Click **+** or **Select in-app purchases** and **add** the subscription **com.anita.pro.monthly** to this version.
5. Save. Then submit the version for review when ready.

For **Sandbox testing** you do **not** need to attach the subscription to a version; Step 7 is enough.

---

## Quick checklist (App Store Connect only)

- [ ] **Agreements, Tax, and Banking:** Paid Applications agreement accepted; Banking/Tax complete if required.
- [ ] **Apps** → your app → **Subscriptions** (or In-App Purchases → Subscriptions).
- [ ] **Subscription group** exists (e.g. Anita Premium); subscription **com.anita.pro.monthly** is inside it.
- [ ] **Subscription** has: Product ID **com.anita.pro.monthly**, duration (e.g. 1 month), **price** set, at least one **localization** (name + description).
- [ ] **Status** = **Ready to Submit** (or Approved).
- [ ] (For release) Subscription added to the app version in **In-App Purchases** on the version page.

After this, Sandbox testing should work on the device (Sandbox account signed in, StoreKit Configuration = None in Xcode, Retry on the Upgrade screen if needed).
