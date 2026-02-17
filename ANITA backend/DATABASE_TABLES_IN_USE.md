# Database tables in use – do not delete

These tables are referenced by the **ANITA backend**, **ANITA iOS app**, or **ANITA webapp**.  
Before dropping any table in Supabase, check this list. **Only drop tables that are not listed here.**

## Tables used by the app

| Table (or view) | Used by | Purpose |
|-----------------|--------|---------|
| **anita_data** | Backend, Webapp | Messages and transactions (main data) |
| **conversations** | Backend, Webapp | Chat conversations |
| **profiles** | Backend, Webapp | User profile (name, currency, etc.) |
| **targets** | Backend, Webapp | Financial goals / budget targets |
| **assets** | Backend, Webapp | Assets tracking |
| **user_xp_events** | Backend, Webapp | XP event log |
| **user_xp_stats** | Backend, Webapp | XP level/points per user |
| **xp_rules** | Backend, Webapp | XP rule definitions |
| **xp_levels** | Backend, Webapp | Level thresholds |
| **user_subscriptions** | Backend, Webapp | Subscription status (Stripe / Apple) |
| **message_feedback** | Backend | Like/dislike on chat messages |
| **user_support_requests** | Backend | Support form (Settings → Support) |
| **user_feedback** | Backend, Webapp | Feedback form (Settings → Feedback) |
| **target_transactions** | Webapp | Links targets to transactions |
| **monthly_financial_overview_with_available_cash** | Webapp | View for analytics |
| **files** | Webapp | File references (if used) |
| **transactions** | Webapp (some services) | May be view or table – check migrations |
| **category_reclassification_log** | Webapp | Category reclassification history |
| **merchant_rules** | Webapp | Category rules by merchant |
| **category_corrections** | Webapp | Category overrides |

## Tables/views you can consider removing

Only remove something if:

1. It is **not** in the list above, and  
2. You have confirmed in Supabase that it exists and is not used by any migration or trigger.

Examples of things that might be safe to drop (verify in your project):

- Old duplicate or renamed tables from earlier migrations
- Tables created by experiments or one-off scripts that are no longer referenced in the repo

## How to fix “Failed to submit support request”

1. Open **Supabase** → your project → **SQL Editor**.
2. Open **`ANITA backend/create_support_feedback_tables.sql`** from this repo.
3. Copy its contents into the SQL Editor and run it.
4. Retry Support in the app.

This creates the **user_support_requests** table. The **user_feedback** table is created by the webapp migration `20241220000016_create_user_feedback.sql`; if you never ran the webapp migrations, create that table from the webapp migrations or run the webapp Supabase migration set.
