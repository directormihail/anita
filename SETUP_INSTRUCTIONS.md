# Setup Instructions - Environment Variables

## Backend Setup (.env file)

1. Navigate to `/ANITA backend` folder
2. Create a `.env` file (copy from `.env.example` if it exists)
3. Add your keys in lines 3-19 as requested:

```env
# ANITA Backend Environment Variables
# IMPORTANT: Add this file to .gitignore to keep keys secure

# Supabase Configuration (lines 3-19)
SUPABASE_URL=your_supabase_project_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_MODEL=gpt-4o-mini

# Stripe Configuration
STRIPE_SECRET_KEY=your_stripe_secret_key_here

# Server Configuration
PORT=3001
NODE_ENV=development
ALLOWED_ORIGINS=*
```

**Replace the placeholder values with your actual keys:**
- `SUPABASE_URL`: Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY`: Your Supabase anon/public key
- `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key
- `OPENAI_API_KEY`: Your OpenAI API key
- `STRIPE_SECRET_KEY`: Your Stripe secret key

## iOS Setup (Config.swift)

1. Open the iOS project in Xcode
2. Navigate to `ANITA/Utils/Config.swift`
3. Replace the placeholder values:

```swift
static let supabaseURL: String = {
    if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
        return url
    }
    return "YOUR_SUPABASE_URL_HERE"  // Replace this
}()

static let supabaseAnonKey: String = {
    if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
        return key
    }
    return "YOUR_SUPABASE_ANON_KEY_HERE"  // Replace this
}()
```

**Important:**
- Use the same `SUPABASE_URL` and `SUPABASE_ANON_KEY` as in backend `.env`
- Do NOT commit `Config.swift` with real keys to git
- Consider adding `Config.swift` to `.gitignore` or using a `Config.swift.example` template

## Security Notes

1. **Never commit `.env` file** - Add to `.gitignore`
2. **Never commit `Config.swift` with real keys** - Use placeholders or environment variables
3. **Use different keys for development and production**
4. **Rotate keys if they're accidentally exposed**

## Getting Your Keys

### Supabase Keys:
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Settings → API
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** → `SUPABASE_ANON_KEY` (for iOS)
   - **service_role** → `SUPABASE_SERVICE_ROLE_KEY` (for backend only)

### OpenAI Key:
1. Go to [OpenAI Platform](https://platform.openai.com)
2. API Keys section
3. Create new key or use existing

### Stripe Key:
1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Developers → API keys
3. Copy Secret key

## Verification

### Backend:
```bash
cd "ANITA backend"
npm install
npm run dev
# Check console for "✅ All required environment variables are set"
```

### iOS:
1. Open app in Xcode
2. Go to Settings
3. Check "Supabase Status" - should show "Configured"
4. Click "Test Connection" - should show "Success"

## Troubleshooting

- **Backend can't find keys**: Make sure `.env` is in `/ANITA backend` folder (same level as `package.json`)
- **iOS shows "Not Configured"**: Check `Config.swift` has real values (not placeholders)
- **Connection fails**: Verify keys are correct and Supabase project is active

