# Google Sign-In Quick Start for iOS

## Current Status

✅ **Code is properly set up and ready**
- Google Sign-In SDK is installed (v7.1.0)
- All code is in place
- Error handling is improved
- Validation is added

❌ **Missing: Google Client ID**
- You need to add your iOS OAuth Client ID to `Config.swift`

## Quick Fix (3 Steps)

### Step 1: Create iOS OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** > **Credentials**
3. Click **Create Credentials** > **OAuth client ID**
4. Select **iOS** as application type
5. Bundle ID: `com.anita.app`
6. Copy the **Client ID** (format: `123456789-abc123def456.apps.googleusercontent.com`)

### Step 2: Add Client ID to Config.swift

Open `ANITA/Utils/Config.swift` and replace the empty string on line 57:

```swift
return "YOUR_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
```

### Step 3: Add Reversed Client ID to Info.plist

1. Open `ANITA/Info.plist` in Xcode
2. Find `CFBundleURLSchemes` array
3. Add your reversed client ID:

**Example:**
- Client ID: `123456789-abc123def456.apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.123456789-abc123def456`

Add this line in the `CFBundleURLSchemes` array:
```xml
<string>com.googleusercontent.apps.123456789-abc123def456</string>
```

## Test

1. Build and run the app
2. Tap "Log in with Google"
3. It should work! 🎉

## Need Help?

See `GOOGLE_SIGNIN_IOS_SETUP.md` for detailed instructions.

## Important Notes

- You need **TWO** OAuth clients:
  1. **iOS Client ID** → Goes in `Config.swift` (for native sign-in)
  2. **Web Client ID + Secret** → Goes in Supabase Dashboard (for token exchange)

- Make sure Google OAuth is enabled in Supabase Dashboard:
  - Go to Supabase Dashboard > Authentication > Providers > Google
  - Enable it and add your Web Client ID and Secret

