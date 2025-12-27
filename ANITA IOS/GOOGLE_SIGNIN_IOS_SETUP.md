# Google Sign-In Setup for iOS

This guide will help you enable Google Sign-In for your ANITA iOS app.

## Overview

The iOS app uses native Google Sign-In SDK, which requires:
1. An **iOS OAuth client ID** (different from Web client ID)
2. The client ID configured in `Config.swift`
3. The bundle ID registered in Google Cloud Console

## Step-by-Step Instructions

### Step 1: Create iOS OAuth Client in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Go to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. If prompted, configure the OAuth consent screen first:
   - User Type: **External** (for testing) or **Internal** (for Google Workspace)
   - Fill in the required information
   - Add your email as a test user if using External type
6. Create the iOS OAuth client:
   - Application type: **iOS** (NOT Web application)
   - Name: "ANITA iOS" (or your preferred name)
   - Bundle ID: `com.anita.app` (must match your app's bundle identifier)
7. Click **Create**
8. **Copy the Client ID** - you'll need this for `Config.swift`

### Step 2: Configure Config.swift

1. Open `ANITA/Utils/Config.swift`
2. Find the `googleClientID` property (around line 42)
3. Replace the empty string with your iOS Client ID:

```swift
static let googleClientID: String = {
    if let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] {
        return clientId
    }
    // Add your iOS OAuth Client ID here (from Google Cloud Console)
    return "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
}()
```

**Important:** 
- Use the **iOS Client ID**, not the Web Client ID
- The format should be: `123456789-abc123def456.apps.googleusercontent.com`
- You can also set it via environment variable `GOOGLE_CLIENT_ID` for CI/CD

### Step 3: Verify Google Sign-In SDK is Installed

The app uses Google Sign-In SDK. Make sure it's added to your project:

1. In Xcode, go to **File** > **Add Package Dependencies**
2. Add: `https://github.com/google/GoogleSignIn-iOS`
3. Version: **7.0.0** or later
4. Add to target: **ANITA**

If you're not sure, check `ANITA.xcodeproj/project.pbxproj` for GoogleSignIn references.

### Step 4: Add Reversed Client ID to Info.plist

Google Sign-In requires a reversed client ID URL scheme. After getting your iOS Client ID:

1. Open `ANITA/Info.plist` in Xcode
2. Find the `CFBundleURLTypes` section
3. In the `CFBundleURLSchemes` array, add your reversed client ID:

**How to reverse your Client ID:**
- If your Client ID is: `123456789-abc123def456.apps.googleusercontent.com`
- The reversed Client ID is: `com.googleusercontent.apps.123456789-abc123def456`

**Example Info.plist entry:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>anita</string>
            <string>com.googleusercontent.apps.123456789-abc123def456</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.anita.app</string>
    </dict>
</array>
```

**Important:** Replace `123456789-abc123def456` with your actual client ID prefix (the part before `.apps.googleusercontent.com`)

### Step 5: Test Google Sign-In

1. Build and run the app in Xcode
2. Navigate to the login screen
3. Tap **"Log in with Google"**
4. You should see the Google Sign-In flow
5. After signing in, you should be authenticated

## Troubleshooting

### "Google Client ID not configured"
- **Fix:** Make sure you've added the iOS Client ID to `Config.swift`
- **Fix:** Verify the Client ID is not empty
- **Fix:** Check that you're using the iOS Client ID, not the Web Client ID

### "GoogleSignIn SDK not installed"
- **Fix:** Add the Google Sign-In SDK via Swift Package Manager
- **Fix:** Make sure it's added to the correct target (ANITA)
- **Fix:** Clean build folder (Cmd+Shift+K) and rebuild

### "No ID token received from Google"
- **Fix:** Verify your bundle ID matches exactly: `com.anita.app`
- **Fix:** Check that the iOS OAuth client is created with the correct bundle ID
- **Fix:** Make sure you're using the iOS Client ID, not Web Client ID

### "Authentication failed" when exchanging token with Supabase
- **Fix:** Ensure Google OAuth is enabled in your Supabase project
- **Fix:** Go to Supabase Dashboard > Authentication > Providers > Google
- **Fix:** Make sure the Web Client ID and Secret are configured in Supabase (different from iOS Client ID)
- **Fix:** The iOS app uses native sign-in, then exchanges the token with Supabase

### Sign-in works but Supabase authentication fails
- **Note:** You need BOTH:
  1. **iOS Client ID** - for the native Google Sign-In (in Config.swift)
  2. **Web Client ID + Secret** - for Supabase (in Supabase Dashboard)
- **Fix:** Configure Google OAuth in Supabase Dashboard:
  1. Go to [Supabase Dashboard](https://app.supabase.com/)
  2. Select your project
  3. Go to **Authentication** > **Providers**
  4. Enable **Google** provider
  5. Enter your **Web Client ID** and **Web Client Secret** (from Google Cloud Console)
  6. Click **Save**

## Important Notes

### Two Different Client IDs

You need **two different OAuth clients** in Google Cloud Console:

1. **iOS Client ID** (Application type: iOS)
   - Bundle ID: `com.anita.app`
   - Used in: `Config.swift` for native Google Sign-In
   - Format: `123456789-abc123def456.apps.googleusercontent.com`

2. **Web Client ID** (Application type: Web application)
   - Redirect URI: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
   - Used in: Supabase Dashboard for token exchange
   - Format: `123456789-xyz789abc123.apps.googleusercontent.com`

### Why Two Clients?

- The iOS app uses **native Google Sign-In** (requires iOS Client ID)
- After getting the ID token, it exchanges it with Supabase
- Supabase uses **OAuth flow** (requires Web Client ID + Secret)

## Security Notes

⚠️ **Important:**
1. **Never commit credentials to git** - Keep `Config.swift` in `.gitignore` if it contains secrets
2. **Use environment variables for CI/CD** - Set `GOOGLE_CLIENT_ID` in your build environment
3. **Different clients for dev/prod** - Consider separate OAuth clients for each environment

## Additional Resources

- [Google Sign-In for iOS Documentation](https://developers.google.com/identity/sign-in/ios)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Supabase OAuth Providers](https://supabase.com/docs/guides/auth/social-login/auth-google)

## Quick Checklist

- [ ] Created iOS OAuth client in Google Cloud Console
- [ ] Bundle ID matches: `com.anita.app`
- [ ] Copied iOS Client ID
- [ ] Added iOS Client ID to `Config.swift`
- [ ] Added reversed Client ID URL scheme to `Info.plist`
- [ ] Google Sign-In SDK installed in Xcode
- [ ] Created Web OAuth client for Supabase (if not already done)
- [ ] Configured Google provider in Supabase Dashboard
- [ ] Tested sign-in flow

---

**That's it! Your Google Sign-In should now work on iOS!** 🎉

