# Deploying the backend (e.g. Railway)

After you add or change API routes, you **must redeploy** the backend so the live server has the new code.

## If the app shows "route not found" for Delete Account

The **Delete Account** feature uses `POST /api/v1/delete-account`. If the iOS app reports that the API route is not found (404):

1. **Redeploy this backend** to your hosting (e.g. Railway).
2. After deploy, the server startup log should include:
   - `POST /api/v1/clear-user-data`
   - `POST /api/v1/delete-account`
3. Try **Delete Account** again in the app (Settings → Privacy & Data → Delete Account).

## How to redeploy (Railway example)

- If you use **Git**: push your latest code to the branch connected to Railway; Railway will build and deploy.
- If you use **Railway CLI**: run `railway up` or deploy from the Railway dashboard.
- Ensure the deployed service uses the same environment variables (e.g. `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) so delete-account can clear data and remove the auth user.

Once the new build is live, the Delete Account button in the app will work.
