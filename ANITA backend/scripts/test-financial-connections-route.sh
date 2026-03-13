#!/usr/bin/env bash
# Test POST /api/v1/financial-connections/session (run backend first: npm run dev)
# Usage: ./scripts/test-financial-connections-route.sh [BASE_URL]
# Example: ./scripts/test-financial-connections-route.sh http://localhost:3001

set -e
BASE_URL="${1:-http://localhost:3001}"
# Use a test UUID; backend will create Stripe customer if needed
USER_ID="${2:-00000000-0000-0000-0000-000000000001}"
echo "Testing financial-connections route at $BASE_URL (userId=$USER_ID)"
echo ""

for i in 1 2; do
  echo "--- Request $i ---"
  HTTP=$(curl -s -w "%{http_code}" -o /tmp/fc_response.json -X POST "$BASE_URL/api/v1/financial-connections/session" \
    -H "Content-Type: application/json" \
    -d "{\"userId\":\"$USER_ID\",\"userEmail\":\"test@example.com\"}")
  echo "HTTP status: $HTTP"
  if command -v jq &>/dev/null; then
    jq . /tmp/fc_response.json 2>/dev/null || cat /tmp/fc_response.json
  else
    cat /tmp/fc_response.json
  fi
  echo ""
  if [ "$HTTP" = "200" ]; then
    if grep -q client_secret /tmp/fc_response.json 2>/dev/null; then
      echo "OK: Got client_secret (Stripe session created)."
    else
      echo "WARN: 200 but no client_secret in response."
    fi
  elif [ "$HTTP" = "404" ]; then
    echo "FAIL: Route not found. Deploy the latest backend so it includes POST /api/v1/financial-connections/session."
    exit 1
  elif [ "$HTTP" = "500" ]; then
    if grep -q "Stripe is not configured" /tmp/fc_response.json 2>/dev/null; then
      echo "Route OK; backend needs STRIPE_SECRET_KEY in .env (or Railway) to return client_secret."
    else
      echo "Server error (500). Check backend logs and .env (STRIPE_SECRET_KEY, Supabase)."
    fi
  else
    echo "HTTP $HTTP – check backend and request body (userId required)."
  fi
done
echo "Done (2 requests)."
