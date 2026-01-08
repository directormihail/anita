# Fix: Apple Sign-In Secret Key Error

## The Problem

You're seeing an error: **"Secret key should be a JWT."** in the Supabase Apple Sign-In configuration.

## The Solution

### For Native iOS Apps (Your Case)

**You can leave the Secret Key field BLANK!** 

Native iOS Sign-In doesn't require a secret key. You only need:
- ✅ **Enable Sign in with Apple**: ON
- ✅ **Client IDs**: `com.anita.app`
- ✅ **Secret Key (for OAuth)**: **LEAVE EMPTY** ← This is the fix!

### Steps to Fix

1. Go to: https://app.supabase.com/project/kezregiqfxlrvaxytdet/auth/providers
2. Find **Apple** provider
3. **Clear the Secret Key field** - delete the value `re_2KumjGGQ_KfMeGfxa7sBaH5kPg1kX997X`
4. Leave it **empty**
5. Make sure **Client IDs** has: `com.anita.app`
6. Click **Save**

## Why This Works

- **Native iOS Sign-In** uses Apple's native authentication (AuthenticationServices framework)
- It doesn't use OAuth flow, so no secret key is needed
- The secret key is **only** required for web-based OAuth flows
- Your Bundle ID (`com.anita.app`) in Client IDs is sufficient for native iOS

## Configuration Summary

| Field | Value | Required? |
|-------|-------|-----------|
| Enable Sign in with Apple | ✅ ON | Yes |
| Client IDs | `com.anita.app` | Yes |
| Secret Key (for OAuth) | **(empty)** | No (for native iOS) |
| Allow users without an email | OFF | Optional |

## Important Note

The warning about "Apple OAuth secret keys expire every 6 months" only applies if you're using web OAuth. Since you're using native iOS Sign-In, you can ignore this warning.

---

**After clearing the Secret Key field, the error will disappear and Apple Sign-In will work!** ✅

