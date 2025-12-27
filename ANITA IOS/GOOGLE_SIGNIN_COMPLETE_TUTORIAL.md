# Complete Google Sign-In Setup Tutorial for iOS

This is a **step-by-step guide** with exact instructions to set up Google Sign-In for your ANITA iOS app. Follow each step carefully.

---

## Prerequisites

- A Google account
- Access to Google Cloud Console
- Xcode installed
- Your ANITA iOS project open

---

## Part 1: Create Google Cloud Project and OAuth Credentials

### Step 1.1: Access Google Cloud Console

1. Open your web browser
2. Go to: **https://console.cloud.google.com/**
3. Sign in with your Google account
4. If you see a project selector at the top, click it

### Step 1.2: Create or Select a Project

**Option A: Create a New Project**
1. Click the project dropdown at the top (next to "Google Cloud")
2. Click **"NEW PROJECT"** button
3. Enter project name: `ANITA Finance` (or any name you prefer)
4. Click **"CREATE"**
5. Wait for the project to be created (10-30 seconds)
6. Select the newly created project from the dropdown

**Option B: Use Existing Project**
1. Click the project dropdown
2. Select your existing project

### Step 1.3: Enable Google Sign-In API

1. In the left sidebar, click **"APIs & Services"** → **"Library"**
2. In the search box, type: `Google Sign-In API`
3. Click on **"Google Sign-In API"** from the results
4. Click the blue **"ENABLE"** button
5. Wait for it to enable (5-10 seconds)

**Alternative:** You can also enable "Google+ API" if Google Sign-In API is not available:
- Search for: `Google+ API`
- Click **"ENABLE"**

### Step 1.4: Configure OAuth Consent Screen

1. In the left sidebar, click **"APIs & Services"** → **"OAuth consent screen"**
2. You'll see a form. Fill it out:

   **User Type:**
   - Select **"External"** (unless you have a Google Workspace account)
   - Click **"CREATE"**

   **App Information:**
   - **App name:** `ANITA Finance Advisor`
   - **User support email:** Select your email from dropdown
   - **App logo:** (Optional - you can skip this)
   - **App domain:** Leave empty or add your domain if you have one
   - **Application home page:** Leave empty or add your website
   - **Authorized domains:** Leave empty for now
   - **Developer contact information:** Your email address
   - Click **"SAVE AND CONTINUE"**

   **Scopes:**
   - Click **"SAVE AND CONTINUE"** (default scopes are fine)

   **Test users (if External):**
   - Click **"+ ADD USERS"**
   - Add your Google account email
   - Click **"ADD"**
   - Click **"SAVE AND CONTINUE"**

   **Summary:**
   - Review the information
   - Click **"BACK TO DASHBOARD"**

### Step 1.5: Create iOS OAuth Client ID

1. In the left sidebar, click **"APIs & Services"** → **"Credentials"**
2. At the top, click **"+ CREATE CREDENTIALS"**
3. Select **"OAuth client ID"** from the dropdown
4. If prompted about OAuth consent screen, click **"CONFIGURE CONSENT SCREEN"** and complete Step 1.4 first

5. **Application type:** Select **"iOS"** (NOT Web application!)

6. **Name:** Enter `ANITA iOS App` (or any descriptive name)

7. **Bundle ID:** Enter exactly: `com.anita.app`
   - ⚠️ **CRITICAL:** This must match exactly with your Xcode project's bundle identifier
   - No spaces, no typos

8. Click **"CREATE"**

9. **IMPORTANT:** A popup will appear with your credentials:
   - **Client ID:** This is what you need! It looks like: `123456789-abc123def456.apps.googleusercontent.com`
   - **Copy this Client ID** - you'll need it in the next steps
   - You can also click **"DOWNLOAD JSON"** to save it
   - Click **"OK"**

10. **Save your Client ID somewhere safe** (Notes app, text file, etc.)

