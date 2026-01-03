#!/bin/bash

#
# Setup Google Client ID for iOS from Webapp Configuration
#

echo "═══════════════════════════════════════════════════════════"
echo "  Google Client ID Setup for iOS"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Get Web Client ID from Supabase Dashboard${NC}"
echo ""
echo "1. Go to: https://app.supabase.com/"
echo "2. Select project: ANITA"
echo "3. Go to: Authentication → Providers → Google"
echo "4. Copy the Client ID shown there"
echo ""
read -p "Enter your Web Client ID (or press Enter to skip): " WEB_CLIENT_ID

if [ -z "$WEB_CLIENT_ID" ]; then
    echo -e "${YELLOW}Skipping Web Client ID check...${NC}"
else
    echo -e "${GREEN}✓ Web Client ID received${NC}"
    echo ""
    echo "This helps us identify your Google Cloud project."
    echo "Now you need to create an iOS OAuth Client ID in the same project."
fi

echo ""
echo -e "${YELLOW}Step 2: Create iOS OAuth Client ID${NC}"
echo ""
echo "1. Go to: https://console.cloud.google.com/"
echo "2. Find the project that contains your Web Client ID"
echo "3. Go to: APIs & Services → Credentials"
echo "4. Click: + CREATE CREDENTIALS → OAuth client ID"
echo "5. Select: iOS (NOT Web!)"
echo "6. Bundle ID: com.anita.app"
echo "7. Copy the iOS Client ID"
echo ""
read -p "Enter your iOS Client ID: " IOS_CLIENT_ID

if [ -z "$IOS_CLIENT_ID" ]; then
    echo -e "${RED}❌ iOS Client ID is required!${NC}"
    exit 1
fi

# Validate format
if [[ ! $IOS_CLIENT_ID =~ ^[0-9]+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$ ]]; then
    echo -e "${RED}❌ Invalid Client ID format!${NC}"
    echo "Expected format: 123456789-abc123def456.apps.googleusercontent.com"
    exit 1
fi

echo -e "${GREEN}✓ iOS Client ID format is valid${NC}"

# Calculate reversed Client ID
REVERSED=$(echo "$IOS_CLIENT_ID" | awk -F. '{for(i=NF;i>0;i--) printf "%s%s", $i, (i>1?".":"")}')

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Configuration Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "iOS Client ID:"
echo "  $IOS_CLIENT_ID"
echo ""
echo "Reversed Client ID (for Info.plist):"
echo "  $REVERSED"
echo ""

# Update Config.swift
CONFIG_FILE="ANITA/Utils/Config.swift"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Updating Config.swift...${NC}"
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    # Replace the empty string with the Client ID
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|return \"\"|return \"$IOS_CLIENT_ID\"|g" "$CONFIG_FILE"
    else
        # Linux
        sed -i "s|return \"\"|return \"$IOS_CLIENT_ID\"|g" "$CONFIG_FILE"
    fi
    
    echo -e "${GREEN}✓ Config.swift updated${NC}"
    echo "  Backup saved to: ${CONFIG_FILE}.backup"
else
    echo -e "${RED}❌ Config.swift not found at: $CONFIG_FILE${NC}"
    echo "Please update it manually:"
    echo "  return \"$IOS_CLIENT_ID\""
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Next Steps"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "1. ✅ Config.swift has been updated"
echo ""
echo "2. ⚠️  You still need to add reversed Client ID to Info.plist:"
echo "   Open ANITA/Info.plist in Xcode"
echo "   Add to CFBundleURLSchemes array:"
echo "   <string>$REVERSED</string>"
echo ""
echo "3. Build and test the app!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

