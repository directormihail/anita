# 🔑 Verify Your Supabase Service Role Key

## Current Status
Your service role key is configured in `.env`, but Supabase is returning "Invalid API key".

## Possible Causes:
1. **Key was rotated/regenerated** in Supabase Dashboard
2. **Wrong key copied** (maybe copied anon key instead of service_role key)
3. **Key is for a different project**

## How to Fix:

### Step 1: Get Fresh Service Role Key
1. Go to: https://app.supabase.com
2. Select project: **kezregiqfxlrvaxytdet**
3. Go to: **Settings** → **API**
4. Scroll to: **"Project API keys"**
5. Find: **`service_role`** key (the SECRET one, NOT anon)
6. Click: 👁️ eye icon to reveal it
7. **Copy the ENTIRE key** (make sure you get all of it)

### Step 2: Verify Key Format
The key should:
- Start with: `eyJhbGci...`
- Be ~200+ characters long
- Have 3 parts separated by dots (JWT format)
- Contain `service_role` in the middle part (when decoded)

### Step 3: Update .env File
Replace line 7 in `/Users/mishadzhuran/My projects/ANITA backend/.env`:

```
SUPABASE_SERVICE_ROLE_KEY=your_fresh_key_here
```

### Step 4: Restart Server
```bash
pkill -9 node
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm start
```

### Step 5: Test
```bash
curl -X POST http://localhost:3001/api/v1/create-conversation \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","title":"Test"}'
```

## Quick Test Script
Run this to verify your key works:
```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
node check-config.js
```

If it shows ✅ for all items, the key is valid!

