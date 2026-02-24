# ANITA app verification report

Summary of checks run on the codebase and backend. **The iOS app itself was not run** (no simulator/device available in this environment). Use this as a checklist to confirm everything works on your side.

---

## 1. Backend

| Check | Result |
|-------|--------|
| **TypeScript** | `npm run type-check` in `ANITA backend` — **passed** |
| **Health endpoint** | `GET https://anita-production-bb9a.up.railway.app/health` — **200 OK** (`status: "ok"`) |
| **Routes registered** | All v1 API routes are wired in `index.ts` (chat, subscription, support, feedback, delete-account, etc.) |

---

## 2. Support & Feedback (Settings → Support / Feedback)

**Flow:**
- **Support:** Settings → Support → user fills subject + message → app calls `POST /api/v1/support` → backend inserts into **`user_support_requests`** (Supabase).
- **Feedback:** Settings → Feedback → user fills message + rating → app calls `POST /api/v1/feedback` → backend inserts into **`user_feedback`** (Supabase).

**Backend:** Routes exist and are registered. They require:
- Env: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (backend uses service role, so RLS is bypassed for these inserts).
- Tables in Supabase: **`user_support_requests`** and **`user_feedback`**.

**If Support or Feedback fail in the app:** Create the tables in Supabase:

1. Open **Supabase** → your project → **SQL Editor**.
2. Run the script **`ANITA backend/create_support_feedback_tables.sql`** (it now creates both `user_support_requests` and `user_feedback`).
3. Retry Support and Feedback in the app.

**How to confirm data is stored:**
- Supabase → **Table Editor** → open **`user_support_requests`** or **`user_feedback`**.
- Send a test message from the app (Support or Feedback), then refresh the table — a new row should appear.

---

## 3. Backend tables used by the app

From `ANITA backend/DATABASE_TABLES_IN_USE.md` and the codebase, the backend uses at least:

| Table | Purpose |
|-------|---------|
| `user_support_requests` | Support form (Settings → Support) |
| `user_feedback` | Feedback form (Settings → Feedback) |
| `user_subscriptions` | Subscription status (Apple IAP / Stripe) |
| `message_feedback` | Like/dislike on chat messages |
| `profiles` | User profile |
| `anita_data` / `conversations` / messages | Chat and transactions |
| `targets`, `assets`, `user_xp_*`, etc. | Finance and XP |

Ensure these exist in your Supabase project (run the relevant migrations or SQL scripts if needed).

---

## 4. iOS app services (code-level)

| Service | Role |
|---------|------|
| **NetworkService** | All API calls to backend (support, feedback, subscription, chat, delete-account, etc.). Uses `Config.backendURL` (Railway production URL). |
| **SupabaseService** | Auth, profile, direct Supabase access where used. |
| **StoreKitService** | In-app purchase; calls `POST /api/v1/verify-ios-subscription` and `GET /api/v1/subscription`. |
| **SubscriptionManager** | Single source of truth for premium status (backend + StoreKit fallback). |

Support and Feedback use **NetworkService** only (backend API); they do not write to Supabase directly from the app.

---

## 5. What you should do to “run and check” on your side

1. **Backend:** Already verified (type-check + health). If you use a different URL, test `GET <your-backend>/health`.
2. **Support:** In the app, open Settings → Support, send a test request. Then in Supabase → Table Editor → **`user_support_requests`**, confirm a new row.
3. **Feedback:** Same for Settings → Feedback; confirm a new row in **`user_feedback`**.
4. **Subscription:** You already confirmed Sandbox purchase and “test” subscription; no extra check needed for this report.
5. **Other features:** Manually test chat, finance, and delete-account flows; backend routes for these are registered and type-checked.

---

## 6. Change made in this pass

- **`ANITA backend/create_support_feedback_tables.sql`** now also creates **`user_feedback`** (with `user_id`, `message`, `rating`, `created_at`), so one script sets up both Support and Feedback tables if you don’t have the webapp migrations.

---

**Bottom line:** Backend is up and type-correct; Support and Feedback will work once the Supabase tables exist (run the SQL script if needed). To confirm “info comes into the database” for Support, send a test from the app and check **`user_support_requests`** in Supabase.
