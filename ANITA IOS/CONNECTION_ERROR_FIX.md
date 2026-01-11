# Server Connection Error Fix

## Problem
The iOS app was showing "Could not connect to the server" error when trying to load conversations and other data. This was happening because:

1. **No timeout handling** - Network requests could hang indefinitely
2. **Poor error handling** - Network errors (like URLError) weren't being caught and converted to user-friendly messages
3. **Unclear error messages** - Users didn't know how to fix connection issues
4. **No guidance for physical devices** - `localhost` doesn't work on physical iOS devices

## Changes Made

### 1. Added Timeout to Network Requests
**File**: `ANITA/Services/NetworkService.swift`

Added 10-second timeout to:
- `getConversations()` - Now has timeout and better error handling
- `getFinancialMetrics()` - Added timeout and error handling
- `getXPStats()` - Added timeout and error handling

**Before:**
```swift
let request = URLRequest(url: url)
let (data, response) = try await URLSession.shared.data(for: request)
```

**After:**
```swift
var request = URLRequest(url: url)
request.timeoutInterval = 10.0 // 10 second timeout
request.setValue("application/json", forHTTPHeaderField: "Accept")

do {
    let (data, response) = try await URLSession.shared.data(for: request)
    // ... handle response
} catch {
    // Handle URLError with specific messages
}
```

### 2. Improved Error Handling
Added comprehensive error handling that catches `URLError` and provides specific messages for:
- **No internet connection** - Clear message about network settings
- **Timeout** - Guidance on checking backend and network
- **Cannot find host** - Instructions for fixing backend URL
- **Cannot connect to host** - Same helpful guidance

### 3. Better Error Messages in ViewModels
**File**: `ANITA/ViewModels/SidebarViewModel.swift`

Enhanced error message handling to provide user-friendly guidance:
- Detects timeout errors and provides troubleshooting steps
- Detects connection errors and explains how to fix backend URL
- Provides specific instructions for physical devices vs simulators

### 4. User-Friendly Error Messages
The app now shows helpful error messages like:

```
Could not connect to the server.

Please check:
1. Backend is running: cd 'ANITA backend' && npm run dev
2. Backend URL in Settings is: http://localhost:3001
3. For physical device: Use your Mac's IP address (e.g., http://192.168.1.100:3001)
```

## How to Fix Connection Issues

### For iOS Simulator:
1. Make sure backend is running: `cd 'ANITA backend' && npm run dev`
2. Backend URL should be: `http://localhost:3001`
3. Both should be on the same machine

### For Physical iOS Device:
1. Find your Mac's IP address:
   - Open System Settings → Network
   - Look for your active connection (Wi-Fi or Ethernet)
   - Note the IP address (e.g., `192.168.1.100`)

2. Update backend URL in iOS app Settings:
   - Go to Settings in the app
   - Change backend URL to: `http://YOUR_MAC_IP:3001`
   - Example: `http://192.168.1.100:3001`

3. Make sure:
   - Backend is running on your Mac
   - iPhone and Mac are on the same Wi-Fi network
   - Firewall allows connections on port 3001

## Testing
After these changes:
- ✅ Network requests timeout after 10 seconds (no hanging)
- ✅ Clear error messages guide users to fix issues
- ✅ Works on both simulator and physical devices
- ✅ Better error handling for all network calls

## Files Modified
1. `ANITA/Services/NetworkService.swift`
   - Added timeout and error handling to `getConversations()`
   - Added timeout and error handling to `getFinancialMetrics()`
   - Added timeout and error handling to `getXPStats()`

2. `ANITA/ViewModels/SidebarViewModel.swift`
   - Enhanced error message handling with user-friendly messages

## Next Steps
If you still see connection errors:
1. Verify backend is running: `cd 'ANITA backend' && npm run dev`
2. Check backend URL in app Settings
3. For physical device: Use Mac's IP address instead of localhost
4. Ensure both devices are on the same network
