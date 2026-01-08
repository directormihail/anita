#!/bin/bash

# Apple Sign-In Configuration Script for Supabase
# This script helps configure Apple Sign-In in your Supabase project

set -e

echo "🍎 Apple Sign-In Configuration for ANITA"
echo "=========================================="
echo ""

# Project details
PROJECT_REF="kezregiqfxlrvaxytdet"
BUNDLE_ID="com.anita.app"
PROJECT_NAME="ANITA"

echo "Project: $PROJECT_NAME"
echo "Project Ref: $PROJECT_REF"
echo "Bundle ID: $BUNDLE_ID"
echo ""

# Check if access token is provided
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    echo "⚠️  SUPABASE_ACCESS_TOKEN not found in environment"
    echo ""
    echo "To get your access token:"
    echo "1. Go to: https://supabase.com/dashboard/account/tokens"
    echo "2. Create a new access token"
    echo "3. Run: export SUPABASE_ACCESS_TOKEN='your-token-here'"
    echo "4. Then run this script again"
    echo ""
    echo "Alternatively, you can configure Apple Sign-In manually:"
    echo "1. Go to: https://app.supabase.com/project/$PROJECT_REF/auth/providers"
    echo "2. Find 'Apple' provider"
    echo "3. Enable it (toggle ON)"
    echo "4. In 'Client IDs' field, add: $BUNDLE_ID"
    echo "5. Click 'Save'"
    echo ""
    exit 1
fi

echo "✅ Access token found"
echo ""
echo "Configuring Apple Sign-In via Management API..."
echo ""

# Configure Apple provider
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH \
  "https://api.supabase.com/v1/projects/$PROJECT_REF/config/auth" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"external_apple_enabled\": true,
    \"external_apple_client_id\": \"$BUNDLE_ID\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Apple Sign-In configured successfully!"
    echo ""
    echo "Configuration:"
    echo "  - Provider: Apple"
    echo "  - Enabled: true"
    echo "  - Client ID: $BUNDLE_ID"
    echo ""
    echo "Next steps:"
    echo "1. Enable 'Sign in with Apple' capability in Xcode:"
    echo "   - Open ANITA.xcodeproj"
    echo "   - Select ANITA target"
    echo "   - Go to Signing & Capabilities"
    echo "   - Click + Capability"
    echo "   - Add 'Sign in with Apple'"
    echo ""
    echo "2. Test on a physical device (not simulator)"
    echo "3. Go to Settings → Sign In / Sign Up"
    echo "4. Tap 'Sign in with Apple' button"
    echo ""
else
    echo "❌ Failed to configure Apple Sign-In"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
    echo ""
    echo "Please configure manually:"
    echo "1. Go to: https://app.supabase.com/project/$PROJECT_REF/auth/providers"
    echo "2. Find 'Apple' provider"
    echo "3. Enable it (toggle ON)"
    echo "4. In 'Client IDs' field, add: $BUNDLE_ID"
    echo "5. Click 'Save'"
    echo ""
    exit 1
fi

