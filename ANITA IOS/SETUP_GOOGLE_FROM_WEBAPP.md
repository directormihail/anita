# Quick Setup: Get Google Key from Webapp for iOS

## The Situation

- ✅ Your **webapp** has Google Sign-In working (configured in Supabase)
- ❌ Your **iOS app** needs the Google Client ID configured

## Important: You Need TWO Different Client IDs!

1. **Web Client ID** - Already in Supabase (for webapp) ✅
2. **iOS Client ID** - Need to create this (for iOS app) ❌

Both use the **same Google Cloud project**, but are different OAuth clients.

## Quick Steps

### Step 1: Get Your Web Client ID (to find the project)

1. Go to: https://app.supabase.com/
2. Project: **ANITA**
3. Go to: **Authentication** → **Providers** → **Google**
4. **Copy the Client ID** shown there
5. This is your Web Client ID (format: `123456789-abc.apps.googleusercontent.com`)

### Step 2: Create iOS Client ID

1. Go to: https://console.cloud.google.com/
2. Find the project that contains your Web Client ID
3. Go to: **APIs & Services** → **Credentials**
4. Click: **+ CREATE CREDENTIALS** → **OAuth client ID**
5. Select: **iOS** (NOT Web!)
6. Bundle ID: `com.anita.app`
7. **Copy the iOS Client ID**

### Step 3: Configure iOS App

#### Option A: Use Test Script (Recommended)

```bash
cd "ANITA IOS"
swift test-google-config.swift "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
```

This will:
- ✅ Validate the format
- ✅ Show you the reversed Client ID
- ✅ Give you exact setup instructions

#### Option B: Manual Setup

1. **Config.swift** (line ~57):
   ```swift
   return "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
   ```

2. **Info.plist** - Add reversed Client ID to `CFBundleURLSchemes`:
   ```xml
   <string>com.googleusercontent.apps.YOUR_CLIENT_ID_PREFIX</string>
   ```

### Step 4: Test

Build and run - the app will automatically validate the configuration!

## Need Help?

- See `GET_GOOGLE_CLIENT_ID_FROM_WEBAPP.md` for detailed instructions
- See `GOOGLE_SIGNIN_IOS_SETUP.md` for complete setup guide

