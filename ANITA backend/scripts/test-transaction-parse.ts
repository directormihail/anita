/**
 * Quick test for parseTransactionFromAiResponse.
 * Run: npx tsx scripts/test-transaction-parse.ts
 */
import { parseTransactionFromAiResponse } from '../src/routes/chat-completion';

const messages = [
  { role: 'user' as const, content: "I wanna add expense" },
  { role: 'assistant' as const, content: "Sure! Please provide the category of the expense (e.g. Groceries, Dining Out), the amount, and optionally a short description." },
  { role: 'user' as const, content: "21 on the haircut" },
  { role: 'assistant' as const, content: "Please confirm the category for the expense. Based on your description, it could be 'Personal Care.' Is that correct?" },
  { role: 'user' as const, content: "Yes" },
];

const aiResponse = "I've added your expense of $21.00 for Personal Care (Haircut). You can review your expenses anytime!";

const result = parseTransactionFromAiResponse(messages, aiResponse);

function assert(cond: boolean, msg: string) {
  if (!cond) {
    console.error('FAIL:', msg);
    process.exit(1);
  }
}

assert(result !== null, 'parser should return a transaction');
assert(result!.type === 'expense', 'type should be expense');
assert(result!.amount === 21, 'amount should be 21');
assert(result!.category === 'Personal Care', 'category should be Personal Care');
assert(result!.description === 'Haircut', 'description should be Haircut');

// Not a transaction confirmation
const noTx = parseTransactionFromAiResponse(messages, "Sure! Please provide the category and amount.");
assert(noTx === null, 'non-confirmation should return null');

console.log('All parse tests passed.');
process.exit(0);
