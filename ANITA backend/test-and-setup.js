/**
 * Test Backend Connection and Add Sample Data
 * This script tests the backend API and adds sample data for testing
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testConnection() {
  console.log('🔍 Testing Supabase connection...');
  try {
    const { data, error } = await supabase.from('targets').select('count').limit(1);
    if (error) {
      console.error('❌ Connection failed:', error.message);
      return false;
    }
    console.log('✅ Supabase connection successful');
    return true;
  } catch (error) {
    console.error('❌ Connection error:', error.message);
    return false;
  }
}

async function addSampleData(userId = 'default-user') {
  console.log(`\n📊 Adding sample data for user: ${userId}`);
  
  // Add sample transactions
  const transactions = [
    {
      account_id: userId,
      data_type: 'transaction',
      transaction_type: 'income',
      transaction_amount: 5000,
      transaction_category: 'Salary',
      transaction_description: 'Monthly salary'
    },
    {
      account_id: userId,
      data_type: 'transaction',
      transaction_type: 'expense',
      transaction_amount: 120,
      transaction_category: 'Food & Dining',
      transaction_description: 'Grocery shopping'
    },
    {
      account_id: userId,
      data_type: 'transaction',
      transaction_type: 'expense',
      transaction_amount: 45,
      transaction_category: 'Transportation',
      transaction_description: 'Gas station'
    },
    {
      account_id: userId,
      data_type: 'transaction',
      transaction_type: 'expense',
      transaction_amount: 200,
      transaction_category: 'Technology',
      transaction_description: 'Software subscription'
    },
    {
      account_id: userId,
      data_type: 'transaction',
      transaction_type: 'income',
      transaction_amount: 300,
      transaction_category: 'Freelance',
      transaction_description: 'Freelance project payment'
    }
  ];

  console.log('  Adding transactions...');
  for (const transaction of transactions) {
    const { error } = await supabase.from('anita_data').upsert(transaction, {
      onConflict: 'id',
      ignoreDuplicates: true
    });
    if (error && !error.message.includes('duplicate')) {
      console.error(`    ⚠️  Error adding transaction: ${error.message}`);
    }
  }
  console.log('  ✅ Transactions added');

  // Add sample targets/goals
  const targets = [
    {
      account_id: userId,
      title: 'Emergency Fund',
      description: 'Build a 6-month emergency fund for financial security',
      target_amount: 15000,
      current_amount: 8500,
      currency: 'USD',
      status: 'active',
      target_type: 'emergency_fund',
      priority: 'high',
      target_date: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString()
    },
    {
      account_id: userId,
      title: 'Vacation Fund',
      description: 'Save for summer vacation',
      target_amount: 5000,
      current_amount: 1200,
      currency: 'USD',
      status: 'active',
      target_type: 'savings',
      priority: 'medium',
      target_date: new Date(Date.now() + 240 * 24 * 60 * 60 * 1000).toISOString()
    },
    {
      account_id: userId,
      title: 'TRANSPORTATION Monthly Budget',
      description: 'Monthly spending limit for transportation',
      target_amount: 200,
      current_amount: 45,
      currency: 'USD',
      status: 'active',
      target_type: 'budget',
      category: 'Transportation',
      priority: 'medium',
      target_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    },
    {
      account_id: userId,
      title: 'Food Monthly Budget',
      description: 'Monthly spending limit for food and dining',
      target_amount: 400,
      current_amount: 120,
      currency: 'USD',
      status: 'active',
      target_type: 'budget',
      category: 'Food & Dining',
      priority: 'high',
      target_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    }
  ];

  console.log('  Adding targets/goals...');
  for (const target of targets) {
    const { error } = await supabase.from('targets').upsert(target, {
      onConflict: 'id',
      ignoreDuplicates: true
    });
    if (error && !error.message.includes('duplicate')) {
      console.error(`    ⚠️  Error adding target: ${error.message}`);
    }
  }
  console.log('  ✅ Targets/goals added');

  // Add sample assets
  const assets = [
    {
      account_id: userId,
      name: 'Savings Account',
      type: 'savings',
      current_value: 5000,
      currency: 'USD',
      description: 'Main savings account'
    },
    {
      account_id: userId,
      name: 'Checking Account',
      type: 'checking',
      current_value: 2500,
      currency: 'USD',
      description: 'Primary checking account'
    }
  ];

  console.log('  Adding assets...');
  for (const asset of assets) {
    const { error } = await supabase.from('assets').upsert(asset, {
      onConflict: 'id',
      ignoreDuplicates: true
    });
    if (error && !error.message.includes('duplicate')) {
      console.error(`    ⚠️  Error adding asset: ${error.message}`);
    }
  }
  console.log('  ✅ Assets added');

  console.log('\n✅ Sample data setup complete!');
}

async function main() {
  console.log('🚀 ANITA Backend Test & Setup\n');
  
  const connected = await testConnection();
  if (!connected) {
    console.log('\n❌ Cannot proceed without database connection');
    process.exit(1);
  }

  await addSampleData();
  
  console.log('\n📝 Next steps:');
  console.log('  1. Make sure backend is running: npm run dev');
  console.log('  2. Test health endpoint: curl http://localhost:3001/health');
  console.log('  3. Test targets endpoint: curl "http://localhost:3001/api/v1/targets?userId=default-user"');
  console.log('  4. In iOS app, make sure backend URL is set to: http://localhost:3001');
  console.log('     (or your Mac\'s IP address if testing on physical device)');
}

main().catch(console.error);
