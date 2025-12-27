# ⚡ Quick Fix: Make Chat Work

## The Problem
Your backend `.env` file has a placeholder for `SUPABASE_SERVICE_ROLE_KEY`. The chat needs this key to save conversations.

## The Solution (2 minutes)

### Step 1: Get Your Service Role Key

1. Open: https://app.supabase.com
2. Select project: **kezregiqfxlrvaxytdet**
3. Go to: **Settings** → **API**
4. Scroll to: **"Project API keys"**
5. Find: **`service_role`** key (the secret one, NOT the anon key)
6. Click: 👁️ eye icon to reveal it
7. Copy: The entire key (starts with `eyJhbGci...`)

### Step 2: Update .env File

Open this file:
```
/Users/mishadzhuran/My projects/ANITA backend/.env
```

Find this line:
```
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_HERE
```

Replace `YOUR_SERVICE_ROLE_KEY_HERE` with your copied key.

**Example:**
```
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlenJlZ2lxZnhscnZheHl0ZGV0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzY5NjkxOCwiZXhwIjoyMDczMjcyOTE4fQ.YOUR_ACTUAL_KEY_HERE
```

### Step 3: Restart Backend

```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm start
```

You should see:
```
✅ All required environment variables are set
```

### Step 4: Test Chat

Open your iOS app and send a message. It should work! ✅

## Alternative: Use Setup Script

You can also run:
```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
./setup-service-key.sh
```

This script will guide you through the process interactively.

## Still Not Working?

1. Make sure the backend server is running
2. Check the backend console for error messages
3. Verify the key starts with `eyJhbGci...`
4. Make sure there are no extra spaces in the .env file


