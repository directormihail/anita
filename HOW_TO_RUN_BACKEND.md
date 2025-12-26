# How to Run Backend Server

## Option 1: Terminal (Recommended)

1. Open **Terminal** app on your Mac
2. Run:
   ```bash
   cd "/Users/mishadzhuran/My projects/ANITA backend"
   npm run dev
   ```
3. You should see:
   ```
   🚀 ANITA Backend API Server
      Running on http://localhost:3001
      ✅ All required environment variables are set
   ```
4. Keep this terminal window open - the server runs in the foreground
5. Press `Ctrl+C` to stop the server

## Option 2: Using the Script

I've created a startup script for you:

```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
./start-backend.sh
```

## Option 3: Xcode (Not Recommended)

Xcode is for iOS development, not for running Node.js servers. You need to use Terminal.

However, you CAN add a "Run Script" in Xcode to start the backend automatically:

1. In Xcode, go to your iOS app target
2. Build Phases → + → New Run Script Phase
3. Add this script:
   ```bash
   cd "${SRCROOT}/../ANITA backend"
   npm run dev &
   ```

But this is not recommended because:
- The server needs to keep running
- It's better to run it separately in Terminal
- You'll see server logs better in Terminal

## Quick Start (One-time setup)

If you haven't installed dependencies yet:

```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm install
npm run dev
```

## Verify It's Running

Once started, test it:
```bash
curl http://localhost:3001/health
```

Should return:
```json
{"status":"ok","timestamp":"...","service":"ANITA Backend API","version":"1.0.0"}
```

## Troubleshooting

- **Port 3001 already in use**: 
  ```bash
  lsof -ti:3001 | xargs kill
  ```

- **Missing .env file**: Make sure `.env` exists with all keys

- **Module not found**: Run `npm install` first

