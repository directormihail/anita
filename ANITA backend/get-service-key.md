# 🔑 Get Your Supabase Service Role Key

## Quick Steps:

1. **Open Supabase Dashboard**: https://app.supabase.com
2. **Select your project**: `kezregiqfxlrvaxytdet`
3. **Go to**: Settings → API
4. **Scroll to**: "Project API keys" section
5. **Find**: The `service_role` key (it's the **secret** one, not the `anon` key)
6. **Click**: The eye icon 👁️ to reveal it
7. **Copy**: The entire key (it's a long JWT token starting with `eyJhbGci...`)

## Update .env File:

1. Open: `/Users/mishadzhuran/My projects/ANITA backend/.env`
2. Find the line: `SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY_HERE`
3. Replace `YOUR_SERVICE_ROLE_KEY_HERE` with your copied key
4. Save the file

## Restart Backend:

```bash
# Stop the current server (Ctrl+C)
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm start
```

## Verify:

After restarting, the console should show:
```
✅ All required environment variables are set
```

Then test the chat - it should work! ✅


