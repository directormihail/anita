# Google Sign-In Setup - Step-by-Step Visual Guide

Follow these steps **in order**. Each step has exact instructions.

---

## 📋 PRE-SETUP CHECKLIST

Before starting, make sure you have:
- [ ] Google account (Gmail account works)
- [ ] Xcode installed and ANITA project open
- [ ] Supabase account access
- [ ] 15-20 minutes of time

---

## PART 1: GOOGLE CLOUD CONSOLE SETUP

### ✅ Step 1: Open Google Cloud Console

1. Open browser
2. Go to: **https://console.cloud.google.com/**
3. Sign in with Google account
4. You'll see the dashboard

**What you'll see:** A page with "Google Cloud" at the top, navigation menu on the left

---

### ✅ Step 2: Create or Select Project

**Look for:** Project dropdown at the top (next to "Google Cloud" text)

**If you see a project name:**
- Click the dropdown
- If you see "ANITA" or similar project, select it
- Skip to Step 3

**If you see "Select a project" or want to create new:**
1. Click the project dropdown
2. Click **"NEW PROJECT"** button (top right of popup)
3. **Project name:** Type `ANITA Finance`
4. Click **"CREATE"**
5. Wait 10-30 seconds
6. Click **"SELECT PROJECT"** when it appears

**What you'll see:** Project name changes to your selected project

---

### ✅ Step 3: Enable Google Sign-In API

**Navigation path:**
1. Left sidebar → Click **"APIs & Services"**
2. Click **"Library"** (if not already selected)

**Search:**
1. In the search box at top, type: `Google Sign-In API`
2. Press Enter or click search icon
3. Click on **"Google Sign-In API"** from results

**Enable:**
1. Click the blue **"ENABLE"** button
2. Wait 5-10 seconds
3. You'll see "API enabled" message

**Alternative if not found:**
- Search for: `Google+ API`
- Enable that instead

**What you'll see:** "API enabled" confirmation

---

### ✅ Step 4: Configure OAuth Consent Screen

**Navigation:**
1. Left sidebar → **"APIs & Services"**
2. Click **"OAuth consent screen"**

**If you see "Create OAuth consent screen" button:**
1. Click it
2. **User Type:** Select **"External"** (unless you have Google Workspace)
3. Click **"CREATE"**

**Fill the form:**

**App Information:**
- **App name:** `ANITA Finance Advisor`
- **User support email:** Select your email from dropdown
- **App logo:** (Skip - click "Continue" or leave empty)
- **Application home page:** (Leave empty)
- **Authorized domains:** (Leave empty)
- **Developer contact information:** Your email address
- Click **"SAVE AND CONTINUE"** button

**Scopes:**
- Click **"SAVE AND CONTINUE"** (default scopes are fine)

**Test users (if External):**
- Click **"+ ADD USERS"** button
- Type your Gmail address
- Click **"ADD"**
- Click **"SAVE AND CONTINUE"**

**Summary:**
- Review the info
- Click **"BACK TO DASHBOARD"**

**What you'll see:** OAuth consent screen configured message

---

### ✅ Step 5: Create iOS OAuth Client

**Navigation:**
1. Left sidebar → **"APIs & Services"**
2. Click **"Credentials"**

**Create credential:**
1. Click **"+ CREATE CREDENTIALS"** button (top of page)
2. Select **"OAuth client ID"** from dropdown

**If you see consent screen warning:**
- Go back and complete Step 4 first

**Fill the form:**

**Application type:**
- Select **"iOS"** ⚠️ **NOT "Web application"!**

**Name:**
- Type: `ANITA iOS App`

**Bundle ID:**
- Type exactly: `com.anita.app`
- ⚠️ **CRITICAL:** Must match exactly, no spaces, no typos

**Create:**
1. Click **"CREATE"** button
2. A popup will appear

**Copy Client ID:**
1. In the popup, you'll see **"Your Client ID"**
2. It looks like: `123456789-abc123def456.apps.googleusercontent.com`
3. **Click the copy icon** next to it (or select and copy)
4. **Paste it somewhere safe** (Notes app, text file)
5. Click **"OK"**

**What you'll see:** Popup with Client ID, then it closes. Client appears in credentials list.

