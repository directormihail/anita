# Google Sign-In Setup - Start Here! 🚀

This directory contains comprehensive guides to set up Google Sign-In for your ANITA iOS app.

---

## 📖 Which Guide Should I Use?

### 🎯 **First Time Setup?**
→ Start with: **`GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md`**
- Most detailed, step-by-step instructions
- Includes exact button clicks and what to expect
- Best for beginners

### ⚡ **Want Quick Reference?**
→ Use: **`GOOGLE_SIGNIN_CHECKLIST.md`**
- Print-friendly checklist
- Quick verification of each step
- Good for following along

### 📝 **Prefer Visual Step-by-Step?**
→ Use: **`GOOGLE_SIGNIN_STEP_BY_STEP.md`**
- Visual descriptions of what you'll see
- Clear navigation paths
- Good for visual learners

### 🏃 **Just Need Quick Start?**
→ Use: **`GOOGLE_SIGNIN_QUICK_START.md`**
- 3-step quick setup
- For experienced developers
- Minimal instructions

### 📚 **Need Technical Details?**
→ Use: **`GOOGLE_SIGNIN_IOS_SETUP.md`**
- Original comprehensive guide
- Technical explanations
- Troubleshooting section

---

## 🎯 Recommended Path

**For most users, follow this order:**

1. **Start here:** `GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md`
   - Follow it step-by-step
   - Don't skip any steps

2. **While working:** `GOOGLE_SIGNIN_CHECKLIST.md`
   - Keep it open
   - Check off items as you complete them

3. **If stuck:** `GOOGLE_SIGNIN_STEP_BY_STEP.md`
   - More visual descriptions
   - Helps if you're lost

4. **For troubleshooting:** See troubleshooting sections in any guide

---

## ⚡ Quick Summary

**What you need to do:**

1. **Google Cloud Console:**
   - Create iOS OAuth Client → Get iOS Client ID
   - Create Web OAuth Client → Get Web Client ID + Secret

2. **Supabase Dashboard:**
   - Enable Google provider
   - Add Web Client ID + Secret

3. **Xcode:**
   - Add iOS Client ID to `Config.swift`
   - Add reversed Client ID to `Info.plist`

4. **Test:**
   - Build and run
   - Try Google Sign-In

---

## 📋 Files Overview

| File | Purpose | Best For |
|------|---------|----------|
| `GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md` | Most detailed tutorial | First-time setup |
| `GOOGLE_SIGNIN_STEP_BY_STEP.md` | Visual step-by-step | Visual learners |
| `GOOGLE_SIGNIN_CHECKLIST.md` | Printable checklist | Following along |
| `GOOGLE_SIGNIN_QUICK_START.md` | Quick 3-step guide | Experienced devs |
| `GOOGLE_SIGNIN_IOS_SETUP.md` | Original guide | Technical reference |

---

## 🎓 Key Concepts

### Two Different Client IDs

You need **TWO** OAuth clients:

1. **iOS Client ID** (for native sign-in)
   - Type: iOS application
   - Bundle ID: `com.anita.app`
   - Goes in: `Config.swift`

2. **Web Client ID** (for Supabase)
   - Type: Web application
   - Redirect URI: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`
   - Goes in: Supabase Dashboard

### Reversed Client ID

Your iOS Client ID: `123456789-abc.apps.googleusercontent.com`
Reversed for URL scheme: `com.googleusercontent.apps.123456789-abc`
Goes in: `Info.plist` as URL scheme

---

## ✅ Pre-Setup Requirements

Before starting, make sure you have:
- [ ] Google account
- [ ] Access to Google Cloud Console
- [ ] Supabase account and project access
- [ ] Xcode installed
- [ ] ANITA iOS project open
- [ ] 15-20 minutes

---

## 🚨 Common Mistakes

1. **Using Web Client ID in Config.swift**
   - ❌ Wrong: Using Web Client ID
   - ✅ Right: Using iOS Client ID

2. **Wrong Bundle ID**
   - ❌ Wrong: `com.anita` or `com.anita.app.ios`
   - ✅ Right: `com.anita.app` (exactly)

3. **Missing Reversed Client ID in Info.plist**
   - ❌ Wrong: Only `anita` URL scheme
   - ✅ Right: Both `anita` and reversed Client ID

4. **Using iOS Client ID in Supabase**
   - ❌ Wrong: iOS Client ID in Supabase Dashboard
   - ✅ Right: Web Client ID + Secret in Supabase

---

## 🆘 Need Help?

1. **Check the checklist:** `GOOGLE_SIGNIN_CHECKLIST.md`
   - Make sure all items are checked

2. **Review the complete tutorial:** `GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md`
   - Go back to the step you're on
   - Read carefully

3. **Check console logs in Xcode:**
   - Look for error messages
   - They'll tell you what's wrong

4. **Verify your credentials:**
   - Double-check Client IDs are correct
   - No typos, no extra spaces
   - Right Client ID in right place

---

## 📞 Support Resources

- [Google Sign-In iOS Docs](https://developers.google.com/identity/sign-in/ios)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Supabase OAuth Providers](https://supabase.com/docs/guides/auth/social-login/auth-google)

---

## 🎉 Success Indicators

You'll know it's working when:
- ✅ App builds without errors
- ✅ Google Sign-In popup appears when you tap the button
- ✅ You can select your Google account
- ✅ You're successfully authenticated
- ✅ Console shows: `[Supabase] ✓ Google Sign-In configuration validated`

---

**Ready to start? Open `GOOGLE_SIGNIN_COMPLETE_TUTORIAL.md` and follow along!** 🚀

