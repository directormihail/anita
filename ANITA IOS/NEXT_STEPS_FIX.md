# Next Steps: Fix the Web Client ID Error

## Current Situation

❌ **Problem:** You're using a **Web Client ID** but need an **iOS Client ID**

The Client ID `730448941091-31qv7cl53k401e14pnrecjem6mdk2qu9.apps.googleusercontent.com` is configured as a Web application, but iOS apps need an iOS OAuth Client ID.

## Step-by-Step Fix

### Step 1: Go to Google Cloud Console

1. Open: https://console.cloud.google.com/
2. Make sure you're in the **same project** that has your Web Client ID
   - Look for project with Client ID ending in `...31qv7cl53k401e14pnrecjem6mdk2qu9`

### Step 2: Create iOS OAuth Client ID

1. In the left sidebar, click: **APIs & Services** → **Credentials**
2. At the top, click: **+ CREATE CREDENTIALS** → **OAuth client ID**
3. If prompted about OAuth consent screen, make sure it's configured (it should be if your Web Client ID works)

4. **Application type:** Select **iOS** ⚠️ (NOT Web application!)
5. **Name:** Enter "ANITA iOS" (or any name you prefer)
6. **Bundle ID:** Enter exactly: `com.anita.app` ⚠️ (must match your app's bundle identifier)
7. Click **CREATE**

8. **IMPORTANT:** A popup will appear with your credentials:
   - **Client ID:** This is what you need! Copy it
   - It will look like: `730448941091-XXXXXXXXXXXX.apps.googleusercontent.com`
   - ⚠️ This will be DIFFERENT from your Web Client ID
   - Click **OK**

### Step 3: Update iOS App Configuration

Once you have the iOS Client ID, you have two options:

#### Option A: Use the Setup Script (Easiest)

```bash
cd "ANITA IOS"
./configure-google-signin.sh
```

Enter your **iOS Client ID** when prompted. The script will:
- ✅ Validate the format
- ✅ Update Config.swift automatically
- ✅ Update Info.plist automatically
- ✅ Create backups

#### Option B: Tell Me the Client ID

Just send me the iOS Client ID and I'll update everything for you!

### Step 4: Verify

After updating, run:

```bash
swift test-google-setup.swift "YOUR_IOS_CLIENT_ID"
```

Should show all ✅ green checks!

### Step 5: Test in Xcode

1. Build and run the app
2. Try Google Sign-In
3. It should work! 🎉

## Quick Checklist

- [ ] Opened Google Cloud Console
- [ ] Found the correct project (with Web Client ID)
- [ ] Created new iOS OAuth Client ID
- [ ] Selected "iOS" as application type (NOT Web!)
- [ ] Set Bundle ID: `com.anita.app`
- [ ] Copied the iOS Client ID
- [ ] Updated Config.swift (or ran setup script)
- [ ] Updated Info.plist (or ran setup script)
- [ ] Tested in Xcode

## Important Reminders

1. **You need TWO different Client IDs:**
   - Web Client ID → Already in Supabase (for webapp) ✅
   - iOS Client ID → Need to create this (for iOS app) ❌

2. **Both are in the same Google Cloud project** but are different OAuth clients

3. **The Bundle ID must match exactly:** `com.anita.app`

4. **The iOS Client ID will be different** from your Web Client ID (even though they're in the same project)

## Need Help?

If you get stuck:
1. Make sure you're creating an **iOS** OAuth client (not Web)
2. Make sure Bundle ID is exactly: `com.anita.app`
3. Copy the Client ID immediately after creating it
4. Send me the iOS Client ID and I'll configure everything!

---

**Once you have the iOS Client ID, send it to me and I'll update everything!** 🚀

