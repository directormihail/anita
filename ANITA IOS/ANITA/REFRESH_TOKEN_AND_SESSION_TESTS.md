# Refresh Token & Session Persistence – Test Guide

After the fix for “logout when quitting the app,” use this checklist to verify session and refresh token behavior across different scenarios.

---

## What Was Fixed

1. **Refresh token persistence**  
   Refresh token is now stored in both Keychain and UserDefaults so it survives app quit/restart and works even if Keychain is temporarily unavailable.

2. **Load on service init**  
   `SupabaseService` loads saved tokens in `init()`, so tokens are restored as soon as the service is used, regardless of initialization order.

3. **Restore before auth check**  
   On launch, `checkAuthStatus()` calls `tryRestoreSessionFromRefreshToken()` before `getCurrentUser()`, so an expired access token is refreshed first and the user stays logged in.

4. **Migration/fallback**  
   If only UserDefaults has tokens (e.g. older installs), both access and refresh are restored and written back to Keychain.

---

## Test Scenarios

### 1. Normal quit and relaunch (primary case)

- **Steps**
  1. Log in (email or Google).
  2. Use the app (e.g. open Chat, Finance, Settings).
  3. Quit the app (swipe up from app switcher and swipe away, or Home then force quit).
  4. Relaunch the app.
- **Expected**  
  User remains logged in; main tabs (Chat, Finance, Settings) are visible without showing login again.

---

### 2. Background and return (no quit)

- **Steps**
  1. Log in.
  2. Send app to background (Home or switch to another app) for 1–2 minutes.
  3. Return to the app.
- **Expected**  
  User remains logged in; no logout.

---

### 3. Long background (access token may expire)

- **Steps**
  1. Log in.
  2. Send app to background for 30+ minutes (or until access token would normally expire).
  3. Return to the app and navigate (e.g. open Finance or Chat).
- **Expected**  
  Session is refreshed automatically; user stays logged in and data loads. No unexpected logout.

---

### 4. Cold start with expired access token

- **Steps**
  1. Log in.
  2. Quit the app.
  3. Wait long enough for access token to expire (e.g. 1 hour), or change device date/time to simulate expiry.
  4. Launch the app.
- **Expected**  
  App uses refresh token to get a new access token; user is still logged in and sees main content.

---

### 5. Sign out clears session

- **Steps**
  1. Log in.
  2. Open Settings and sign out.
  3. Quit the app and relaunch.
- **Expected**  
  Welcome/login screen is shown. No automatic re-login.

---

### 6. Only refresh token in storage (edge case)

- Simulates “access token missing but refresh token present” (e.g. after a partial clear or migration).
- **Steps**  
  (Requires dev/debug: clear only access token from Keychain/UserDefaults and keep refresh token, then launch app.)
- **Expected**  
  App should call refresh and obtain a new access token; user ends up logged in.

---

### 7. No network on launch, then network

- **Steps**
  1. Log in, then quit the app.
  2. Turn off Wi‑Fi and cellular (or use airplane mode).
  3. Launch the app.
  4. After app shows (may show loading or error), turn network back on.
  5. Pull to refresh or navigate.
- **Expected**  
  When network returns, session can refresh and user stays or becomes logged in; no permanent logout solely due to temporary offline.

---

### 8. Multiple rapid launches

- **Steps**
  1. Log in.
  2. Quit and relaunch the app 3–4 times in a row.
- **Expected**  
  User remains logged in on each launch; no flicker to login then back.

---

### 9. Google Sign-In then quit

- **Steps**
  1. Log in with Google.
  2. Quit the app fully and relaunch.
- **Expected**  
  User is still logged in with the same account; no need to sign in with Google again.

---

### 10. Email sign-in then quit

- **Steps**
  1. Log in with email/password.
  2. Quit the app fully and relaunch.
- **Expected**  
  User is still logged in; no email login screen.

---

## Quick Checklist

| # | Scenario                         | Pass / Fail |
|---|----------------------------------|-------------|
| 1 | Quit app → relaunch → still in   |             |
| 2 | Background → return → still in   |             |
| 3 | Long background → return → still in |         |
| 4 | Cold start, expired access → still in |      |
| 5 | Sign out → quit → relaunch → login screen |  |
| 6 | Only refresh token present → still in (if applicable) | |
| 7 | Offline launch → online → session works |   |
| 8 | Multiple rapid relaunches → still in   |     |
| 9 | Google sign-in → quit → relaunch → still in |  |
| 10| Email sign-in → quit → relaunch → still in |  |

---

## If a Test Fails

- Check Xcode console for `[Supabase]` and `[UserManager]` logs (e.g. “Session refreshed successfully” or “Session refresh failed”).
- Confirm Supabase URL and anon key in `Config.swift`.
- Confirm no code path calls `signOut()` or `setAccessToken(nil)` on startup or when going to background.
