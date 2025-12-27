# Google Sign-In Setup Checklist

Print this or keep it open while setting up. Check off each item as you complete it.

---

## 📱 GOOGLE CLOUD CONSOLE

### Project Setup
- [ ] Opened https://console.cloud.google.com/
- [ ] Created or selected project
- [ ] Enabled Google Sign-In API (or Google+ API)

### OAuth Consent Screen
- [ ] Configured OAuth consent screen
- [ ] Selected "External" user type
- [ ] Filled app name: "ANITA Finance Advisor"
- [ ] Added test user (your email)

### iOS OAuth Client
- [ ] Created OAuth client ID
- [ ] Selected "iOS" as application type
- [ ] Set Bundle ID: `com.anita.app`
- [ ] **COPIED iOS Client ID** → Save it!
- [ ] Client ID format: `123456789-abc.apps.googleusercontent.com`

### Web OAuth Client (for Supabase)
- [ ] Created second OAuth client ID
- [ ] Selected "Web application" as type
- [ ] Added redirect URI: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
- [ ] **COPIED Web Client ID** → Save it!
- [ ] **COPIED Web Client Secret** → Save it!

---

## 🔐 SUPABASE DASHBOARD

- [ ] Opened https://app.supabase.com/
- [ ] Selected ANITA project
- [ ] Went to Authentication → Providers
- [ ] Found Google provider
- [ ] Enabled Google (turned toggle ON)
- [ ] Pasted **Web Client ID** (not iOS!)
- [ ] Pasted **Web Client Secret**
- [ ] Clicked Save
- [ ] Saw confirmation message

---

## 💻 XCODE CONFIGURATION

### Config.swift
- [ ] Opened `ANITA/Utils/Config.swift`
- [ ] Found `googleClientID` property (line ~57)
- [ ] Replaced empty string `""` with iOS Client ID
- [ ] Format: `"123456789-abc.apps.googleusercontent.com"`
- [ ] Saved file (Cmd+S)

### Calculate Reversed Client ID
- [ ] Took iOS Client ID: `123456789-abc.apps.googleusercontent.com`
- [ ] Calculated reversed: `com.googleusercontent.apps.123456789-abc`
- [ ] **Wrote down reversed Client ID**

### Info.plist
- [ ] Opened `ANITA/Info.plist`
- [ ] Found `CFBundleURLTypes` → `CFBundleURLSchemes`
- [ ] Added reversed Client ID as new string in array
- [ ] Format: `<string>com.googleusercontent.apps.123456789-abc</string>`
- [ ] Saved file (Cmd+S)

### Bundle Identifier
- [ ] Checked Bundle Identifier in Xcode
- [ ] Verified it's: `com.anita.app`
- [ ] If different, either changed it OR created new OAuth client with correct Bundle ID

---

## 🧪 TESTING

- [ ] Cleaned build folder (Cmd+Shift+K)
- [ ] Built project (Cmd+B) - no errors
- [ ] Ran app on simulator/device (Cmd+R)
- [ ] Navigated to login screen
- [ ] Tapped "Log in with Google" button
- [ ] Google Sign-In popup appeared ✅
- [ ] Selected Google account
- [ ] Successfully signed in ✅
- [ ] Checked console logs - saw validation message ✅

---

## ✅ FINAL VERIFICATION

**Double-check these:**

- [ ] iOS Client ID is in `Config.swift` (not empty, in quotes)
- [ ] Reversed Client ID is in `Info.plist` (as URL scheme)
- [ ] Bundle ID is `com.anita.app` everywhere
- [ ] Web Client ID is in Supabase Dashboard
- [ ] Web Client Secret is in Supabase Dashboard
- [ ] Google provider is enabled in Supabase
- [ ] No typos in any Client IDs
- [ ] No extra spaces in Client IDs

---

## 📚 DOCUMENTATION

If you need more help, see:
- `GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md` - Complete detailed tutorial
- `GOOGLE_SIGNIN_STEP_BY_STEP.md` - Step-by-step visual guide
- `GOOGLE_SIGNIN_IOS_SETUP.md` - Original setup guide

---

**Once all items are checked, Google Sign-In should work!** 🎉

