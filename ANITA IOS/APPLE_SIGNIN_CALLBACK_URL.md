# Apple Sign-In Callback URL

## Your Supabase Callback URL

```
https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback
```

## When Do You Need This?

### ✅ For Native iOS Apps (Your Current Setup)
**You DON'T need the callback URL!**

Native iOS Sign-In uses Apple's AuthenticationServices framework directly. It doesn't use web OAuth, so no callback URL is required.

### ⚠️ For Web/Cross-Platform OAuth (Optional)
**You DO need the callback URL if:**
- You want to support Apple Sign-In on web browsers
- You want to support Apple Sign-In on Android/Windows/Linux via OAuth flow
- You're using `signInWithOAuth()` instead of native Sign-In

## How to Use Callback URL (If Needed for Web)

If you decide to add web support later:

1. **In Apple Developer Console:**
   - Go to [Services IDs](https://developer.apple.com/account/resources/identifiers/list/serviceId)
   - Create or edit your Services ID
   - Under "Website URLs", add:
     - **Domains and Subdomains**: `kezregiqfxlrvaxytdet.supabase.co`
     - **Return URLs**: `https://kezregiqfxlrvaxytdet.supabase.co/auth/v1/callback`

2. **In Supabase Dashboard:**
   - The callback URL is automatically configured
   - You'll need to add:
     - **OAuth client ID**: Your Services ID
     - **OAuth client secret**: Generated JWT secret key

## Current Configuration Status

✅ **Native iOS**: Configured and ready (no callback URL needed)
⚠️ **Web OAuth**: Not configured (callback URL available if needed)

---

**For your current native iOS app, you can ignore the callback URL!** 🎉

