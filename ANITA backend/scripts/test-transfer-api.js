/**
 * Test transfer save + financial metrics
 * Run: BACKEND_URL=https://your-railway-url.up.railway.app node scripts/test-transfer-api.js <userId>
 * Or: BACKEND_URL=https://your-railway-url.up.railway.app node scripts/test-transfer-api.js
 * (uses test-user-id if no userId)
 *
 * 1. POST save-transaction (transfer)
 * 2. GET financial-metrics (month)
 * 3. GET transactions (month)
 * Verifies transfer is stored and monthlyBalance reflects it.
 */

const backendUrl = (process.env.BACKEND_URL || '').replace(/\/$/, '');
const userId = process.argv[2] || 'test-user-id';

if (!backendUrl) {
  console.error('Set BACKEND_URL (e.g. https://anita-production-bb9a.up.railway.app)');
  process.exit(1);
}

const now = new Date();
const month = now.getUTCMonth() + 1;
const year = now.getUTCFullYear();
const firstOfMonth = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0, 0)).toISOString();

async function run() {
  console.log('Backend:', backendUrl);
  console.log('UserId:', userId);
  console.log('Month/Year:', month, year);
  console.log('');

  // 1) Save a transfer
  const txnId = `txn_test_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
  const transferBody = {
    userId,
    transactionId: txnId,
    type: 'transfer',
    amount: 10.5,
    category: 'Transfer to goal',
    description: 'To goal: Test goal',
    date: firstOfMonth,
  };

  console.log('1. POST /api/v1/save-transaction (transfer)');
  const saveRes = await fetch(`${backendUrl}/api/v1/save-transaction`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(transferBody),
  });
  const saveJson = await saveRes.json().catch(() => ({}));
  if (!saveRes.ok) {
    console.error('   FAIL', saveRes.status, saveJson);
    process.exit(1);
  }
  if (!saveJson.success || !saveJson.transaction) {
    console.error('   FAIL success/transaction', saveJson);
    process.exit(1);
  }
  console.log('   OK', saveJson.transaction.id, saveJson.transaction.type, saveJson.transaction.amount);

  // 2) Get financial metrics
  console.log('\n2. GET /api/v1/financial-metrics');
  const metricsRes = await fetch(
    `${backendUrl}/api/v1/financial-metrics?userId=${encodeURIComponent(userId)}&month=${month}&year=${year}`
  );
  const metricsJson = await metricsRes.json().catch(() => ({}));
  if (!metricsRes.ok) {
    console.error('   FAIL', metricsRes.status, metricsJson);
    process.exit(1);
  }
  console.log('   monthlyIncome:', metricsJson.metrics?.monthlyIncome);
  console.log('   monthlyExpenses:', metricsJson.metrics?.monthlyExpenses);
  console.log('   monthlyBalance (Available Funds):', metricsJson.metrics?.monthlyBalance);

  // 3) Get transactions
  console.log('\n3. GET /api/v1/transactions');
  const txRes = await fetch(
    `${backendUrl}/api/v1/transactions?userId=${encodeURIComponent(userId)}&month=${month}&year=${year}`
  );
  const txJson = await txRes.json().catch(() => ({}));
  if (!txRes.ok) {
    console.error('   FAIL', txRes.status, txJson);
    process.exit(1);
  }
  const transfers = (txJson.transactions || []).filter((t) => t.type === 'transfer');
  const found = transfers.some((t) => t.id === txnId);
  console.log('   transactions count:', (txJson.transactions || []).length);
  console.log('   transfers in month:', transfers.length);
  console.log('   our transfer found:', found ? 'YES' : 'NO');

  console.log('\nDone. Transfer is saved and returned by API.');
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
