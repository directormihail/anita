# Get Google Client ID from Webapp and Configure for iOS

## Understanding the Setup

Your webapp uses **Supabase OAuth**, which means:
- The **Web Client ID** is configured in Supabase Dashboard
- For iOS, you need a **separate iOS OAuth Client ID** (same Google Cloud project, different client type)

## Step 1: Get Web Client ID from Supabase Dashboard

1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project: **ANITA** (kezregiqfxlrvaxytdet)
3. Navigate to: **Authentication** → **Providers**
4. Find **Google** provider
5. You'll see the **Client ID** (this is your Web Client ID)
6. **Copy this Client ID** - it looks like: `123456789-abc123def456.apps.googleusercontent.com`

This tells us which Google Cloud project you're using!

## Step 2: Find Your Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to **APIs & Services** → **Credentials**
3. Look for the Client ID you copied from Supabase
4. Note which **Project** it belongs to (shown at the top of the page)

## Step 3: Create iOS OAuth Client ID

In the **same Google Cloud project**:

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. If prompted, configure OAuth consent screen first (if not already done)
4. Select **iOS** as application type (NOT Web!)
5. **Name:** "ANITA iOS" (or your preferred name)
6. **Bundle ID:** `com.anita.app` (must match exactly!)
7. Click **CREATE**
8. **Copy the iOS Client ID** - format: `123456789-xyz789abc123.apps.googleusercontent.com`

⚠️ **Important:** This is a DIFFERENT Client ID from the Web one!

## Step 4: Configure iOS App

### 4a. Add to Config.swift

Open `ANITA/Utils/Config.swift` and replace line 57:

```swift
return "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
```

Replace with your actual iOS Client ID.

### 4b. Calculate Reversed Client ID

Use the test script:
```bash
cd "ANITA IOS"
swift test-google-config.swift "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
```

This will show you:
- ✅ If the format is valid
- ✅ The reversed Client ID for Info.plist
- ✅ Exact setup instructions

### 4c. Add to Info.plist

Open `ANITA/Info.plist` in Xcode and add the reversed Client ID to `CFBundleURLSchemes`:

```xml
<string>com.googleusercontent.apps.YOUR_CLIENT_ID_PREFIX</string>
```

(The test script will show you the exact value)

## Step 5: Test

1. Build and run the app in Xcode
2. Check console output - it will show configuration status
3. Try Google Sign-In - it should work!

## Quick Reference

| Item | Where | Type |
|------|-------|------|
| Web Client ID | Supabase Dashboard | For webapp |
| iOS Client ID | Config.swift | For iOS app |
| Reversed iOS Client ID | Info.plist | For iOS URL scheme |

## Troubleshooting

### "I can't find the Client ID in Supabase"
- Make sure Google provider is enabled in Supabase Dashboard
- Go to: Authentication → Providers → Google
- The Client ID should be visible there

### "I only see Web Client ID, not iOS"
- That's correct! You need to create a separate iOS Client ID
- Use the same Google Cloud project
- Create a new OAuth client with type "iOS"

### "Bundle ID doesn't match"
- Your iOS app Bundle ID must be: `com.anita.app`
- Check in Xcode: Project → Target → Signing & Capabilities → Bundle Identifier
- If different, either change it in Xcode OR create a new iOS OAuth client with the correct Bundle ID

## Summary

1. ✅ Get Web Client ID from Supabase Dashboard
2. ✅ Find Google Cloud project
3. ✅ Create iOS OAuth Client ID in same project
4. ✅ Add iOS Client ID to Config.swift
5. ✅ Add reversed Client ID to Info.plist
6. ✅ Test!

---

**Both Client IDs work together:**
- **Web Client ID** → Supabase Dashboard (for webapp OAuth)
- **iOS Client ID** → Config.swift (for iOS native sign-in)

Both exchange tokens with Supabase, so they work with the same user accounts!

