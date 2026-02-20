# App Store submission checklist – ANITA

Use this before submitting for **App Review** so you don’t get rejected for missing metadata or compliance.

---

## 1. App Store Connect – App information

| Item | Where | What to do |
|------|--------|------------|
| **Privacy Policy URL** | App Store Connect → Your App → **App Information** (or **App Privacy**) | Set a working URL, e.g. `https://anita.app/privacy`. Must open a real page (your site or backend). |
| **Terms of Use (EULA) URL** | Same → **Terms of Use (EULA)** | Set a working URL, e.g. `https://anita.app/terms`. Required if you have paid subscriptions or account creation. |
| **Category** | **App Information** → Primary Category | e.g. **Finance** (fits ANITA). |
| **Age Rating** | **App Information** → Age Rating | Complete the questionnaire. For a finance app with no restricted content, typically **4+** or **12+** depending on answers. |
| **Copyright** | **App Information** | e.g. `© 2025 Your Name or Company`. |

---

## 2. App Store Connect – Version / build

| Item | Where | What to do |
|------|--------|------------|
| **Screenshots** | **App Store** tab → iOS App → **Screenshots** | At least one screenshot per required device size (e.g. 6.7", 6.5", 5.5"). Use real app screens or simulators. |
| **App Preview (optional)** | Same | Short video; optional but can help. |
| **Description** | **App Store** → Version → **Description** | Clear description of ANITA (finance assistant, AI, etc.). No misleading claims. |
| **Keywords** | Same | Relevant keywords; no competitor names or inappropriate terms. |
| **Support URL** | Same | A URL where users can get help. Can be `https://anita.app/support` or a page that explains “Support in app: Settings → Support”. |
| **Marketing URL (optional)** | Same | Optional; e.g. landing page. |
| **Version** | Same | Must match Xcode **Marketing Version** (e.g. 1.1). |
| **Build** | Same | Select the build you uploaded (e.g. 1.1 (2)). Build number must be **higher** than any previously submitted build for that version. |

---

## 3. Subscriptions / In‑App Purchase (IAP)

| Item | Where | What to do |
|------|--------|------------|
| **Subscription group** | App Store Connect → **Subscriptions** (under your app) | Create a subscription group if not done (e.g. “Premium”). |
| **Product** | Same → **In-App Purchases** | Ensure `com.anita.pro.monthly` (Premium) exists, is **Approved**, and is in the right subscription group. |
| **Subscription prices** | Same → your subscription → **Subscription Prices** | Set price(s) and territories. |
| **Subscription terms** | Shown in app | ✅ You already show: payment charged to Apple ID, auto-renewal, cancel anytime in Apple ID settings. |
| **Restore Purchases** | In app | ✅ Visible on Upgrade and post-signup plan screens. |
| **Financial disclaimer** | In app | ✅ “ANITA is for informational use only and does not provide financial, legal, or tax advice.” |

---

## 4. App Privacy (App Store Connect)

| Item | Where | What to do |
|------|--------|------------|
| **App Privacy questionnaire** | App Store Connect → **App Privacy** | Answer all questions: what data you collect (email, financial data, usage, etc.), how it’s used, whether it’s linked to identity, etc. |
| **Privacy nutrition labels** | Same | Your answers appear on the App Store page. Align with your actual Privacy Policy and app behavior (Supabase, OpenAI, Stripe/Apple IAP, etc.). |

---

## 5. Export compliance

| Item | Where | What to do |
|------|--------|------------|
| **Encryption** | Info.plist / App Store Connect | ✅ **ITSAppUsesNonExemptEncryption** is set to **false** in Info.plist (only standard HTTPS / exempt encryption). When you upload a build, you can answer “No” to using non-exempt encryption. If asked, you do not need to upload CCATS documentation. |

---

## 6. In the app (already done)

| Item | Status |
|------|--------|
| Privacy Policy accessible (e.g. Settings, Login) | ✅ |
| Terms of Use accessible | ✅ |
| Restore Purchases button | ✅ |
| Subscription terms (renewal, cancel) | ✅ |
| Financial disclaimer | ✅ |
| No misleading claims (informational only) | ✅ |
| Microphone / Photo / Documents usage descriptions | ✅ In Info.plist |

---

## 7. Before you click “Submit for Review”

1. **Test the build** on a real device (subscription flow, restore, backend).
2. **Notes for reviewer** (optional): In App Store Connect → Version → **App Review Information**, you can add:
   - **Sign-in**: e.g. “Test with Sign in with Apple or email. Demo account: …” if you have one.
   - **Subscription**: “Premium is available as an auto-renewable subscription. Use Sandbox account to test.”
3. **Backend live**: Ensure Railway (or your backend) is running and the app uses the correct production URL so reviewer can use the app.
4. **Content rights**: You have rights to all text and assets (no copied content from others).
5. **No placeholder content**: Descriptions, screenshots, and in-app content are final, not “Lorem” or “Test”.

---

## 8. Common rejection reasons (avoid these)

- **Missing Privacy Policy URL** or broken link → set a working URL in App Information.
- **Missing or unclear subscription terms** → you already show them in the subscription screen.
- **Restore Purchases hard to find** → you have it on Upgrade and post-signup.
- **Financial app without disclaimer** → you show the disclaimer.
- **Export compliance** → ITSAppUsesNonExemptEncryption = NO and answer the question in Connect.
- **Crashes or broken features** → test the submitted build and a clean install.
- **Login required with no test account** → provide a demo account in App Review Information if the app requires login.

---

## Quick pre-submit list

- [ ] Privacy Policy URL set and working
- [ ] Terms of Use (EULA) URL set and working
- [ ] Screenshots added for required sizes
- [ ] Description, keywords, support URL filled
- [ ] Subscription product(s) configured and approved
- [ ] App Privacy questionnaire completed
- [ ] Build selected; version number correct
- [ ] Test account / notes for reviewer if needed
- [ ] Backend (Railway) up and reachable

After that, submit the version for review and wait for App Review (often 24–48 hours).
