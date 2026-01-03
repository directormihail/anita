#!/bin/bash

#
# Complete Google Sign-In Configuration Script
# This script will help you configure Google Sign-In for iOS
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Google Sign-In Configuration for iOS"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if we're in the right directory
if [ ! -f "ANITA/Utils/Config.swift" ]; then
    echo -e "${RED}❌ Error: Config.swift not found${NC}"
    echo "Please run this script from the 'ANITA IOS' directory"
    exit 1
fi

echo -e "${BLUE}Step 1: Getting iOS OAuth Client ID${NC}"
echo ""
echo "You need an iOS OAuth Client ID from Google Cloud Console."
echo ""
echo "To get it:"
echo "1. Go to: https://console.cloud.google.com/"
echo "2. Find your project (the one with your webapp's Web Client ID)"
echo "3. Go to: APIs & Services → Credentials"
echo "4. Click: + CREATE CREDENTIALS → OAuth client ID"
echo "5. Select: iOS (NOT Web!)"
echo "6. Bundle ID: com.anita.app"
echo "7. Copy the Client ID"
echo ""
read -p "Enter your iOS OAuth Client ID: " IOS_CLIENT_ID

if [ -z "$IOS_CLIENT_ID" ]; then
    echo -e "${RED}❌ Client ID is required!${NC}"
    exit 1
fi

# Validate format
if [[ ! $IOS_CLIENT_ID =~ ^[0-9]+-[a-zA-Z0-9]+\.apps\.googleusercontent\.com$ ]]; then
    echo -e "${RED}❌ Invalid Client ID format!${NC}"
    echo "Expected format: 123456789-abc123def456.apps.googleusercontent.com"
    exit 1
fi

echo -e "${GREEN}✅ Client ID format is valid${NC}"

# Calculate reversed Client ID
REVERSED=$(echo "$IOS_CLIENT_ID" | awk -F. '{for(i=NF;i>0;i--) printf "%s%s", $i, (i>1?".":"")}')

echo ""
echo -e "${BLUE}Step 2: Updating Config.swift${NC}"

# Create backup
cp "ANITA/Utils/Config.swift" "ANITA/Utils/Config.swift.backup"
echo "  ✅ Backup created: Config.swift.backup"

# Update Config.swift
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|return \"\"|return \"$IOS_CLIENT_ID\"|g" "ANITA/Utils/Config.swift"
else
    # Linux
    sed -i "s|return \"\"|return \"$IOS_CLIENT_ID\"|g" "ANITA/Utils/Config.swift"
fi

echo -e "${GREEN}  ✅ Config.swift updated${NC}"

echo ""
echo -e "${BLUE}Step 3: Updating Info.plist${NC}"

# Check if reversed Client ID already exists
if grep -q "$REVERSED" "ANITA/Info.plist" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠️  Reversed Client ID already exists in Info.plist${NC}"
else
    # Create backup
    cp "ANITA/Info.plist" "ANITA/Info.plist.backup"
    echo "  ✅ Backup created: Info.plist.backup"
    
    # Add reversed Client ID to Info.plist
    # Find the line with </array> after CFBundleURLSchemes and add before it
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use perl for better XML handling
        perl -i -pe "s|(<string>anita</string>)|\$1\n\t\t\t\t<string>$REVERSED</string>|" "ANITA/Info.plist"
    else
        # Linux
        sed -i "/<string>anita<\/string>/a\\\t\t\t\t<string>$REVERSED</string>" "ANITA/Info.plist"
    fi
    
    echo -e "${GREEN}  ✅ Info.plist updated with reversed Client ID${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✅ Configuration Complete!${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Configuration Summary:"
echo "  iOS Client ID: $IOS_CLIENT_ID"
echo "  Reversed Client ID: $REVERSED"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode"
echo "2. Build and run the app"
echo "3. Try Google Sign-In - it should work!"
echo ""
echo "Backups created:"
echo "  - ANITA/Utils/Config.swift.backup"
echo "  - ANITA/Info.plist.backup"
echo ""

