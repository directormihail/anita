#!/usr/bin/env bash
# Opens Supabase Dashboard → Auth → Providers → Google so you can enable "Skip nonce check".
# Required to fix: "Passed nonce and nonce in id_token should either both exist or not" on iOS.
set -e
URL="https://supabase.com/dashboard/project/kezregiqfxlrvaxytdet/auth/providers"
echo "Opening: $URL"
echo "Then: turn ON 'Skip nonce check' for Google and click Save."
if command -v open >/dev/null 2>&1; then
  open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL"
else
  echo "Open this URL in your browser: $URL"
fi