### Step 1.6: Create Web OAuth Client ID (for Supabase)

You need a **separate** Web Client ID for Supabase to exchange tokens.

1. Still in **"Credentials"** page
2. Click **"+ CREATE CREDENTIALS"** again
3. Select **"OAuth client ID"**

4. **Application type:** Select **"Web application"** (this time it's Web!)

5. **Name:** Enter `ANITA Web (Supabase)`

6. **Authorized redirect URIs:** Click **"+ ADD URI"** and add:
   ```
   https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback
   ```
   - ⚠️ **CRITICAL:** This exact URL is required for Supabase
   - Copy it exactly, including `https://`

7. Click **"CREATE"**

8. **IMPORTANT:** Another popup will appear:
   - **Client ID:** Copy this (different from iOS Client ID)
   - **Client Secret:** Copy this too (you'll need it for Supabase)
   - Click **"OK"**

9. **Save both Web Client ID and Client Secret** somewhere safe

---

## Part 2: Configure Supabase Dashboard

### Step 2.1: Access Supabase Dashboard

1. Go to: **https://app.supabase.com/**
2. Sign in to your account
3. Select your project: **ANITA** (or the project name you're using)

### Step 2.2: Enable Google Provider

1. In the left sidebar, click **"Authentication"**
2. Click **"Providers"** tab
3. Scroll down and find **"Google"**
4. Click on the **"Google"** card/row

5. **Enable Google:**
   - Toggle the switch to **ON** (enabled)

6. **Enter Credentials:**
   - **Client ID (for OAuth):** Paste your **Web Client ID** (from Step 1.6)
   - **Client Secret (for OAuth):** Paste your **Web Client Secret** (from Step 1.6)
   - ⚠️ **Important:** Use the Web Client ID, NOT the iOS Client ID!

7. **Redirect URLs:**
   - You should see: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
   - This should already be there, but verify it matches your Supabase project URL

8. Click **"SAVE"** at the bottom
9. Wait for confirmation message

---

## Part 3: Configure iOS App - Config.swift

### Step 3.1: Open Config.swift in Xcode

1. Open Xcode
2. Open your ANITA iOS project
3. In the Project Navigator (left sidebar), find: **ANITA** → **Utils** → **Config.swift**
4. Click on **Config.swift** to open it

### Step 3.2: Add iOS Client ID

1. Scroll down to find the `googleClientID` property (around line 51-57)
2. You'll see something like:
   ```swift
   return ""
   ```

3. **Replace the empty string** with your iOS Client ID:
   ```swift
   return "123456789-abc123def456.apps.googleusercontent.com"
   ```
   - Replace `123456789-abc123def456.apps.googleusercontent.com` with your **actual iOS Client ID** from Step 1.5
   - Keep the quotes
   - Make sure there are no spaces

4. **Example of what it should look like:**
   ```swift
   static let googleClientID: String = {
       if let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !clientId.isEmpty {
           return clientId.trimmingCharacters(in: .whitespacesAndNewlines)
       }
       // Add your iOS OAuth Client ID here
       // Example: "123456789-abc123def456.apps.googleusercontent.com"
       return "YOUR_ACTUAL_IOS_CLIENT_ID_HERE.apps.googleusercontent.com"
   }()
   ```

5. **Save the file:** Press `Cmd + S`

---

## Part 4: Configure Info.plist - Add Reversed Client ID

### Step 4.1: Understand Reversed Client ID

Your iOS Client ID looks like: `123456789-abc123def456.apps.googleusercontent.com`

The reversed version is: `com.googleusercontent.apps.123456789-abc123def456`

**How to reverse it:**
- Take the domain parts (everything after the numbers and dash)
- Reverse the order: `com.googleusercontent.apps` stays the same, then add the prefix

**Example:**
- Original: `987654321-xyz789.apps.googleusercontent.com`
- Reversed: `com.googleusercontent.apps.987654321-xyz789`

### Step 4.2: Open Info.plist

1. In Xcode Project Navigator, find: **ANITA** → **Info.plist**
2. Click on **Info.plist**
3. You can view it in two ways:
   - **Property List view** (default, shows keys and values)
   - **Source Code view** (shows XML)

### Step 4.3: Add Reversed Client ID (Property List View)

1. If you're in Property List view:
   - Find the row: **"URL types"** or **"CFBundleURLTypes"**
   - Expand it by clicking the arrow
   - You'll see **"Item 0"** or similar
   - Expand **"Item 0"**
   - Find **"URL Schemes"** or **"CFBundleURLSchemes"**
   - Expand it
   - You should see **"Item 0"** with value `anita`

2. **Add new URL scheme:**
   - Click the **"+"** button next to the last item in URL Schemes
   - A new row will appear: **"Item 1"** (or next number)
   - Double-click the value field
   - Enter your reversed Client ID: `com.googleusercontent.apps.123456789-abc123def456`
   - Replace with your actual reversed Client ID
   - Press Enter

### Step 4.4: Add Reversed Client ID (Source Code View)

**Alternative method if you prefer XML:**

1. Right-click on **Info.plist** in Project Navigator
2. Select **"Open As"** → **"Source Code"**

2. Find the section that looks like:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>anita</string>
           </array>
           <key>CFBundleURLName</key>
           <string>com.anita.app</string>
           </dict>
   </array>
   ```

3. **Add a new line** inside the `<array>` tag, after `<string>anita</string>`:
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
   - Replace `123456789-abc123def456` with your actual Client ID prefix

4. **Save:** Press `Cmd + S`

### Step 4.5: Verify Info.plist

Your final `CFBundleURLSchemes` array should have:
1. `anita` (your app's URL scheme)
2. `com.googleusercontent.apps.YOUR_CLIENT_ID_PREFIX` (reversed Google Client ID)

---

## Part 5: Verify Bundle Identifier

### Step 5.1: Check Bundle ID in Xcode

1. In Xcode, click on your project name in the Project Navigator (top item)
2. Select the **"ANITA"** target (under TARGETS)
3. Click the **"Signing & Capabilities"** tab
4. Find **"Bundle Identifier"**
5. It should be: `com.anita.app`
6. **If it's different:**
   - Either change it to `com.anita.app` in Xcode
   - OR go back to Google Cloud Console and create a new iOS OAuth client with the correct Bundle ID

---

## Part 6: Test the Setup

### Step 6.1: Clean Build

1. In Xcode menu: **Product** → **Clean Build Folder** (or press `Cmd + Shift + K`)
2. Wait for it to complete

### Step 6.2: Build the Project

1. Press `Cmd + B` to build
2. Check for any errors
3. If you see errors about Google Sign-In, make sure the SDK is installed:
   - Go to **File** → **Add Package Dependencies**
   - If GoogleSignIn-iOS is not listed, add it:
     - URL: `https://github.com/google/GoogleSignIn-iOS`
     - Version: 7.0.0 or later

### Step 6.3: Run on Simulator or Device

1. Select a simulator or connected device
2. Press `Cmd + R` to run
3. Wait for the app to launch

### Step 6.4: Test Google Sign-In

1. Navigate to the login screen
2. Tap the **"Log in with Google"** button
3. **Expected behavior:**
   - A Google Sign-In popup should appear
   - You can select your Google account
   - After signing in, you should be authenticated

### Step 6.5: Check Console Logs

1. In Xcode, open the **Console** (bottom panel)
2. Look for messages like:
   - `[Supabase] ✓ Google Sign-In configuration validated` ✅ (Good!)
   - `[Supabase] ⚠️ WARNING: Google Sign-In not configured!` ❌ (Check Config.swift)

---

## Troubleshooting

### Error: "Google Client ID not configured"

**Problem:** The Client ID is empty or not set correctly in Config.swift

**Solution:**
1. Open `Config.swift`
2. Verify the `googleClientID` property has your iOS Client ID
3. Make sure it's in quotes: `"your-client-id.apps.googleusercontent.com"`
4. Rebuild the app

### Error: "Invalid Google Client ID format"

**Problem:** The Client ID format is wrong

**Solution:**
1. Check that your Client ID looks like: `123456789-abc123.apps.googleusercontent.com`
2. Make sure there are no extra spaces
3. Make sure you're using the **iOS Client ID**, not the Web Client ID

### Error: "No ID token received from Google"

**Problem:** Bundle ID mismatch or Info.plist URL scheme missing

**Solution:**
1. Verify Bundle ID in Xcode matches `com.anita.app`
2. Verify the reversed Client ID is in Info.plist
3. Clean and rebuild

### Error: "Authentication failed" when exchanging with Supabase

**Problem:** Supabase Google provider not configured correctly

**Solution:**
1. Go to Supabase Dashboard → Authentication → Providers → Google
2. Verify it's enabled
3. Verify you're using the **Web Client ID and Secret** (not iOS)
4. Check that the redirect URL matches your Supabase project URL

### Google Sign-In popup doesn't appear

**Problem:** SDK not installed or configuration issue

**Solution:**
1. Verify GoogleSignIn-iOS package is installed:
   - Project Navigator → Package Dependencies
   - Should see "GoogleSignIn-iOS"
2. If missing, add it via File → Add Package Dependencies
3. Clean and rebuild

### "redirect_uri_mismatch" error

**Problem:** Redirect URI not added to Web OAuth client

**Solution:**
1. Go to Google Cloud Console → Credentials
2. Click on your **Web OAuth client** (not iOS)
3. Add this exact URL to Authorized redirect URIs:
   ```
   https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback
   ```
4. Click Save
5. Wait 1-2 minutes for changes to propagate

---

## Quick Checklist

Before testing, verify:

- [ ] iOS OAuth Client created in Google Cloud Console
- [ ] Bundle ID in Google Cloud Console matches `com.anita.app`
- [ ] iOS Client ID copied and saved
- [ ] Web OAuth Client created in Google Cloud Console
- [ ] Web Client ID and Secret copied and saved
- [ ] Supabase Google provider enabled
- [ ] Web Client ID and Secret added to Supabase
- [ ] iOS Client ID added to `Config.swift`
- [ ] Reversed Client ID added to `Info.plist`
- [ ] Bundle Identifier in Xcode is `com.anita.app`
- [ ] GoogleSignIn-iOS SDK installed in Xcode
- [ ] Project builds without errors
- [ ] App runs successfully

---

## Summary of What You Need

**From Google Cloud Console:**
1. **iOS Client ID:** `123456789-abc123.apps.googleusercontent.com` → Goes in `Config.swift`
2. **Web Client ID:** `987654321-xyz789.apps.googleusercontent.com` → Goes in Supabase Dashboard
3. **Web Client Secret:** `GOCSPX-xxxxx` → Goes in Supabase Dashboard

**In Your iOS App:**
1. **Config.swift:** Add iOS Client ID
2. **Info.plist:** Add reversed iOS Client ID as URL scheme

**In Supabase:**
1. Enable Google provider
2. Add Web Client ID and Secret

---

## Need More Help?

If you're still having issues:

1. Check the console logs in Xcode for specific error messages
2. Verify each step was completed correctly
3. Make sure you're using the correct Client IDs in the right places:
   - iOS Client ID → Config.swift
   - Web Client ID + Secret → Supabase Dashboard

4. Double-check:
   - No typos in Bundle ID
   - No extra spaces in Client IDs
   - Info.plist URL scheme is correctly reversed
   - Supabase redirect URL matches exactly

---

**That's it! Follow these steps carefully and Google Sign-In will work! 🎉**

