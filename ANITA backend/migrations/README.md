# ANITA backend migrations

Run these in **Supabase → SQL Editor** (one time per project) so that progress and transactions persist after app reload.

## 1. `add_anita_data_transaction_date.sql` — **run this first**

**Why:** Transfers to/from goals (and any transaction) are stored with a user-intended date. Without this column, the app filters by `created_at`, which some databases overwrite, so transactions can disappear after reload.

**What it does:** Adds a nullable `transaction_date` column to `anita_data` and an index.

**Steps:**
1. Open Supabase → your project → **SQL Editor**.
2. Copy the contents of `add_anita_data_transaction_date.sql`.
3. Paste and run.

After this, new transactions will be stored with `transaction_date` and will show again when you reload the app. Goal progress (saved amount) is stored in the `targets` table and persists as long as the update-target API succeeds.
