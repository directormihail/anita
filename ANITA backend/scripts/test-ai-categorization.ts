/**
 * Two tests that verify the AI transaction categorizer correctly assigns
 * canonical categories to sample bank transactions.
 *
 * Run: npx tsx scripts/test-ai-categorization.ts
 * Requires OPENAI_API_KEY in .env for real API tests.
 */

import * as dotenv from 'dotenv';
dotenv.config();

import { categorizeTransactionWithAI } from '../src/utils/transactionCategoryAI';

const TESTS: Array<{
  name: string;
  input: { merchant_name?: string; description?: string; amount_cents: number; raw_category?: string };
  expectedCategories: string[]; // at least one must match (e.g. income can be Salary or Freelance & Side Income)
}> = [
  {
    name: 'Test 1: Ride-hailing expense → Rideshare & Taxi',
    input: {
      merchant_name: 'Rocket Rides',
      description: 'Trip',
      amount_cents: -1000,
    },
    expectedCategories: ['Rideshare & Taxi'],
  },
  {
    name: 'Test 2: Income from client/company → Freelance & Side Income or Salary',
    input: {
      merchant_name: 'Typographic',
      description: 'Payment received',
      amount_cents: 10000,
    },
    expectedCategories: ['Freelance & Side Income', 'Salary'],
  },
  {
    name: 'Test 3: Food delivery (Rocket Delivery) → Dining Out',
    input: {
      description: 'Rocket Delivery',
      amount_cents: -2500,
    },
    expectedCategories: ['Dining Out'],
  },
];

async function run(): Promise<void> {
  const apiKey = process.env.OPENAI_API_KEY?.trim();
  if (!apiKey || !apiKey.startsWith('sk-')) {
    console.log('⚠️  OPENAI_API_KEY not set or invalid. Skipping AI categorization tests.');
    console.log('   Set OPENAI_API_KEY in .env to run the tests.');
    process.exit(0);
  }

  console.log('Running AI transaction categorization tests (3 tests, run twice for consistency)...\n');

  let passed = 0;
  let failed = 0;

  for (const round of [1, 2]) {
    console.log(`--- Round ${round} ---`);
    for (const test of TESTS) {
      process.stdout.write(`  ${test.name} ... `);
      try {
        const category = await categorizeTransactionWithAI(test.input, 'test-script');
        const ok = test.expectedCategories.includes(category);
        if (ok) {
          console.log(`✅ ${category}`);
          passed++;
        } else {
          console.log(`❌ got "${category}", expected one of [${test.expectedCategories.join(', ')}]`);
          failed++;
        }
      } catch (err) {
        console.log(`❌ ${err instanceof Error ? err.message : String(err)}`);
        failed++;
      }
    }
  }

  console.log(`\nResult: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

run();
