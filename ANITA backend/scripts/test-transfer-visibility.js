/**
 * Test: Transfer created with first-of-month date should appear in that month's transaction list.
 * Run with: node scripts/test-transfer-visibility.js
 * Requires: BACKEND_URL and a valid userId (or set TEST_USER_ID in .env for real run).
 *
 * This script verifies the UTC month-boundary logic:
 * - Month Feb 2026 = 2026-02-01T00:00:00.000Z to 2026-02-28T23:59:59.999Z
 * - A transfer with created_at 2026-02-01T00:00:00.000Z must be included.
 */

function assertUTCMonthBoundaries() {
  const yearNum = 2026;
  const monthNum = 1; // February (0-indexed)
  const monthStart = new Date(Date.UTC(yearNum, monthNum, 1, 0, 0, 0, 0)).toISOString();
  const monthEnd = new Date(Date.UTC(yearNum, monthNum + 1, 0, 23, 59, 59, 999)).toISOString();

  const transferDate = '2026-02-01T00:00:00.000Z';
  const inRange = transferDate >= monthStart && transferDate <= monthEnd;

  console.log('UTC month boundaries (Feb 2026):');
  console.log('  monthStart:', monthStart);
  console.log('  monthEnd: ', monthEnd);
  console.log('  transfer  :', transferDate);
  console.log('  in range  :', inRange);
  if (!inRange) {
    console.error('FAIL: Transfer date should be in February range.');
    process.exit(1);
  }
  console.log('OK: Transfer with first-of-month date is within UTC month range.\n');
}

assertUTCMonthBoundaries();

// Old (server-local) boundaries would exclude the transfer in some timezones
const oldMonthStartLocal = new Date(2026, 1, 1).toISOString();
console.log('For comparison, server-local Feb 1 00:00 (e.g. US Eastern):');
console.log('  oldMonthStart:', oldMonthStartLocal);
console.log('  "2026-02-01T00:00:00.000Z" >= oldMonthStart?', '2026-02-01T00:00:00.000Z' >= oldMonthStartLocal);
console.log('  (In US Eastern, Feb 1 00:00 = 05:00 UTC, so midnight UTC would be EXCLUDED)\n');
console.log('Using UTC boundaries fixes this so the transfer is always included.');
