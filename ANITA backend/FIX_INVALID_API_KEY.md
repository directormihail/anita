# 🔧 Fix: Invalid API Key Error for iOS

## Problem
Your iOS app is showing: **"Failed to create conversation: Invalid API key"**

## Root Cause
The `SUPABASE_SERVICE_ROLE_KEY` in your `.env` file is **invalid or expired**. Supabase is rejecting it with a 401 error.

## Quick Fix (3 minutes)

### Step 1: Get Fresh Service Role Key

1. **Open Supabase Dashboard**: https://app.supabase.com
2. **Select your project**: `kezregiqfxlrvaxytdet`
3. **Go to**: Settings → API
4. **Scroll to**: "Project API keys" section
5. **Find**: The `service_role` key (it's the **SECRET** one, NOT the `anon` key)
6. **Click**: The eye icon 👁️ to reveal it
7. **Copy**: The entire key (it's a long JWT token starting with `eyJhbGci...`)

### Step 2: Update .env File

1. Open: `/Users/mishadzhuran/My projects/ANITA backend/.env`
2. Find the line: `SUPABASE_SERVICE_ROLE_KEY=...`
3. **Replace the entire value** with your fresh service role key
4. **Save the file**

**Important:**
- Make sure there are **no spaces** around the `=` sign
- Make sure there are **no quotes** around the key
- Make sure you copied the **entire key** (it's very long)

### Step 3: Restart Backend

```bash
# Stop the current server (Ctrl+C if running)
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm start
```

### Step 4: Verify It Works

Run the test script:
```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
node test-all-api-keys.cjs
```

You should see:
```
✅ Backend create-conversation endpoint (test)
   Create conversation endpoint works!
```

### Step 5: Test in iOS App

1. Open your iOS app
2. Try sending a message
3. The error should be gone! ✅

## How to Verify Your Key is Correct

The service role key should:
- ✅ Start with `eyJhbGci...` (JWT format)
- ✅ Be ~200+ characters long
- ✅ Have 3 parts separated by dots
- ✅ When decoded, contain `"role":"service_role"` (not `"role":"anon"`)

## Common Mistakes

❌ **Using the anon key instead of service_role key**
- The anon key is for client-side (iOS app)
- The service_role key is for backend only

❌ **Copying only part of the key**
- The key is very long - make sure you copy all of it

❌ **Extra spaces or quotes**
- Should be: `SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...`
- NOT: `SUPABASE_SERVICE_ROLE_KEY = "eyJhbGci..."`

## Still Not Working?

1. **Double-check the key** in Supabase Dashboard
2. **Make sure backend is restarted** after updating .env
3. **Check backend console** for error messages
4. **Run the test script** to see detailed diagnostics:
   ```bash
   node test-all-api-keys.cjs
   ```

## Test Results Summary

After running `test-all-api-keys.cjs`, you should see:
- ✅ All Supabase tests passing
- ✅ Backend create-conversation endpoint working
- ✅ No "Invalid API key" errors

If you still see failures, the test script will tell you exactly what's wrong.

