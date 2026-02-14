# Testing: Profile name does not flow between accounts

## What was fixed
Profile name and onboarding data are now stored **per account** (keyed by `userId`). Switching accounts no longer shows the previous account’s name.

## Manual test steps

1. **Account A**
   - Sign in (or use anonymous).
   - Complete onboarding with name **"Alice"** (or set name in Settings).
   - Open Settings and confirm the displayed name is **Alice**.

2. **Sign out**
   - Sign out from the app.

3. **Account B**
   - Sign in with a **different** account (different email or create new).
   - Open Settings.
   - **Expected:** Name is **empty** or the name set for this account (e.g. **"Bob"**), **not** "Alice".

4. **Switch back to Account A**
   - Sign out, then sign in again as Account A.
   - Open Settings.
   - **Expected:** Name is **Alice** again (not Bob).

5. **Same device, two accounts**
   - Repeat with two different accounts on the same device; each account should keep its own name.

## What is keyed per account
- Profile display name
- Onboarding survey (including onboarding name)
- Currency and number format
- Onboarding completed / synced flags

## Technical note
Keys in UserDefaults now include the user id, e.g. `anita_profile_name_<userId>`, so each account has its own namespace.
