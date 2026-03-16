# How transaction categories are defined and managed

## Summary

Categories are set in two places that work together:

1. **Supabase trigger** – On INSERT/UPDATE of `bank_transactions`, if `category` is null or empty, a trigger runs and sets `category` from `description` + `merchant_name` + `amount_cents` using the same rules as the backend (e.g. "Rocket Rides" → Rideshare & Taxi, "Rocket Delivery" → Dining Out, income → Freelance & Side Income or Salary).
2. **Backend categorizer** – When you pull-to-refresh or when the app loads transactions and some are uncategorized, the backend runs `categorizeUncategorizedBankTransactions`. **AI is the source of truth** (same pattern as chat paywall): the AI reasons about each transaction (millions of possible merchants) and picks one category from the canonical list. No fixed keyword rules for the primary path. If `OPENAI_API_KEY` is set, the AI’s answer is normalized to a canonical category and stored. **Rule-based is used only when the AI is unavailable** (no key or request failure). So the backend can improve on the trigger’s default.

Result: new rows get a category immediately from the trigger; the backend can refine it later. No row should stay null or "Other".

---

# Where transaction category is defined (and why it can be wrong)

## 1. Where the category comes from

- **Stored in:** `bank_transactions.category` (Supabase).
- **Read by:** `GET /api/v1/bank-transactions` returns each transaction with its `category`; the iOS app shows that value in the list.
- **Written by:** Only one place sets `category`: **`categorizeUncategorizedBankTransactions`** (in `src/utils/categorizeBankTransactions.ts`). It:
  - Finds rows where `category` is null, empty, `"other"`, `"uncategorized"`, or `"unclassified"`.
  - For each, calls **`categorizeTransactionWithAI`** (AI + rule-based fallback).
  - Updates `bank_transactions.category` (and `updated_at`) in the DB.

So **the category you see is whatever was last written by that categorization step**. Nothing else updates `category`.

## 2. When does categorization run?

Categorization runs only when **`categorizeUncategorizedBankTransactions`** is called:

| When | Where it's called |
|------|--------------------|
| User pulls to refresh on Finance tab | iOS calls `POST/GET /api/v1/bank-transactions/refresh` → `refresh-bank-transactions.ts` syncs from Stripe, then calls `categorizeUncategorizedBankTransactions`. |
| Stripe webhook (account created/refreshed) | `stripe-webhook.ts` syncs transactions, then calls `categorizeUncategorizedBankTransactions`. |
| **Loading the transaction list** | **`get-bank-transactions.ts`**: if the response includes any uncategorized row, it **triggers** `categorizeUncategorizedBankTransactions` in the **background** (after sending the response). The **current** response still has the old/missing category; the **next** load (or next refresh) will see the new category. |

So:

- If the user **never** pulls to refresh and only opens the Finance tab, categories are updated only when:
  - The backend has run the **background** job (because the previous load had uncategorized rows), and
  - The user loads the list again (or refreshes).
- If **refresh** is used, categories are updated in the same flow (sync + categorize), and the following `loadData()` shows the new categories.

## 3. Why categories can be wrong or missing

1. **Categorization hasn’t run yet**  
   New or previously uncategorized rows stay null/other until one of the triggers above runs. **Fix:** Pull to refresh, or open the list again after the background job has run.

2. **Only “uncategorized” rows are re-run**  
   Rows that already have a value (e.g. `"Shopping"`, `"Other"`) are **not** re-categorized. So an old wrong category stays until we change the logic to re-categorize more cases. **Fix:** Logic in `categorizeBankTransactions.ts` (`needsCategorization`) decides which rows are processed.

3. **Stripe only sends `description`**  
   We don’t get `merchant_name` or `raw_category` from Stripe; only `description` (e.g. "Rocket Rides", "Rocket Delivery"). Categorization is based on that plus amount. **Fix:** All logic (AI and rules) uses `description` (and optional `merchant_name` if we ever get it).

4. **AI not used (no key or failure)**  
   If `OPENAI_API_KEY` is missing or the AI call fails, we fall back to **rule-based** categorization (`categoryDetector.ts`). It’s good for known names (e.g. Rocket Delivery → Dining Out, Rocket Rides → Rideshare & Taxi) but can be wrong for unknown names. **Fix:** Set `OPENAI_API_KEY`; ensure the model and prompt in `transactionCategoryAI.ts` are what you want.

5. **Wrong or generic AI answer**  
   The model can still return a generic or wrong category. We normalize with `toCanonicalCategory` and avoid "Other" by using fallbacks (e.g. Shopping / Freelance). **Fix:** Adjust the prompt and examples in `transactionCategoryAI.ts`; extend rules in `categoryDetector.ts`.

## 4. Flow summary

```
Stripe (only description, amount, date)
    → sync (refresh or webhook) → bank_transactions rows (category = null)
    → categorizeUncategorizedBankTransactions
        → for each uncategorized row: categorizeTransactionWithAI (AI or rules)
        → UPDATE bank_transactions SET category = ? WHERE id = ?

App loads list: GET /api/v1/bank-transactions
    → SELECT ... FROM bank_transactions (existing category)
    → if any row uncategorized → trigger categorizeUncategorizedBankTransactions in background
    → return current rows (next load sees updated category)
```

So **the problem with defining category** is: **category is only set inside `categorizeUncategorizedBankTransactions`**, and only when that function is run (refresh, webhook, or background after a get that saw uncategorized rows). If that hasn’t run for a row, or the AI/rules gave a bad result, you see the wrong or missing category until we run categorization again and/or improve the logic.
