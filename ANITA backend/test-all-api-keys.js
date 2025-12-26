#!/usr/bin/env node

/**
 * Comprehensive API Key Testing Script for iOS
 * Tests all API keys and configurations needed for iOS app to work
 */

const { config } = require('dotenv');
config();
const https = require('https');
const http = require('http');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const openaiApiKey = process.env.OPENAI_API_KEY;
const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
const backendPort = process.env.PORT || 3001;
const backendUrl = `http://localhost:${backendPort}`;

// iOS Config values (from Config.swift)
const iosSupabaseUrl = 'https://kezregiqfxlrvaxytdet.supabase.co';
const iosSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlenJlZ2lxZnhscnZheHl0ZGV0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2OTY5MTgsImV4cCI6MjA3MzI3MjkxOH0.X4QWu0W31Kv_8KGQ6h_n4PYnQOMTX85CYbWJVbv2AxM';
const iosBackendUrl = 'http://localhost:3001';

console.log('\n🧪 Testing All API Keys for iOS App\n');
console.log('='.repeat(60));

let allTestsPassed = true;
const testResults = [];

// Helper function to make HTTP requests
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const isHttps = urlObj.protocol === 'https:';
    const client = isHttps ? https : http;
    
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || (isHttps ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: options.headers || {}
    };

    const req = client.request(requestOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', reject);
    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

// Test function wrapper
async function runTest(name, testFn) {
  process.stdout.write(`\n🔍 Testing: ${name}... `);
  try {
    const result = await testFn();
    if (result.success) {
      console.log('✅ PASS');
      testResults.push({ name, status: 'PASS', message: result.message });
      return true;
    } else {
      console.log('❌ FAIL');
      console.log(`   ${result.message}`);
      testResults.push({ name, status: 'FAIL', message: result.message });
      allTestsPassed = false;
      return false;
    }
  } catch (error) {
    console.log('❌ ERROR');
    console.log(`   ${error.message}`);
    testResults.push({ name, status: 'ERROR', message: error.message });
    allTestsPassed = false;
    return false;
  }
}

// Test 1: Backend Environment Variables
await runTest('Backend SUPABASE_URL', () => {
  if (!supabaseUrl) {
    return { success: false, message: 'Missing SUPABASE_URL' };
  }
  if (supabaseUrl.includes('YOUR_') || supabaseUrl.includes('placeholder')) {
    return { success: false, message: 'SUPABASE_URL is a placeholder' };
  }
  if (supabaseUrl !== iosSupabaseUrl) {
    return { success: false, message: `Backend URL (${supabaseUrl}) doesn't match iOS URL (${iosSupabaseUrl})` };
  }
  return { success: true, message: `Configured: ${supabaseUrl}` };
});

await runTest('Backend SUPABASE_SERVICE_ROLE_KEY', () => {
  if (!supabaseServiceKey) {
    return { success: false, message: 'Missing SUPABASE_SERVICE_ROLE_KEY - This is critical!' };
  }
  if (supabaseServiceKey.includes('YOUR_') || supabaseServiceKey.includes('placeholder')) {
    return { success: false, message: 'SUPABASE_SERVICE_ROLE_KEY is a placeholder' };
  }
  if (!supabaseServiceKey.startsWith('eyJ')) {
    return { success: false, message: 'Service key format looks incorrect (should start with eyJ)' };
  }
  // Check if it's the service_role key (not anon)
  try {
    const payload = JSON.parse(Buffer.from(supabaseServiceKey.split('.')[1], 'base64').toString());
    if (payload.role !== 'service_role') {
      return { success: false, message: 'Key is not a service_role key (found role: ' + payload.role + ')' };
    }
  } catch (e) {
    // Can't decode, but format looks OK
  }
  return { success: true, message: 'Service role key configured correctly' };
});

await runTest('Backend OPENAI_API_KEY', () => {
  if (!openaiApiKey) {
    return { success: false, message: 'Missing OPENAI_API_KEY - Chat won\'t work!' };
  }
  if (openaiApiKey.includes('YOUR_') || openaiApiKey.includes('placeholder') || openaiApiKey.includes('sk-')) {
    if (openaiApiKey.includes('YOUR_') || openaiApiKey.includes('placeholder')) {
      return { success: false, message: 'OPENAI_API_KEY is a placeholder' };
    }
  }
  if (!openaiApiKey.startsWith('sk-')) {
    return { success: false, message: 'OpenAI key format looks incorrect (should start with sk-)' };
  }
  return { success: true, message: 'OpenAI API key configured' };
});

await runTest('Backend STRIPE_SECRET_KEY', () => {
  if (!stripeSecretKey) {
    return { success: false, message: 'Missing STRIPE_SECRET_KEY - Checkout won\'t work (optional for chat)' };
  }
  if (stripeSecretKey.includes('YOUR_') || stripeSecretKey.includes('placeholder')) {
    return { success: false, message: 'STRIPE_SECRET_KEY is a placeholder' };
  }
  return { success: true, message: 'Stripe key configured' };
});

// Test 2: iOS Configuration
console.log('\n📱 iOS App Configuration:');
await runTest('iOS Supabase URL matches backend', () => {
  if (iosSupabaseUrl !== supabaseUrl) {
    return { success: false, message: `iOS URL (${iosSupabaseUrl}) doesn't match backend (${supabaseUrl})` };
  }
  return { success: true, message: 'URLs match' };
});

await runTest('iOS Supabase Anon Key format', () => {
  if (!iosSupabaseAnonKey.startsWith('eyJ')) {
    return { success: false, message: 'iOS anon key format looks incorrect' };
  }
  try {
    const payload = JSON.parse(Buffer.from(iosSupabaseAnonKey.split('.')[1], 'base64').toString());
    if (payload.role !== 'anon') {
      return { success: false, message: 'iOS key is not an anon key (found role: ' + payload.role + ')' };
    }
  } catch (e) {
    // Can't decode, but format looks OK
  }
  return { success: true, message: 'iOS anon key format is correct' };
});

// Test 3: Supabase Connection Tests
console.log('\n🔌 Supabase Connection Tests:');
await runTest('Supabase Health Check (with service key)', async () => {
  try {
    const response = await makeRequest(`${supabaseUrl}/auth/v1/health`, {
      method: 'GET',
      headers: {
        'apikey': supabaseServiceKey,
        'Authorization': `Bearer ${supabaseServiceKey}`
      }
    });
    if (response.statusCode === 200) {
      return { success: true, message: 'Supabase is reachable with service key' };
    } else {
      return { success: false, message: `Supabase returned status ${response.statusCode}` };
    }
  } catch (error) {
    return { success: false, message: `Connection failed: ${error.message}` };
  }
});

await runTest('Supabase Health Check (with anon key)', async () => {
  try {
    const response = await makeRequest(`${supabaseUrl}/auth/v1/health`, {
      method: 'GET',
      headers: {
        'apikey': iosSupabaseAnonKey
      }
    });
    if (response.statusCode === 200) {
      return { success: true, message: 'Supabase is reachable with anon key' };
    } else {
      return { success: false, message: `Supabase returned status ${response.statusCode}` };
    }
  } catch (error) {
    return { success: false, message: `Connection failed: ${error.message}` };
  }
});

// Test 4: Backend Server Tests
console.log('\n🖥️  Backend Server Tests:');
await runTest('Backend server is running', async () => {
  try {
    const response = await makeRequest(`${backendUrl}/health`);
    if (response.statusCode === 200) {
      const health = JSON.parse(response.body);
      return { success: true, message: `Backend is running (${health.status})` };
    } else {
      return { success: false, message: `Backend returned status ${response.statusCode}` };
    }
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      return { success: false, message: 'Backend server is not running. Start it with: npm start' };
    }
    return { success: false, message: `Connection failed: ${error.message}` };
  }
});

