# iOS Chat Troubleshooting Guide

## Common Issues and Solutions

### Issue: Cannot start conversation in iOS chat

#### 1. Backend Not Running
**Problem**: The backend server is not running on port 3001.

**Solution**:
```bash
cd "ANITA backend"
npm install  # if needed
npm run build  # if needed
npm start
# or
node dist/index.js
```

You should see:
```
🚀 ANITA Backend API Server
   Running on http://localhost:3001
```

#### 2. Backend URL Configuration
**Problem**: iOS app cannot reach the backend server.

**For iOS Simulator**:
- Use: `http://localhost:3001`
- This works because the simulator runs on your Mac

**For Physical iOS Device**:
- You CANNOT use `localhost` or `127.0.0.1`
- You need your Mac's local IP address

**To find your Mac's IP address**:
1. Open System Settings → Network
2. Find your active connection (Wi-Fi or Ethernet)
3. Note the IP address (e.g., `192.168.1.100`)
4. Use: `http://192.168.1.100:3001` (replace with your actual IP)

**To configure in iOS app**:
1. Open the ANITA iOS app
2. Go to Settings
3. Find "Backend URL" section
4. Enter your backend URL (e.g., `http://192.168.1.100:3001`)
5. Tap "Save URL"
6. Test the connection

#### 3. Network/Firewall Issues
**Problem**: Device and backend are on different networks or firewall is blocking.

**Solutions**:
- Ensure both your Mac and iOS device are on the same Wi-Fi network
- Check macOS Firewall settings (System Settings → Network → Firewall)
- Temporarily disable firewall to test, then re-enable with proper rules

#### 4. Backend Environment Variables
**Problem**: Backend .env file is missing or has incorrect values.

**Verify**:
- `.env` file exists in `ANITA backend/` directory
- Contains all required variables:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `OPENAI_API_KEY`
  - `STRIPE_SECRET_KEY`
  - `PORT=3001`

#### 5. CORS Issues
**Problem**: Backend is rejecting requests from iOS app.

**Solution**: 
- Check that `ALLOWED_ORIGINS=*` in `.env` (allows all origins)
- Or set specific origins if needed

#### 6. Supabase Configuration
**Problem**: Backend cannot connect to Supabase.

**Verify**:
- `SUPABASE_URL` is correct
- `SUPABASE_SERVICE_ROLE_KEY` is the service_role key (not anon key)
- Service role key has proper permissions in Supabase

## Testing the Connection

### From iOS App:
1. Open Settings in the app
2. Check "Connection Status"
3. Tap "Test Backend Connection"
4. Should show "✅ Connected" if working

### From Terminal:
```bash
# Test health endpoint
curl http://localhost:3001/health

# Should return:
# {"status":"ok","timestamp":"...","service":"ANITA Backend API","version":"1.0.0"}
```

### From iOS Simulator/Device:
1. Open Safari
2. Navigate to: `http://YOUR_BACKEND_URL/health`
3. Should see JSON response

## Debugging Steps

1. **Check Backend Logs**:
   - Look at terminal where backend is running
   - Check for error messages
   - Look for request logs

2. **Check iOS Console**:
   - In Xcode, open Console
   - Filter by "ChatViewModel" or "NetworkService"
   - Look for error messages

3. **Test Backend Directly**:
   ```bash
   # Test create conversation
   curl -X POST http://localhost:3001/api/v1/create-conversation \
     -H "Content-Type: application/json" \
     -d '{"userId":"test-user-123","title":"Test Conversation"}'
   ```

4. **Verify User ID**:
   - iOS app generates a UUID for userId if not authenticated
   - Check that userId is being sent in requests
   - Look in Xcode console for userId logs

## Quick Fix Checklist

- [ ] Backend is running (`npm start` in backend directory)
- [ ] Backend URL is correct in iOS Settings
- [ ] Device and Mac are on same network (for physical device)
- [ ] `.env` file exists with all required variables
- [ ] Backend health check works (`/health` endpoint)
- [ ] No firewall blocking port 3001
- [ ] Supabase credentials are correct

## Still Having Issues?

1. Check Xcode console for detailed error messages
2. Check backend terminal for request logs
3. Verify all environment variables are set correctly
4. Test backend endpoints directly with curl
5. Ensure Supabase tables exist (conversations, anita_data)

