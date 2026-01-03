# Fix: "Custom scheme URIs are not allowed for 'WEB' client type"

## The Problem

The error means you're using a **Web Client ID** instead of an **iOS Client ID**.

The Client ID you provided (`730448941091-31qv7cl53k401e14pnrecjem6mdk2qu9.apps.googleusercontent.com`) is configured as a **Web application** type in Google Cloud Console, but iOS apps need an **iOS** type Client ID.

## The Solution

You need to create a **separate iOS OAuth Client ID** in the same Google Cloud project.

### Step 1: Go to Google Cloud Console

1. Go to: https://console.cloud.google.com/
2. Select the project that contains your Web Client ID (the one ending in `...31qv7cl53k401e14pnrecjem6mdk2qu9`)

### Step 2: Create iOS OAuth Client ID

1. Go to: **APIs & Services** → **Credentials**
2. Click: **+ CREATE CREDENTIALS** → **OAuth client ID**
3. **Application type:** Select **iOS** (NOT Web!)
4. **Name:** "ANITA iOS" (or any name you prefer)
5. **Bundle ID:** `com.anita.app` (must match exactly!)
6. Click **CREATE**
7. **Copy the NEW iOS Client ID** - it will look similar but be different from the Web one

### Step 3: Update Config.swift

Replace the current Client ID with the new iOS Client ID:

```swift
return "YOUR_NEW_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
```

### Step 4: Update Info.plist

Calculate the reversed Client ID and update Info.plist:

```xml
<string>com.googleusercontent.apps.YOUR_NEW_IOS_CLIENT_ID_PREFIX</string>
```

## Quick Fix Script

Once you have the iOS Client ID, run:

```bash
cd "ANITA IOS"
./configure-google-signin.sh
```

Enter your **iOS Client ID** (not the Web one).

## Important Notes

- **Web Client ID** → Used by webapp (stays in Supabase Dashboard) ✅
- **iOS Client ID** → Used by iOS app (goes in Config.swift) ❌ Need to create this!

Both are in the same Google Cloud project, but they're different OAuth clients.

## How to Tell Them Apart

- **Web Client ID**: Used for browser-based OAuth (what you have now)
- **iOS Client ID**: Used for native iOS app sign-in (what you need)

The error happens because iOS tries to use a custom URL scheme (like `com.googleusercontent.apps.xxx`) which is only allowed for iOS Client IDs, not Web Client IDs.

