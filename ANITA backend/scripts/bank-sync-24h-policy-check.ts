/**
 * Sanity-check for iOS BankSessionForegroundSyncPolicy (24h between successful client refreshes).
 * Run: npx tsx scripts/bank-sync-24h-policy-check.ts
 */

const DAY_MS = 24 * 3600 * 1000;

function shouldAllowForegroundRefresh(lastSuccessMs: number | null, nowMs: number): boolean {
  if (lastSuccessMs == null) return true;
  return nowMs - lastSuccessMs >= DAY_MS;
}

let failed = 0;
function assert(cond: boolean, msg: string) {
  if (!cond) {
    console.error('FAIL:', msg);
    failed++;
  }
}

const t0 = 1_000_000_000_000;

assert(shouldAllowForegroundRefresh(null, t0) === true, 'never synced → allow');
assert(shouldAllowForegroundRefresh(t0, t0 + DAY_MS - 1) === false, '23h59m → deny');
assert(shouldAllowForegroundRefresh(t0, t0 + DAY_MS) === true, 'exactly 24h → allow');
assert(shouldAllowForegroundRefresh(t0, t0 + DAY_MS + 60_000) === true, '24h+ → allow');

if (failed > 0) {
  process.exit(1);
}
console.log('bank-sync-24h-policy-check: OK (matches iOS 24h window)');
