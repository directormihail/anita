# Quick Start: iOS Chat Fix

## What Was Fixed

1. ✅ **Improved Error Handling**: ChatViewModel now shows clear error messages when connection fails
2. ✅ **Connection Testing**: App now checks backend connection before sending messages
3. ✅ **Better Error Display**: Error messages are now more visible in the chat UI
4. ✅ **Enhanced Logging**: Added detailed logging to help debug issues

## Steps to Get Chat Working

### 1. Start the Backend Server

```bash
cd "ANITA backend"
npm start
```

You should see:
```
🚀 ANITA Backend API Server
   Running on http://localhost:3001
   ✅ All required environment variables are set
```

### 2. Configure Backend URL in iOS App

**If using iOS Simulator:**
- Backend URL should be: `http://localhost:3001`
- This is already the default

**If using Physical iOS Device:**
- Find your Mac's IP address:
  - System Settings → Network → Wi-Fi/Ethernet
  - Note the IP (e.g., `192.168.1.100`)
- In iOS app: Settings → Backend URL → Enter `http://192.168.1.100:3001`
- Tap "Save URL"

### 3. Test the Connection

1. Open iOS app
2. Go to Settings
3. Tap "Test Backend Connection"
4. Should show "✅ Connected"

### 4. Start a Conversation

1. Go to Chat tab
2. Type a message (e.g., "Hello")
3. Tap send button
4. If there's an error, it will show clearly with helpful instructions

## Common Issues

### "Cannot connect to backend"
- **Check**: Backend is running (`npm start`)
- **Check**: Backend URL is correct in Settings
- **Check**: Device and Mac are on same network (for physical device)

### "Failed to create conversation"
- **Check**: Backend .env file has correct Supabase credentials
- **Check**: Supabase service role key is set (not anon key)
- **Check**: Backend logs for specific error

### "Request timed out"
- **Check**: Internet connection
- **Check**: OpenAI API key is valid in .env
- **Check**: Backend can reach OpenAI API

## Debugging

### Check Backend Logs
Look at the terminal where backend is running for error messages.

### Check iOS Console
1. Open Xcode
2. Window → Devices and Simulators
3. Select your device
4. Click "Open Console"
5. Filter by "ChatViewModel" to see detailed logs

### Test Backend Directly
```bash
# Test health endpoint
curl http://localhost:3001/health

# Should return JSON with status: "ok"
```

## Next Steps

1. ✅ Backend is running
2. ✅ Backend URL is configured in iOS app
3. ✅ Connection test passes
4. ✅ Try sending a message in chat

If you still have issues, check `IOS_CHAT_TROUBLESHOOTING.md` for detailed troubleshooting.

