# How to Start the Backend

The health check is failing because the backend server is not running.

## Quick Start:

1. Open Terminal
2. Navigate to backend folder:
   ```bash
   cd "/Users/mishadzhuran/My projects/ANITA backend"
   ```

3. Start the backend:
   ```bash
   npm run dev
   ```

4. You should see:
   ```
   🚀 ANITA Backend API Server
      Running on http://localhost:3001
      ✅ All required environment variables are set
   ```

5. Then test the health check in iOS app again

## Important Notes:

### If testing on iOS Simulator:
- `http://localhost:3001` should work fine

### If testing on Physical Device:
- `localhost` won't work - you need your computer's IP address
- Find your Mac's IP: System Settings → Network → Wi-Fi → IP Address
- Or run: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Use: `http://YOUR_IP_ADDRESS:3001` (e.g., `http://192.168.1.100:3001`)
- Update the Backend URL in iOS Settings

## Troubleshooting:

- **Port already in use**: Kill the process: `lsof -ti:3001 | xargs kill`
- **Missing .env file**: Make sure `.env` exists in backend folder with all keys
- **Module not found**: Run `npm install` first

