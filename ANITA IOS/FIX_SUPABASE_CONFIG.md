# Fix: Authentication Failed with Google Sign-In

## The Problem

Google Sign-In works (you see the Google consent screen), but the token exchange with Supabase fails with "Authentication failed".

## The Solution

You need to configure Supabase Dashboard with your Google OAuth credentials.

### Step 1: Get Your Web Client ID and Secret

1. Go to: https://console.cloud.google.com/
2. Find your project (same one with your iOS Client ID)
3. Go to: **APIs & Services** → **Credentials**
4. Find your **Web application** OAuth client ID
5. **Copy the Web Client ID** (format: `730448941091-31qv7cl53k401e14pnrecjem6mdk2qu9.apps.googleusercontent.com`)
6. **Copy the Web Client Secret** (you'll see it when you click on the Web client)

### Step 2: Configure Supabase Dashboard

1. Go to: https://app.supabase.com/
2. Select your project: **ANITA** (kezregiqfxlrvaxytdet)
3. Go to: **Authentication** → **Providers**
4. Find **Google** provider
5. **Enable** the Google provider (toggle ON)

6. **Configure the following:**
   - **OAuth client ID:** Enter your **Web Client ID** (not iOS!)
   - **OAuth client secret:** Enter your **Web Client Secret**
   - **Client IDs:** Enter both Client IDs separated by comma:
     ```
     730448941091-31qv7cl53k401e14pnrecjem6mdk2qu9,730448941091-ckogfhc8vjhgce8l2bf7l2mpnjaku0i9
     ```
     (Web Client ID, iOS Client ID)
   - **Skip nonce check:** Enable this option (toggle ON) ⚠️ Important for iOS!

7. Click **Save**

### Step 3: Test Again

1. Build and run the app
2. Try Google Sign-In
3. It should work now! 🎉

## Important Notes

### Why You Need Both Client IDs:

- **Web Client ID + Secret** → Supabase uses this to verify the ID token from Google
- **iOS Client ID** → Your app uses this for native Google Sign-In
- **Both in "Client IDs" field** → Supabase accepts tokens from either client

### Configuration Summary:

| Item | Where | Value |
|------|-------|-------|
| OAuth client ID | Supabase Dashboard | Web Client ID |
| OAuth client secret | Supabase Dashboard | Web Client Secret |
| Client IDs | Supabase Dashboard | Web, iOS (comma-separated) |
| Skip nonce check | Supabase Dashboard | Enabled ✅ |
| iOS Client ID | Config.swift | iOS Client ID ✅ |

## Troubleshooting

### Still getting "Authentication failed"?

1. **Check Supabase Dashboard:**
   - Google provider is enabled ✅
   - Web Client ID is correct ✅
   - Web Client Secret is correct ✅
   - Client IDs field has both IDs (comma-separated) ✅
   - Skip nonce check is enabled ✅

2. **Check Xcode console:**
   - Look for `[Supabase]` log messages
   - Check the error response from Supabase
   - The error message will tell you what's wrong

3. **Common issues:**
   - Wrong Web Client ID in Supabase → Use the Web one, not iOS
   - Missing Web Client Secret → Must be configured
   - Client IDs not added → Add both to "Client IDs" field
   - Skip nonce check disabled → Must be enabled for iOS

## Quick Checklist

- [ ] Got Web Client ID from Google Cloud Console
- [ ] Got Web Client Secret from Google Cloud Console
- [ ] Opened Supabase Dashboard → Authentication → Providers → Google
- [ ] Enabled Google provider
- [ ] Added Web Client ID to "OAuth client ID" field
- [ ] Added Web Client Secret to "OAuth client secret" field
- [ ] Added both Client IDs to "Client IDs" field (comma-separated)
- [ ] Enabled "Skip nonce check"
- [ ] Clicked Save
- [ ] Tested in app

---

**Once Supabase Dashboard is configured, authentication will work!** 🚀

