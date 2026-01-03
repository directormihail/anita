# Google Sign-In Quick Setup & Test

## Current Status

Run this to check your current configuration:
```bash
cd "ANITA IOS"
swift test-google-config.swift
```

Or if you have a Client ID to test:
```bash
swift test-google-config.swift "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com"
```

## Quick Setup (3 Steps)

### Step 1: Get Your iOS OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** → **Credentials**
3. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
4. Select **iOS** as application type
5. Bundle ID: `com.anita.app` (must match exactly!)
6. Copy the **Client ID** (format: `123456789-abc123def456.apps.googleusercontent.com`)

### Step 2: Add to Config.swift

Open `ANITA/Utils/Config.swift` and replace line 57:

```swift
return "YOUR_CLIENT_ID_HERE.apps.googleusercontent.com"
```

Replace `YOUR_CLIENT_ID_HERE.apps.googleusercontent.com` with your actual Client ID.

### Step 3: Add Reversed Client ID to Info.plist

1. Calculate reversed Client ID:
   - If your Client ID is: `123456789-abc123def456.apps.googleusercontent.com`
   - Reversed is: `com.googleusercontent.apps.123456789-abc123def456`

2. Or use the test script:
   ```bash
   swift test-google-config.swift "YOUR_CLIENT_ID"
   ```
   It will show you the reversed Client ID.

3. Open `ANITA/Info.plist` in Xcode
4. Find `CFBundleURLSchemes` array
5. Add the reversed Client ID as a new string:
   ```xml
   <string>com.googleusercontent.apps.123456789-abc123def456</string>
   ```

## Test Your Configuration

### Option 1: Test Script
```bash
cd "ANITA IOS"
swift test-google-config.swift "YOUR_CLIENT_ID"
```

### Option 2: Build and Run
1. Open the project in Xcode
2. Build and run (Cmd+R)
3. Check the console output - it will show configuration status
4. Try Google Sign-In - it should work!

### Option 3: Check in Code
The app automatically tests configuration on startup. Check Xcode console for:
- ✅ Success messages if configured correctly
- ❌ Error messages with instructions if not configured

## Troubleshooting

### "Google Client ID not configured"
- Make sure you added the Client ID to `Config.swift` line 57
- Make sure it's not empty: `return ""` should have your Client ID

### "Invalid Google Client ID format"
- Make sure you're using the **iOS Client ID**, not Web Client ID
- Format should be: `123456789-abc123def456.apps.googleusercontent.com`
- No extra spaces or quotes

### "No ID token received from Google"
- Check that Bundle ID in Xcode matches: `com.anita.app`
- Verify the reversed Client ID is in `Info.plist`
- Make sure you created an **iOS** OAuth client, not Web

### Sign-in works but Supabase fails
- You need **TWO** OAuth clients:
  1. **iOS Client ID** → Goes in `Config.swift` (for native sign-in)
  2. **Web Client ID + Secret** → Goes in Supabase Dashboard (for token exchange)
- Configure Google provider in Supabase Dashboard with Web Client ID and Secret

## Need More Help?

See `GOOGLE_SIGNIN_IOS_SETUP.md` for detailed step-by-step instructions.

