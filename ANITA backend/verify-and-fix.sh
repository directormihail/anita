#!/bin/bash

echo "🔍 Verifying Supabase Configuration..."
echo ""

cd "$(dirname "$0")"
source .env 2>/dev/null || true

# Check current state
echo "Current Configuration:"
echo "======================"
echo "SUPABASE_URL: ${SUPABASE_URL:0:50}..."
echo ""

if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ SUPABASE_SERVICE_ROLE_KEY: MISSING"
    exit 1
fi

KEY_LENGTH=${#SUPABASE_SERVICE_ROLE_KEY}
KEY_PREVIEW="${SUPABASE_SERVICE_ROLE_KEY:0:30}..."

echo "SUPABASE_SERVICE_ROLE_KEY: $KEY_PREVIEW"
echo "Key Length: $KEY_LENGTH characters"
echo ""

# Validate the key
if [[ "$SUPABASE_SERVICE_ROLE_KEY" == *"YOUR_SERVICE_ROLE_KEY_HERE"* ]] || [[ "$SUPABASE_SERVICE_ROLE_KEY" == *"YOUR_"* ]]; then
    echo "❌ PROBLEM FOUND: Service Role Key is still a placeholder!"
    echo ""
    echo "The key must be a real JWT token from Supabase, not 'YOUR_SERVICE_ROLE_KEY_HERE'"
    echo ""
    echo "📋 To Fix:"
    echo "1. Go to: https://app.supabase.com"
    echo "2. Select project: kezregiqfxlrvaxytdet"
    echo "3. Go to: Settings → API"
    echo "4. Find 'service_role' key (the SECRET one, not anon)"
    echo "5. Click the eye icon 👁️ to reveal it"
    echo "6. Copy the ENTIRE key (it's long, starts with 'eyJhbGci...')"
    echo ""
    echo "Then update .env file line 7:"
    echo "SUPABASE_SERVICE_ROLE_KEY=your_actual_key_here"
    echo ""
    exit 1
fi

if [ "$KEY_LENGTH" -lt 100 ]; then
    echo "⚠️  WARNING: Key seems too short (should be ~200+ characters)"
    echo "Service role keys are long JWT tokens"
fi

if [[ ! "$SUPABASE_SERVICE_ROLE_KEY" =~ ^eyJ ]]; then
    echo "⚠️  WARNING: Key should start with 'eyJ' (JWT format)"
fi

if [ "$KEY_LENGTH" -lt 100 ] || [[ ! "$SUPABASE_SERVICE_ROLE_KEY" =~ ^eyJ ]]; then
    echo ""
    echo "The key format looks incorrect. Please verify you copied the entire key."
    exit 1
fi

echo "✅ Service Role Key looks valid!"
echo ""
echo "🔄 Restarting backend server to pick up the configuration..."
echo ""

# Restart server
pkill -f "node dist/index.js" 2>/dev/null
sleep 1
npm start &
SERVER_PID=$!

echo "Server starting (PID: $SERVER_PID)..."
echo "Waiting for server to be ready..."
sleep 3

# Check if server is running
if curl -s http://localhost:3001/health > /dev/null; then
    echo "✅ Server is running!"
    echo ""
    echo "🧪 Testing configuration..."
    sleep 1
    
    RESPONSE=$(curl -s -X POST http://localhost:3001/api/v1/create-conversation \
        -H "Content-Type: application/json" \
        -d '{"userId":"test-verify","title":"Test"}' 2>&1)
    
    if echo "$RESPONSE" | grep -q "success\|conversation"; then
        echo "✅ Configuration is working! Chat should work now."
    elif echo "$RESPONSE" | grep -q "incorrectly configured"; then
        echo "❌ Still seeing configuration error. Check the server logs."
        echo "Response: $RESPONSE"
    else
        echo "⚠️  Got response: $RESPONSE"
    fi
else
    echo "❌ Server failed to start. Check the logs above."
    exit 1
fi

