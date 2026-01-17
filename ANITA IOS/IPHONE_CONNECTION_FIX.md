# iPhone Connection Fix Guide

## Problem
When running the app on a physical iPhone, it can't connect to the backend server because `localhost` only refers to the device itself, not your Mac.

## Solution

### Step 1: Find Your Mac's IP Address
Your Mac's IP address is: **192.168.178.45**

To find it manually:
1. Open **System Settings** → **Network**
2. Select your active connection (Wi-Fi or Ethernet)
3. Note the IP address (e.g., `192.168.178.45`)

Or use Terminal:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### Step 2: Make Sure Backend is Running
```bash
cd "ANITA backend"
npm run dev
```

You should see:
```
🚀 ANITA Backend API Server
   Running on http://localhost:3001
   ✅ Ready for iOS app!
```

### Step 3: Update Backend URL in App Settings

1. **Open the ANITA app on your iPhone**
2. **Go to Settings** (gear icon in bottom navigation)
3. **Scroll down to "DEVELOPMENT" section**
4. **Tap "Backend URL"**
5. **Enter your Mac's IP address with port 3001:**
   ```
   http://192.168.178.45:3001
   ```
6. **Tap "Save"**

### Step 4: Verify Connection

1. Make sure your **iPhone and Mac are on the same Wi-Fi network**
2. Try using the app - it should now connect to your backend!

## Troubleshooting

### Still can't connect?

1. **Check Firewall:**
   - System Settings → Network → Firewall
   - Make sure port 3001 is allowed, or temporarily disable firewall to test

2. **Verify Backend is Running:**
   ```bash
   curl http://localhost:3001/health
   ```
   Should return: `{"status":"ok",...}`

3. **Test from iPhone:**
   - Open Safari on iPhone
   - Go to: `http://192.168.178.45:3001/health`
   - Should see the health check response

4. **Check Network:**
   - Both devices must be on the same Wi-Fi network
   - Try disconnecting and reconnecting both devices

5. **IP Address Changed?**
   - If your Mac's IP address changes, update it in Settings again
   - You can find the current IP using the command in Step 1

## For iOS Simulator
If using the iOS Simulator (on your Mac), use:
```
http://localhost:3001
```

## Quick Reference

- **Mac IP Address:** 192.168.178.45
- **Backend URL for iPhone:** http://192.168.178.45:3001
- **Backend URL for Simulator:** http://localhost:3001
- **Backend Port:** 3001
