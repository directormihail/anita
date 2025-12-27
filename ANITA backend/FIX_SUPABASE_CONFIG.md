# 🔧 Fix: Supabase Configuration Error

## Problem
You're seeing the error: **"Supabase is incorrectly configured"** in the chat.

This happens because the backend needs the **Supabase Service Role Key** to save conversations and messages to the database.

## Quick Fix (5 minutes)

### Step 1: Get Your Supabase Service Role Key

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project: `kezregiqfxlrvaxytdet`
3. Go to **Settings** → **API**
4. Scroll down to **Project API keys**
5. Find the **`service_role`** key (it's the secret one, starts with `eyJhbGci...`)
6. Click the **eye icon** to reveal it
7. **Copy the entire key** (it's long, make sure you get it all)

### Step 2: Update Backend .env File

1. Open `/ANITA backend/.env` file
2. Find the line: `SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_HERE`
3. Replace `YOUR_SERVICE_ROLE_KEY_HERE` with your actual service role key
4. Save the file

**Example:**
```env
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlenJlZ2lxZnhscnZheHl0ZGV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzY5NjkxOCwiZXhwIjoyMDczMjcyOTE4fQ.YOUR_ACTUAL_KEY_HERE
```

### Step 3: Restart Backend Server

1. Stop the backend server (Ctrl+C if running)
2. Start it again:
   ```bash
   cd "ANITA backend"
   npm start
   ```
3. Check the console - it should show: **"✅ All required environment variables are set"**

### Step 4: Test Chat

1. Open your iOS app
2. Try sending a message in the chat
3. The error should be gone! ✅

## Verification

After updating, the backend console should show:
```
✅ All required environment variables are set
```

If you still see warnings about missing variables, double-check:
- The key is on the correct line in `.env`
- There are no extra spaces or quotes around the key
- The key starts with `eyJhbGci...` (it's a JWT token)

## Important Security Notes

⚠️ **Never share or commit the service role key:**
- It has full admin access to your Supabase database
- Only use it on the backend (server-side)
- Never put it in client-side code (iOS app, web app, etc.)
- The `.env` file should be in `.gitignore`

## Still Having Issues?

1. **Check the .env file location**: Make sure it's in `/ANITA backend/.env` (not in a subfolder)
2. **Check for typos**: The variable name must be exactly `SUPABASE_SERVICE_ROLE_KEY`
3. **Restart the server**: Environment variables are only loaded when the server starts
4. **Check the key format**: It should be a long JWT token starting with `eyJhbGci...`

## Need Help?

- See `GET_SERVICE_ROLE_KEY.md` for detailed instructions
- Check backend console logs for specific error messages
- Verify your Supabase project is active (not paused)