**✅ SAVE THIS:** Your iOS Client ID (you'll need it for Config.swift)

---

### ✅ Step 6: Create Web OAuth Client (for Supabase)

**Still on Credentials page:**
1. Click **"+ CREATE CREDENTIALS"** again
2. Select **"OAuth client ID"**

**Fill the form:**

**Application type:**
- Select **"Web application"** ⚠️ **This time it's Web!**

**Name:**
- Type: `ANITA Web (Supabase)`

**Authorized redirect URIs:**
1. Click **"+ ADD URI"** button
2. Type exactly: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
3. ⚠️ **CRITICAL:** Copy this URL exactly, including `https://`
4. Press Enter or click outside

**Create:**
1. Click **"CREATE"** button
2. Another popup appears

**Copy credentials:**
1. **Client ID:** Click copy icon (or select and copy)
2. **Client Secret:** Click "Show" then copy (or select and copy)
3. **Paste both somewhere safe**
4. Click **"OK"**

**What you'll see:** Popup with Web Client ID and Secret

**✅ SAVE THESE:**
- Web Client ID (for Supabase Dashboard)
- Web Client Secret (for Supabase Dashboard)

---

## PART 2: SUPABASE DASHBOARD SETUP

### ✅ Step 7: Open Supabase Dashboard

1. Open browser (new tab or window)
2. Go to: **https://app.supabase.com/**
3. Sign in
4. Select project: **ANITA** (or your project name)

**What you'll see:** Supabase project dashboard

---

### ✅ Step 8: Enable Google Provider

**Navigation:**
1. Left sidebar → Click **"Authentication"**
2. Click **"Providers"** tab (at top)

**Find Google:**
1. Scroll down the list
2. Find **"Google"** card/row
3. Click on it (or the toggle switch)

**Configure:**
1. **Toggle switch:** Turn it **ON** (should turn blue/green)

2. **Client ID (for OAuth):**
   - Paste your **Web Client ID** from Step 6
   - ⚠️ Use Web Client ID, NOT iOS Client ID!

3. **Client Secret (for OAuth):**
   - Paste your **Web Client Secret** from Step 6

4. **Redirect URLs:**
   - Should show: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
   - Verify it matches your Supabase project URL

**Save:**
1. Scroll to bottom
2. Click **"SAVE"** button
3. Wait for confirmation

**What you'll see:** "Settings saved" or similar confirmation message

---

## PART 3: XCODE CONFIGURATION

### ✅ Step 9: Open Config.swift

1. Open Xcode
2. Open ANITA project
3. In left sidebar (Project Navigator), find:
   - **ANITA** (folder)
   - **Utils** (subfolder)
   - **Config.swift** (file)
4. Click **Config.swift** to open it

**What you'll see:** Swift code file with configuration

---

### ✅ Step 10: Add iOS Client ID to Config.swift

**Find the code:**
- Scroll to around line 51-57
- Look for:
```swift
return ""
```

**Replace it:**
1. Delete the empty quotes: `""`
2. Type your iOS Client ID in quotes:
```swift
return "123456789-abc123def456.apps.googleusercontent.com"
```
- Replace with your **actual iOS Client ID** from Step 5
- Keep the quotes
- No spaces

**Example of final code:**
```swift
static let googleClientID: String = {
    if let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !clientId.isEmpty {
        return clientId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // Add your iOS OAuth Client ID here
    // Example: "123456789-abc123def456.apps.googleusercontent.com"
    return "YOUR_ACTUAL_CLIENT_ID_HERE.apps.googleusercontent.com"
}()
```

**Save:**
- Press `Cmd + S` (or File → Save)

**What you'll see:** File saved, no errors

---

### ✅ Step 11: Calculate Reversed Client ID

**Your iOS Client ID looks like:**
```
123456789-abc123def456.apps.googleusercontent.com
```

**To reverse it:**
1. Take everything after the dash: `abc123def456.apps.googleusercontent.com`
2. Reverse the domain parts: `com.googleusercontent.apps.abc123def456`
3. Add the prefix back: `com.googleusercontent.apps.123456789-abc123def456`

**Formula:**
- Original: `[NUMBER]-[RANDOM].apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.[NUMBER]-[RANDOM]`

**Example:**
- Original: `987654321-xyz789.apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.987654321-xyz789`

**✅ Write down your reversed Client ID**

---

### ✅ Step 12: Add Reversed Client ID to Info.plist

**Open Info.plist:**
1. In Xcode Project Navigator
2. Find: **ANITA** → **Info.plist**
3. Click it

**View options:**
- **Property List view** (default - shows keys/values in table)
- **Source Code view** (shows XML)

**Method A: Property List View**

1. Find row: **"URL types"** or **"CFBundleURLTypes"**
2. Click arrow to expand
3. Expand **"Item 0"**
4. Find **"URL Schemes"** or **"CFBundleURLSchemes"**
5. Expand it
6. You'll see **"Item 0"** with value `anita`

**Add new item:**
1. Click **"+"** button (next to URL Schemes items)
2. New row appears: **"Item 1"**
3. Double-click the value field
4. Type your reversed Client ID: `com.googleusercontent.apps.123456789-abc123def456`
5. Replace with your actual reversed Client ID
6. Press Enter

**Method B: Source Code View**

1. Right-click **Info.plist** in Project Navigator
2. Select **"Open As"** → **"Source Code"**

2. Find this section:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>anita</string>
</array>
```

3. Add new line after `<string>anita</string>`:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>anita</string>
    <string>com.googleusercontent.apps.123456789-abc123def456</string>
</array>
```
- Replace with your actual reversed Client ID

4. Save: `Cmd + S`

**What you'll see:** Info.plist updated with new URL scheme

---

### ✅ Step 13: Verify Bundle Identifier

**Check in Xcode:**
1. Click project name (top of Project Navigator)
2. Select **"ANITA"** target (under TARGETS)
3. Click **"Signing & Capabilities"** tab
4. Find **"Bundle Identifier"**

**Should be:** `com.anita.app`

**If different:**
- Either change it to `com.anita.app` in Xcode
- OR go back to Google Cloud Console and create new iOS OAuth client with correct Bundle ID

**What you'll see:** Bundle Identifier field showing `com.anita.app`

---

## PART 4: TESTING

### ✅ Step 14: Clean and Build

**Clean:**
1. Xcode menu: **Product** → **Clean Build Folder**
   - Or press: `Cmd + Shift + K`
2. Wait for completion

**Build:**
1. Press `Cmd + B` (or Product → Build)
2. Check for errors in bottom panel

**If errors about Google Sign-In:**
- Go to: **File** → **Add Package Dependencies**
- Add: `https://github.com/google/GoogleSignIn-iOS`
- Version: 7.0.0 or later
- Add to target: ANITA

**What you'll see:** "Build Succeeded" message

---

### ✅ Step 15: Run App

1. Select simulator or device (top toolbar)
2. Press `Cmd + R` (or click Play button)
3. Wait for app to launch

**What you'll see:** App launches on simulator/device

---

### ✅ Step 16: Test Google Sign-In

1. Navigate to login screen in app
2. Tap **"Log in with Google"** button
3. **Expected:** Google Sign-In popup appears
4. Select your Google account
5. **Expected:** You're signed in and authenticated

**Check console:**
1. In Xcode, open Console (bottom panel)
2. Look for: `[Supabase] ✓ Google Sign-In configuration validated` ✅

**What you'll see:** Google Sign-In popup, then successful authentication

---

## 🎉 SUCCESS!

If you see the Google Sign-In popup and can sign in, you're done!

---

## ❌ TROUBLESHOOTING

### Error: "Google Client ID not configured"

**Check:**
1. Open `Config.swift`
2. Verify `googleClientID` has your iOS Client ID (not empty)
3. Make sure it's in quotes
4. Rebuild app

---

### Error: "Invalid Google Client ID format"

**Check:**
1. Client ID should look like: `123456789-abc123.apps.googleusercontent.com`
2. No extra spaces
3. Using iOS Client ID (not Web Client ID)

---

### Error: "No ID token received"

**Check:**
1. Bundle ID in Xcode matches `com.anita.app`
2. Bundle ID in Google Cloud Console matches `com.anita.app`
3. Reversed Client ID is in Info.plist
4. Clean and rebuild

---

### Error: "Authentication failed" with Supabase

**Check:**
1. Supabase Dashboard → Authentication → Providers → Google
2. Verify it's enabled (toggle ON)
3. Verify Web Client ID is entered (not iOS Client ID)
4. Verify Web Client Secret is entered
5. Click Save

---

### Google Sign-In popup doesn't appear

**Check:**
1. GoogleSignIn-iOS package installed?
   - Project Navigator → Package Dependencies
   - Should see "GoogleSignIn-iOS"
2. If missing: File → Add Package Dependencies → Add it
3. Clean and rebuild

---

## 📝 QUICK REFERENCE

**What goes where:**

| Item | Where to Put It |
|------|----------------|
| iOS Client ID | `Config.swift` (line ~57) |
| Reversed iOS Client ID | `Info.plist` (CFBundleURLSchemes) |
| Web Client ID | Supabase Dashboard |
| Web Client Secret | Supabase Dashboard |

**Client IDs:**
- iOS: `123456789-abc123.apps.googleusercontent.com` → Config.swift
- Web: `987654321-xyz789.apps.googleusercontent.com` → Supabase

**Reversed iOS Client ID:**
- Original: `123456789-abc123.apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.123456789-abc123`
- Goes in: Info.plist

---

**Follow these steps exactly and Google Sign-In will work!** 🚀

