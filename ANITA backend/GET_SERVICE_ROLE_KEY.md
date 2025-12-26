# Get Supabase Service Role Key

The backend needs the **Service Role Key** (not the anon key) to access Supabase with admin privileges.

## How to Get It:

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project: `kezregiqfxlrvaxytdet`
3. Go to **Settings** → **API**
4. Scroll down to **Project API keys**
5. Find the **`service_role`** key (it's the secret one, not the anon key)
6. Copy it
7. Open `/ANITA backend/.env` file
8. Replace `YOUR_SERVICE_ROLE_KEY_HERE` on line 5 with your actual service role key

## Important:
- ⚠️ **Never share or commit the service role key** - it has admin access
- ⚠️ **Only use it on the backend** - never in client-side code
- The anon key is for iOS app (already configured)
- The service role key is for backend only

## After Adding the Key:

1. Restart the backend server
2. Check console - should show "✅ All required environment variables are set"

