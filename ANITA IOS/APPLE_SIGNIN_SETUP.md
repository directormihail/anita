# Apple Sign-In Setup Guide

Apple Sign-In has been implemented in the ANITA iOS app. Follow these steps to enable it:

## Prerequisites

1. **Apple Developer Account** - You need an active Apple Developer account
2. **App ID with Sign in with Apple capability** - Your app's Bundle ID must have Sign in with Apple enabled

## Step 1: Enable Sign in with Apple in Xcode

1. Open your project in Xcode: `ANITA.xcodeproj`
2. Select your app target: **ANITA**
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **Sign in with Apple**
6. This will automatically enable the capability for your App ID

## Step 2: Configure Apple Sign-In in Supabase Dashboard

### Option A: Automated Configuration (Recommended)

1. Get your Supabase access token:
   - Go to [Supabase Account Tokens](https://supabase.com/dashboard/account/tokens)
   - Create a new access token
   - Copy it

2. Run the configuration script:
   ```bash
   cd "ANITA IOS"
   export SUPABASE_ACCESS_TOKEN='your-access-token-here'
   ./configure-apple-signin.sh
   ```

### Option B: Manual Configuration

1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project: **ANITA** (kezregiqfxlrvaxytdet)
3. Navigate to **Authentication** → **Providers**
4. Find **Apple** provider
5. **Enable** the Apple provider (toggle ON)

### For Native iOS Apps (Recommended)

1. In the **Client IDs** field, add your App ID (Bundle Identifier)
   - **Your Bundle ID:** `com.anita.app`
   - This is the same as your `PRODUCT_BUNDLE_IDENTIFIER` in Xcode
2. **You do NOT need to configure OAuth settings** for native iOS apps
3. Click **Save**

### Optional: For Web/Cross-Platform Support

If you also want to support Apple Sign-In on web or other platforms, you'll need:

1. **Team ID** - Found in Apple Developer Console (upper right)
2. **Services ID** - Create one in [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list/serviceId)
3. **Key** - Create a signing key in [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list)
4. Generate a secret key using the [Supabase Apple Secret Generator](https://supabase.com/docs/guides/auth/social-login/auth-apple)
5. **Callback URL** - Your Supabase callback URL: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`

Then configure:
- **OAuth client ID**: Your Services ID
- **OAuth client secret**: The generated secret key (JWT format)
- **Callback URL in Apple Developer Console**: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`

## Step 3: Test Apple Sign-In

1. Build and run the app on a **physical device** (Apple Sign-In doesn't work in the simulator)
2. Go to **Settings** → **Sign In / Sign Up**
3. You should see the **Sign in with Apple** button
4. Tap it and complete the authentication flow
5. You should be signed in successfully! 🎉

## Troubleshooting

### "Sign in with Apple" button doesn't appear

- Make sure you're testing on a **physical device** (not simulator)
- Verify the **Sign in with Apple** capability is added in Xcode
- Check that your App ID has Sign in with Apple enabled in [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list/bundleId)

### Authentication fails with Supabase

- Verify your App ID (Bundle Identifier) is added to **Client IDs** in Supabase Dashboard
- Check the Xcode console for error messages starting with `[Supabase]`
- Ensure the Apple provider is **enabled** in Supabase Dashboard

### "No identity token" error

- This usually means the Apple Sign-In flow was cancelled or failed
- Try again and make sure to complete the authentication flow
- Check that you're signed in to iCloud on the device

## Important Notes

- **Native iOS apps** only need the App ID (Bundle Identifier) in the Client IDs field
- **OAuth configuration** is only needed for web/cross-platform support
- Apple Sign-In **requires a physical device** - it won't work in the iOS Simulator
- The first time a user signs in, Apple may ask for permission to share name/email
- Subsequent sign-ins will be faster as the credential is cached

## Configuration Summary

| Item | Where | Value |
|------|-------|-------|
| Sign in with Apple Capability | Xcode → Signing & Capabilities | Enabled ✅ |
| App ID (Bundle Identifier) | Supabase Dashboard → Apple Provider → Client IDs | `com.anita.app` |
| Apple Provider | Supabase Dashboard → Authentication → Providers | Enabled ✅ |
| Supabase Project | Dashboard | ANITA (kezregiqfxlrvaxytdet) |
| Callback URL (for web OAuth only) | Apple Developer Console → Services ID | `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback` |

## Important Notes

- **Native iOS apps** only need the App ID (Bundle Identifier) in the Client IDs field
- **OAuth configuration** (secret key, callback URL) is only needed for web/cross-platform support
- **Callback URL** (`https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`) is only used for web-based OAuth flows, not native iOS
- Apple Sign-In **requires a physical device** - it won't work in the iOS Simulator

---

**Once configured, Apple Sign-In will work seamlessly in your app!** 🚀

