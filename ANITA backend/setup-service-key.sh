#!/bin/bash

# Script to help set up Supabase Service Role Key

echo "🔑 Supabase Service Role Key Setup"
echo "===================================="
echo ""
echo "This script will help you set up your Supabase Service Role Key."
echo ""
echo "📋 Steps:"
echo "1. Go to: https://app.supabase.com"
echo "2. Select project: kezregiqfxlrvaxytdet"
echo "3. Go to: Settings → API"
echo "4. Find the 'service_role' key (secret key, not anon key)"
echo "5. Click the eye icon to reveal it"
echo "6. Copy the entire key"
echo ""
read -p "Press Enter when you have copied the service role key..."

echo ""
echo "Paste your service role key below (it will start with 'eyJhbGci...'):"
read -s SERVICE_KEY

if [ -z "$SERVICE_KEY" ]; then
    echo "❌ No key provided. Exiting."
    exit 1
fi

if [[ ! "$SERVICE_KEY" =~ ^eyJ ]]; then
    echo "⚠️  Warning: Service role key should start with 'eyJ'. Continue anyway? (y/n)"
    read -p "> " confirm
    if [ "$confirm" != "y" ]; then
        echo "Exiting."
        exit 1
    fi
fi

# Update .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found!"
    exit 1
fi

# Backup .env file
cp "$ENV_FILE" "$ENV_FILE.backup"
echo "✅ Created backup: $ENV_FILE.backup"

# Update the service role key
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY|" "$ENV_FILE"
else
    # Linux
    sed -i "s|SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=$SERVICE_KEY|" "$ENV_FILE"
fi

echo "✅ Updated .env file with service role key"
echo ""
echo "🔄 Next steps:"
echo "1. Restart your backend server:"
echo "   cd \"$(pwd)\""
echo "   npm start"
echo ""
echo "2. The server should show: '✅ All required environment variables are set'"
echo ""
echo "3. Test the chat in your iOS app - it should work now! ✅"

