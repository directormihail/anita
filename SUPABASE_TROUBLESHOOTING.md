# Supabase Troubleshooting Guide

## Common Issues and Fixes

### 1. "Supabase is not configured" Error

**Problem:** The Supabase URL or Anon Key is not set.

**Solution:**
1. Open the iOS app
2. Go to Settings
3. Scroll to "Supabase Configuration"
4. Enter your Supabase URL (e.g., `https://xxxxx.supabase.co`)
5. Enter your Supabase Anon Key
6. Click "Save Supabase Config"
7. Click "Test Connection" to verify

### 2. Authentication Fails

**Common causes:**

#### A. Incorrect URL Format
- ❌ Wrong: `https://xxxxx.supabase.co/` (trailing slash)
- ✅ Correct: `https://xxxxx.supabase.co` (no trailing slash)

#### B. Wrong Anon Key
- Make sure you're using the **anon/public** key, not the service role key
- Find it in: Supabase Dashboard → Settings → API → Project API keys → `anon` `public`

#### C. Network/CORS Issues
- Ensure your device has internet connection
- Check if Supabase project is active (not paused)

### 3. "Invalid response" or Decode Errors

**Problem:** The response format doesn't match expected structure.

**Debug Steps:**
1. Check Xcode console for detailed error messages
2. Look for `[Supabase]` prefixed logs
3. Verify the response format matches Supabase API

**Common fixes:**
- Ensure Supabase URL is correct
- Verify Anon Key is valid
- Check if Supabase project is accessible

### 4. Database Operations Fail

**Problem:** Can't create conversations or save messages.

**Possible causes:**
- Not authenticated (no access token)
- RLS (Row Level Security) policies blocking access
- Missing tables in Supabase

**Solution:**
1. Sign in first (Authentication section in Settings)
2. Check Supabase Dashboard → Authentication → Policies
3. Verify tables exist: `conversations` and `anita_data`

### 5. How to Get Your Supabase Keys

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → Use as Supabase URL
   - **anon public** key → Use as Supabase Anon Key

### 6. Testing Your Configuration

1. Open Settings in the app
2. Enter Supabase URL and Anon Key
3. Click **"Test Connection"**
4. Should show "Success" if configured correctly
5. If it fails, check:
   - URL format (no trailing slash)
   - Anon key is correct
   - Internet connection
   - Supabase project is active

### 7. Debug Logging

The app now includes detailed logging. Check Xcode console for:
- `[Supabase]` - All Supabase operations
- `[Settings]` - Settings-related operations

Look for:
- Request URLs
- Response status codes
- Error messages
- Response bodies

### 8. Manual Testing with curl

You can test your Supabase connection manually:

```bash
# Test health endpoint
curl -H "apikey: YOUR_ANON_KEY" \
     https://YOUR_PROJECT.supabase.co/auth/v1/health

# Test sign in
curl -X POST \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"password123"}' \
     https://YOUR_PROJECT.supabase.co/auth/v1/token?grant_type=password
```

### 9. Still Not Working?

If you're still having issues:

1. **Check Xcode Console** - Look for detailed error messages
2. **Verify Keys** - Double-check URL and Anon Key in Supabase Dashboard
3. **Test Connection** - Use the "Test Connection" button in Settings
4. **Check Network** - Ensure device has internet access
5. **Supabase Status** - Check if Supabase is experiencing issues

### 10. Required Supabase Tables

Make sure these tables exist in your Supabase database:

**conversations:**
- id (UUID, primary key)
- user_id (TEXT)
- title (TEXT)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)

**anita_data:**
- id (UUID, primary key)
- account_id (TEXT)
- conversation_id (UUID, foreign key)
- message_text (TEXT)
- sender (TEXT)
- message_id (TEXT)
- data_type (TEXT)
- created_at (TIMESTAMP)

## Quick Checklist

- [ ] Supabase URL entered (no trailing slash)
- [ ] Anon Key entered (not service role key)
- [ ] "Test Connection" shows "Success"
- [ ] Signed in with valid credentials
- [ ] Tables exist in Supabase
- [ ] RLS policies allow access
- [ ] Internet connection active

