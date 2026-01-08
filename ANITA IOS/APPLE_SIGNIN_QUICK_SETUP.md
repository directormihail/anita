# 🍎 Apple Sign-In Quick Setup

Quick setup guide for Apple Sign-In in ANITA iOS app.

## Prerequisites

- ✅ Apple Developer Account
- ✅ Xcode project open

## Quick Setup (3 Steps)

### Step 1: Enable Capability in Xcode

1. Open `ANITA.xcodeproj` in Xcode
2. Select **ANITA** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**

### Step 2: Configure Supabase

**Option A: Automated (Recommended)**
```bash
cd "ANITA IOS"
export SUPABASE_ACCESS_TOKEN='your-token-from-dashboard'
./configure-apple-signin.sh
```

**Option B: Manual**
1. Go to: https://app.supabase.com/project/kezregiqfxlrvaxytdet/auth/providers
2. Find **Apple** provider → Enable it
3. In **Client IDs** field, add: `com.anita.app`
4. Click **Save**

### Step 3: Test

1. Build and run on **physical device** (not simulator)
2. Go to **Settings** → **Sign In / Sign Up**
3. Tap **Sign in with Apple** button
4. Complete authentication

## Configuration Details

- **Bundle ID:** `com.anita.app`
- **Supabase Project:** ANITA (kezregiqfxlrvaxytdet)
- **Provider:** Apple (native iOS)

## Troubleshooting

**Button doesn't appear?**
- Must test on physical device (simulator doesn't support Apple Sign-In)
- Verify capability is added in Xcode

**Authentication fails?**
- Check Bundle ID is in Supabase Client IDs: `com.anita.app`
- Verify Apple provider is enabled in Supabase Dashboard
- Check Xcode console for `[Supabase]` error messages

**Need access token?**
- Go to: https://supabase.com/dashboard/account/tokens
- Create new token and export it

---

**That's it! Apple Sign-In is now configured.** 🚀