await runTest('Backend create-conversation endpoint (test)', async () => {
  try {
    const response = await makeRequest(`${backendUrl}/api/v1/create-conversation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        userId: 'test-user-' + Date.now(),
        title: 'Test Conversation'
      })
    });
    
    if (response.statusCode === 200) {
      const data = JSON.parse(response.body);
      if (data.success && data.conversation) {
        return { success: true, message: 'Create conversation endpoint works!' };
      } else {
        return { success: false, message: 'Endpoint returned success but no conversation data' };
      }
    } else {
      const error = JSON.parse(response.body);
      if (error.message && error.message.includes('Invalid API key')) {
        return { success: false, message: '❌ Invalid API key error - Check SUPABASE_SERVICE_ROLE_KEY' };
      }
      return { success: false, message: `Endpoint returned status ${response.statusCode}: ${error.message || error.error}` };
    }
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      return { success: false, message: 'Backend server is not running' };
    }
    return { success: false, message: `Request failed: ${error.message}` };
  }
});

// Test 5: OpenAI API Test (if key is set)
if (openaiApiKey && openaiApiKey.startsWith('sk-')) {
  console.log('\n🤖 OpenAI API Test:');
  await runTest('OpenAI API key validity', async () => {
    try {
      const response = await makeRequest('https://api.openai.com/v1/models', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`
        }
      });
      
      if (response.statusCode === 200) {
        return { success: true, message: 'OpenAI API key is valid' };
      } else if (response.statusCode === 401) {
        return { success: false, message: 'OpenAI API key is invalid or expired' };
      } else {
        return { success: false, message: `OpenAI returned status ${response.statusCode}` };
      }
    } catch (error) {
      return { success: false, message: `OpenAI test failed: ${error.message}` };
    }
  });
}

// Summary
console.log('\n' + '='.repeat(60));
console.log('\n📊 Test Summary:\n');

const passed = testResults.filter(r => r.status === 'PASS').length;
const failed = testResults.filter(r => r.status === 'FAIL' || r.status === 'ERROR').length;

testResults.forEach(result => {
  const icon = result.status === 'PASS' ? '✅' : '❌';
  console.log(`${icon} ${result.name}`);
  if (result.status !== 'PASS') {
    console.log(`   ${result.message}`);
  }
});

console.log(`\n✅ Passed: ${passed}`);
console.log(`❌ Failed: ${failed}`);

if (allTestsPassed) {
  console.log('\n🎉 All tests passed! Your iOS app should work correctly.\n');
  process.exit(0);
} else {
  console.log('\n⚠️  Some tests failed. Please fix the issues above.\n');
  console.log('Quick fixes:');
  console.log('1. If SUPABASE_SERVICE_ROLE_KEY is missing/invalid:');
  console.log('   - Go to https://app.supabase.com → Settings → API');
  console.log('   - Copy the service_role key (not anon key)');
  console.log('   - Update .env file and restart backend');
  console.log('2. If backend is not running:');
  console.log('   - cd "ANITA backend" && npm start');
  console.log('3. If OpenAI key is missing:');
  console.log('   - Get key from https://platform.openai.com/api-keys');
  console.log('   - Add OPENAI_API_KEY to .env file\n');
  process.exit(1);
}

