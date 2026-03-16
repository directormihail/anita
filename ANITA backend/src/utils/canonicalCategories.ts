/**
 * Canonical transaction categories used across ANITA (iOS, webapp, backend).
 * AI categorizer must return exactly one of these display names.
 * Order: housing, utilities, food, transport, subscriptions, shopping, health, other, income.
 */
export const CANONICAL_CATEGORIES: readonly string[] = [
  'Rent',
  'Mortgage',
  'Electricity',
  'Water & Sewage',
  'Gas & Heating',
  'Internet & Phone',
  'Groceries',
  'Dining Out',
  'Gas & Fuel',
  'Public Transportation',
  'Rideshare & Taxi',
  'Parking & Tolls',
  'Streaming Services',
  'Software & Apps',
  'Shopping',
  'Clothing & Fashion',
  'Entertainment',
  'Medical & Healthcare',
  'Fitness & Gym',
  'Personal Care',
  'Education',
  'Loan Payments',
  'Debts',
  'Leasing',
  'Salary',
  'Freelance & Side Income',
  'Other',
] as const;

export type CanonicalCategory = (typeof CANONICAL_CATEGORIES)[number];

const CATEGORY_SET = new Set(CANONICAL_CATEGORIES);

export function isCanonicalCategory(name: string): name is CanonicalCategory {
  return CATEGORY_SET.has(name);
}

const ALIASES: Record<string, CanonicalCategory> = {
  'rideshare and taxi': 'Rideshare & Taxi',
  'rideshare': 'Rideshare & Taxi',
  'taxi': 'Rideshare & Taxi',
  'rides': 'Rideshare & Taxi',
  'gas and fuel': 'Gas & Fuel',
  'gas and heating': 'Gas & Heating',
  'water and sewage': 'Water & Sewage',
  'internet and phone': 'Internet & Phone',
  'parking and tolls': 'Parking & Tolls',
  'software and apps': 'Software & Apps',
  'clothing and fashion': 'Clothing & Fashion',
  'medical and healthcare': 'Medical & Healthcare',
  'fitness and gym': 'Fitness & Gym',
  'freelance and side income': 'Freelance & Side Income',
  'freelance': 'Freelance & Side Income',
  'salary': 'Salary',
  'dining out': 'Dining Out',
  'streaming services': 'Streaming Services',
  'public transportation': 'Public Transportation',
  'groceries': 'Groceries',
  'grocery': 'Groceries',
  'shopping': 'Shopping',
  'entertainment': 'Entertainment',
  'transport': 'Public Transportation',
  'transportation': 'Public Transportation',
  'income': 'Salary',
  'uncategorized': 'Shopping',
  'other': 'Shopping',
  'misc': 'Shopping',
  'miscellaneous': 'Shopping',
  'general': 'Shopping',
  'pos': 'Shopping',
  'purchase': 'Shopping',
};

/** Normalize AI output to a canonical category. Never returns "Other" — uses Shopping or Freelance & Side Income as fallback. */
export function toCanonicalCategory(aiOutput: string | null | undefined, isIncome?: boolean): CanonicalCategory {
  const fallback: CanonicalCategory = isIncome === true ? 'Freelance & Side Income' : 'Shopping';
  if (!aiOutput || typeof aiOutput !== 'string') return fallback;
  const t = aiOutput.trim();
  if (!t) return fallback;
  const lower = t.toLowerCase();
  if (lower === 'other' || lower === 'uncategorized' || lower === 'misc' || lower === 'miscellaneous') return fallback;
  for (const c of CANONICAL_CATEGORIES) {
    if (c.toLowerCase() === lower) return c === 'Other' ? fallback : c;
  }
  if (ALIASES[lower]) {
    const mapped = ALIASES[lower];
    return mapped === 'Other' ? fallback : mapped;
  }
  return fallback;
}
