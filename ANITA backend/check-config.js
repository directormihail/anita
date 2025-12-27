#!/usr/bin/env node

/**
 * Quick script to check if Supabase is configured correctly
 * Run: node check-config.js
 */

require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

console.log('\n🔍 Checking Supabase Configuration...\n');

let hasErrors = false;

// Check SUPABASE_URL
if (!supabaseUrl) {
  console.log('❌ SUPABASE_URL: Missing');
  hasErrors = true;
} else if (supabaseUrl.includes('YOUR_') || supabaseUrl.includes('your_') || supabaseUrl.includes('placeholder')) {
  console.log('❌ SUPABASE_URL: Placeholder value detected');
  hasErrors = true;
} else {
  console.log('✅ SUPABASE_URL: Configured');
  console.log(`   ${supabaseUrl}`);
}

// Check SUPABASE_SERVICE_ROLE_KEY
if (!supabaseServiceKey) {
  console.log('❌ SUPABASE_SERVICE_ROLE_KEY: Missing');
  console.log('   ⚠️  This is required for backend database operations');
  hasErrors = true;
} else if (supabaseServiceKey.includes('YOUR_') || supabaseServiceKey.includes('your_') || supabaseServiceKey.includes('placeholder')) {
  console.log('❌ SUPABASE_SERVICE_ROLE_KEY: Placeholder value detected');
  console.log('   ⚠️  Please replace with your actual service role key');
  console.log('   📖 See GET_SERVICE_ROLE_KEY.md for instructions');
  hasErrors = true;
} else if (!supabaseServiceKey.startsWith('eyJ')) {
  console.log('⚠️  SUPABASE_SERVICE_ROLE_KEY: Format looks incorrect');
  console.log('   Expected: JWT token starting with "eyJ"');
  hasErrors = true;
} else {
  console.log('✅ SUPABASE_SERVICE_ROLE_KEY: Configured');
  console.log(`   ${supabaseServiceKey.substring(0, 20)}...`);
}

// Check SUPABASE_ANON_KEY (optional for backend, but good to have)
if (!supabaseAnonKey) {
  console.log('⚠️  SUPABASE_ANON_KEY: Not set (optional for backend)');
} else if (supabaseAnonKey.includes('YOUR_') || supabaseAnonKey.includes('your_')) {
  console.log('⚠️  SUPABASE_ANON_KEY: Placeholder value');
} else {
  console.log('✅ SUPABASE_ANON_KEY: Configured');
}

console.log('\n' + '='.repeat(50));

if (hasErrors) {
  console.log('\n❌ Configuration Issues Found\n');
  console.log('To fix:');
  console.log('1. Get your Supabase Service Role Key from:');
  console.log('   https://app.supabase.com → Your Project → Settings → API');
  console.log('2. Update .env file with the actual key');
  console.log('3. See FIX_SUPABASE_CONFIG.md for detailed instructions\n');
  process.exit(1);
} else {
  console.log('\n✅ All Supabase configuration looks good!\n');
  console.log('Your backend should be able to connect to Supabase.');
  console.log('Restart your backend server if it\'s already running.\n');
  process.exit(0);
}


