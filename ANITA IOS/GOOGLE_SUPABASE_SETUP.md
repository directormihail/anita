# Connect Google Sign-In with Supabase

The app already uses the Google Sign-In SDK and exchanges the Google ID token with Supabase. To make it work end-to-end, complete these steps.

---

## Fix: "Unacceptable audience in id_token"

**Problem:** Supabase rejects the Google ID token because the token’s **audience** (`aud`) is your **iOS client ID** (e.g. `730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com`), while the Google provider in Supabase is only configured with the **Web** client ID. GoTrue only accepts tokens whose audience is in its allowed list.

**Fix:** In Supabase you must allow **both** the Web and iOS client IDs.

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Authentication** → **Providers** → **Google**.
2. In **Client ID**, enter **multiple client IDs separated by commas**, **Web first**, then iOS:
   ```
   <YOUR-WEB-CLIENT-ID>,730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com
   ```
   Example: `123456789-abc.apps.googleusercontent.com,730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com`
3. **Client Secret**: keep your **Web** application client secret (unchanged).
4. Click **Save**.

After this, "Log in with Google" from the iOS app should work.

---

## Fix: "Nonces mismatch" or "Passed nonce and nonce in id_token should either both exist or not"

**Problem:** Google’s iOS SDK puts a nonce in the id_token, but GoTrue’s nonce check expects a different format, so you see "Nonces mismatch" or "Passed nonce and nonce in id_token should either both exist or not."

**Fix:** Turn on **Skip nonce checks** for Google in Supabase (required for native iOS Google Sign-In).

1. Open the Google provider page in Supabase:
   - **Direct link (replace with your project ref if different):**  
     https://supabase.com/dashboard/project/kezregiqfxlrvaxytdet/auth/providers  
   - Or: [Supabase Dashboard](https://supabase.com/dashboard) → select your project → **Authentication** (left sidebar) → **Providers** → click **Google**.
2. On the Google provider page, find **Skip nonce check** (or **Skip nonce checks**) and turn it **ON**.
3. Click **Save** at the bottom.
4. Try "Log in with Google" in the iOS app again.

Nonce validation is still covered by PKCE and short-lived tokens for most apps.

**Quick open:** From the ANITA IOS folder run:
```bash
./open-supabase-google-provider.sh
```
Then on the Providers page click **Google**, turn **Skip nonce check** ON, and **Save**. Test "Log in with Google" in the app 2–3 times to confirm.

---

## 1. Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials**.
2. Create or use an existing **OAuth 2.0 Client ID**:
   - **iOS**: Application type **iOS**, Bundle ID `com.anita.app`. Use this Client ID in the app (already in `Config.swift`).
   - **Web (for Supabase)**: Create another OAuth client with type **Web application**. You will use this client’s **Client ID** and **Client secret** in Supabase.
3. If you use the Web client, add **Authorized redirect URIs**:
   - `https://<YOUR-PROJECT-REF>.supabase.co/auth/v1/callback`  
   Replace `<YOUR-PROJECT-REF>` with your Supabase project ref (e.g. `kezregiqfxlrvaxytdet`).

## 2. Supabase Dashboard

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Go to **Authentication** → **Providers** → **Google**.
3. Turn **Google** **ON**.
4. Fill in:
   - **Client ID**: **Web client ID first, then a comma, then your iOS client ID** (e.g. `730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9.apps.googleusercontent.com`). Supabase accepts multiple IDs separated by commas; the Web one must be first.
   - **Client Secret**: Web application Client secret from Google Cloud.
5. Click **Save**.

## 3. iOS app (already done)

- **Config.swift**: `googleClientID` is set to your **iOS** OAuth Client ID.
- **Info.plist**: URL scheme is the reversed iOS Client ID (e.g. `com.googleusercontent.apps.730448941091-...`).
- **SupabaseService**: Sends `provider=google`, `id_token`, `access_token`, and `client_id` (iOS client ID) to Supabase as JSON.

## 4. Test

1. Build and run on a device or simulator (with a Google account available).
2. Tap **Log in with Google**.
3. After signing in with Google, the app should receive a session from Supabase and log you in.

If sign-in fails, check the Xcode console for `[Supabase]` logs and any error message from Supabase (e.g. “Google provider disabled” or “Invalid client”).
