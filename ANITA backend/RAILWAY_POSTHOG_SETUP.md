# Railway: PostHog environment variables

Use these steps so your ANITA backend on Railway has the same PostHog config as local and iOS.

## 1. Open your Railway project

1. Go to [railway.app](https://railway.app) and sign in.
2. Open the project that runs the **ANITA backend** (the one that uses this repo’s `ANITA backend` folder).

## 2. Open Variables

1. Click your **backend service** (the one that runs the Node/Express app).
2. Go to the **Variables** tab (or **Settings** → **Variables**).

## 3. Add PostHog variables

Click **+ New Variable** (or **Add variable**) and add these **one by one**:

| Variable           | Value                                                                 |
|--------------------|-----------------------------------------------------------------------|
| `POSTHOG_KEY`      | `phc_ec2vFoSH9LiPzanrLJ4r4is34g0yR81T3c6rVN0jRPd`                    |
| `POSTHOG_PROJECT_ID` | `318843`                                                           |
| `POSTHOG_HOST`     | `https://us.i.posthog.com`                                           |

- **POSTHOG_KEY** – Project API key (US cloud).
- **POSTHOG_PROJECT_ID** – Project ID (318843).
- **POSTHOG_HOST** – US cloud host.

## 4. Redeploy (if needed)

- If **“Redeploy on variable change”** is on, the service will redeploy after you save.
- Otherwise, trigger a redeploy: **Deployments** → latest deployment → **⋮** → **Redeploy**.

## 5. Confirm

- After deploy, the backend will have `process.env.POSTHOG_KEY`, `POSTHOG_PROJECT_ID`, and `POSTHOG_HOST` set.
- These match the values in:
  - **Backend:** `ANITA backend/.env`
  - **iOS:** `ANITA IOS/.env` (reference) and `Config.swift` (used by the app).

## Reference: where PostHog is configured

| Place        | File / location                                      |
|-------------|-------------------------------------------------------|
| Backend     | `ANITA backend/.env`                                 |
| Backend (Railway) | Project → Service → Variables (same names as above) |
| iOS app     | `ANITA IOS/ANITA/Utils/Config.swift` (built-in values; optional override via Xcode env) |
| iOS reference | `ANITA IOS/.env` (copy of values; root `.gitignore` ignores `.env`) |
