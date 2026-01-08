# Test and Verify Backend Connection

## Quick Test Steps

### 1. Start the Backend Server

```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
npm run dev
```

You should see:
```
🚀 ANITA Backend API Server
   Running on http://localhost:3001
   ✅ All required environment variables are set
```

### 2. Test Backend Health

In a new terminal:
```bash
curl http://localhost:3001/health
```

Should return:
```json
{"status":"ok","timestamp":"...","service":"ANITA Backend API","version":"1.0.0"}
```

### 3. Add Sample Data

```bash
cd "/Users/mishadzhuran/My projects/ANITA backend"
node test-and-setup.js
```

This will:
- ✅ Test Supabase connection
- ✅ Add sample transactions
- ✅ Add sample targets/goals
- ✅ Add sample assets

### 4. Test API Endpoints

```bash
# Test targets
curl "http://localhost:3001/api/v1/targets?userId=default-user"

# Test transactions
curl "http://localhost:3001/api/v1/transactions?userId=default-user"

# Test assets
curl "http://localhost:3001/api/v1/assets?userId=default-user"

# Test financial metrics
curl "http://localhost:3001/api/v1/financial-metrics?userId=default-user"
```

### 5. Configure iOS App

1. **For Simulator**: Use `http://localhost:3001`
2. **For Physical Device**: 
   - Find your Mac's IP address:
     ```bash
     ifconfig | grep "inet " | grep -v 127.0.0.1
     ```
   - Use `http://YOUR_MAC_IP:3001` (e.g., `http://192.168.1.100:3001`)

3. In iOS app Settings, set the backend URL

## Troubleshooting

### "Could not connect to the server"

1. **Check backend is running**:
   ```bash
   curl http://localhost:3001/health
   ```

2. **Check backend URL in iOS app**:
   - Settings → Backend URL should be `http://localhost:3001` (simulator)
   - Or your Mac's IP address (physical device)

3. **Check firewall**: Make sure port 3001 is not blocked

4. **Check network**: Device and Mac must be on same network (for physical device)

### "No data showing"

1. **Run test setup script**:
   ```bash
   node test-and-setup.js
   ```

2. **Check data in Supabase**:
   - Go to Supabase dashboard
   - Check `anita_data` table for transactions
   - Check `targets` table for goals
   - Check `assets` table for assets

3. **Verify userId**: Make sure you're using `default-user` or your actual user ID

### Backend won't start

1. **Check dependencies**:
   ```bash
   npm install
   ```

2. **Check .env file**:
   ```bash
   cat .env
   ```
   Should have:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `OPENAI_API_KEY`
   - `STRIPE_SECRET_KEY`

3. **Check port 3001 is free**:
   ```bash
   lsof -ti:3001 | xargs kill -9
   ```

## Expected Results

After running `test-and-setup.js`, you should have:

- **5 transactions** (2 income, 3 expenses)
- **4 targets/goals** (Emergency Fund, Vacation Fund, Transportation Budget, Food Budget)
- **2 assets** (Savings Account, Checking Account)

The iOS app should display:
- Total Balance
- Monthly Income/Expenses
- Recent Transactions
- Goals/Targets
- Assets

## Next Steps

1. ✅ Backend running on port 3001
2. ✅ Sample data added
3. ✅ iOS app configured with correct backend URL
4. ✅ Test the app - you should see all data!
