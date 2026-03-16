/**
 * Category Detector
 * Detects transaction category from description text (and optional merchant).
 * Stripe Financial Connections only provides: id, amount, currency, description, transacted_at, status.
 * There is NO merchant_name or raw_category in the Stripe API — we only have description (e.g. "Rocket Rides", "Typographic").
 */

export interface BankTransactionCategorizeInput {
  merchant_name?: string | null;
  description?: string | null;
  amount_cents: number;
}

/** Fallback when we cannot determine category: never use "Other". */
const FALLBACK_EXPENSE = 'Shopping';
const FALLBACK_INCOME = 'Freelance & Side Income';

/**
 * Rule-based categorization for bank transactions (used when AI is unavailable or returns Other).
 * Uses merchant_name + description (Stripe typically only sends description).
 */
export function categorizeBankTransactionByRules(
  input: BankTransactionCategorizeInput
): string {
  const combined = [input.merchant_name, input.description].filter(Boolean).join(' ').trim();
  const type: 'income' | 'expense' = input.amount_cents >= 0 ? 'income' : 'expense';
  if (!combined) return type === 'income' ? FALLBACK_INCOME : FALLBACK_EXPENSE;

  const lower = combined.toLowerCase();

  // Explicit merchant/description rules (order matters: more specific first)
  const merchantRules: Array<{ pattern: string; category: string; whenIncome?: boolean; whenExpense?: boolean }> = [
    // Food delivery
    { pattern: 'rocket delivery', category: 'Dining Out', whenExpense: true },
    { pattern: 'rocket deliveries', category: 'Dining Out', whenExpense: true },
    { pattern: 'doordash', category: 'Dining Out', whenExpense: true },
    { pattern: 'uber eats', category: 'Dining Out', whenExpense: true },
    { pattern: 'deliveroo', category: 'Dining Out', whenExpense: true },
    { pattern: 'grubhub', category: 'Dining Out', whenExpense: true },
    { pattern: 'just eat', category: 'Dining Out', whenExpense: true },
    { pattern: 'foodpanda', category: 'Dining Out', whenExpense: true },
    { pattern: 'food delivery', category: 'Dining Out', whenExpense: true },
    // Ride-hailing / transport
    { pattern: 'rocket rides', category: 'Rideshare & Taxi', whenExpense: true },
    { pattern: 'uber', category: 'Rideshare & Taxi', whenExpense: true },
    { pattern: 'lyft', category: 'Rideshare & Taxi', whenExpense: true },
    { pattern: 'bolt', category: 'Rideshare & Taxi', whenExpense: true },
    { pattern: 'free now', category: 'Rideshare & Taxi', whenExpense: true },
    { pattern: 'taxi', category: 'Rideshare & Taxi', whenExpense: true },
    // Income (company/payment names)
    { pattern: 'typographic', category: 'Freelance & Side Income', whenIncome: true },
    { pattern: 'salary', category: 'Salary', whenIncome: true },
    { pattern: 'payroll', category: 'Salary', whenIncome: true },
    { pattern: 'paypal', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
    { pattern: 'stripe', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
    { pattern: 'wise', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
    { pattern: 'revolut', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
    // Shopping / retail
    { pattern: 'amazon', category: 'Shopping' },
    { pattern: 'ebay', category: 'Shopping' },
    { pattern: 'alibaba', category: 'Shopping' },
    // Subscriptions
    { pattern: 'spotify', category: 'Streaming Services' },
    { pattern: 'netflix', category: 'Streaming Services' },
    { pattern: 'disney', category: 'Streaming Services' },
    { pattern: 'hulu', category: 'Streaming Services' },
    { pattern: 'apple music', category: 'Streaming Services' },
    { pattern: 'youtube premium', category: 'Streaming Services' },
    { pattern: 'apple.com/bill', category: 'Software & Apps' },
    { pattern: 'google play', category: 'Software & Apps' },
    { pattern: 'adobe', category: 'Software & Apps' },
    { pattern: 'microsoft', category: 'Software & Apps' },
    { pattern: 'dropbox', category: 'Software & Apps' },
    { pattern: 'icloud', category: 'Software & Apps' },
    // Generic
    { pattern: 'pos purchase', category: 'Shopping' },
    { pattern: 'payment', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
    { pattern: 'transfer', category: type === 'income' ? 'Freelance & Side Income' : 'Shopping' },
  ];
  for (const { pattern, category, whenIncome, whenExpense } of merchantRules) {
    if (!lower.includes(pattern)) continue;
    if (whenIncome !== undefined && !whenIncome && type === 'income') continue;
    if (whenExpense !== undefined && !whenExpense && type === 'expense') continue;
    return category;
  }
  // "delivery" by itself (expense) → often food delivery
  if (type === 'expense' && (lower.includes('delivery') || lower.includes('delivered'))) {
    return 'Dining Out';
  }
  // "rides" or "ride" (expense) → transport
  if (type === 'expense' && (lower.includes('rides') || (lower.includes('ride') && !lower.includes('brides')))) {
    return 'Rideshare & Taxi';
  }

  const out = detectCategoryFromDescription(combined, type);
  return out === 'Other' ? (type === 'income' ? FALLBACK_INCOME : FALLBACK_EXPENSE) : out;
}

/**
 * Detect category from transaction description.
 * Returns a specific category; never returns "Other" (use fallback instead).
 */
export function detectCategoryFromDescription(
  description: string,
  type: 'income' | 'expense'
): string {
  if (!description || description.trim().length === 0) {
    return type === 'income' ? FALLBACK_INCOME : FALLBACK_EXPENSE;
  }

  const lowercased = description.toLowerCase().trim();

  // Restaurant/Fast Food Chains - highest priority
  const restaurantChains = [
    'burger king', 'mcdonalds', 'mcdonald', 'kfc', 'subway', 'dominos', 'domino',
    'papa johns', 'taco bell', 'wendys', 'chipotle', 'panera', 'olive garden',
    'outback', 'applebees', 'chilis', 'red lobster', 'ihop', 'dennys', 'waffle house',
    'dunkin', 'dunkin donuts', 'five guys', 'shake shack', 'in-n-out', 'whataburger',
    'jack in the box', 'arbys', 'panda express', 'pizza hut', 'little caesars'
  ];

  for (const chain of restaurantChains) {
    if (lowercased.includes(chain)) {
      return 'Dining Out';
    }
  }

  // Food/Dining keywords
  const diningKeywords = [
    'pizza', 'burger', 'restaurant', 'cafe', 'dining', 'lunch', 'dinner',
    'breakfast', 'takeout', 'delivery', 'food delivery', 'fast food',
    'drive thru', 'drive-through', 'coffee', 'starbucks'
  ];
  for (const keyword of diningKeywords) {
    if (lowercased.includes(keyword)) {
      return 'Dining Out';
    }
  }

  // Groceries (stores and keywords)
  const groceryKeywords = [
    'grocery', 'groceries', 'supermarket', 'food store', 'food shopping',
    'aldi', 'lidl', 'tesco', 'sainsbury', 'asda', 'walmart', 'costco',
    'whole foods', 'trader joe', 'kroger', 'safeway', 'publix', 'target',
    'rewe', 'edeka', 'carrefour', 'auchan', 'colruyt', 'delhaize',
  ];
  for (const keyword of groceryKeywords) {
    if (lowercased.includes(keyword)) {
      return 'Groceries';
    }
  }

  // Transportation
  if (lowercased.includes('uber') || lowercased.includes('lyft') || 
      lowercased.includes('taxi') || lowercased.includes('cab') || 
      lowercased.includes('rideshare') || lowercased.includes('ride share') ||
      lowercased.includes('rides')) {
    return 'Rideshare & Taxi';
  }
  if (lowercased.includes('bus') || lowercased.includes('train') || 
      lowercased.includes('subway') || lowercased.includes('metro') || 
      lowercased.includes('transit')) {
    return 'Public Transportation';
  }
  if ((lowercased.includes('gas') || lowercased.includes('fuel') || 
       lowercased.includes('gasoline')) && 
      (lowercased.includes('station') || lowercased.includes('car') || 
       lowercased.includes('vehicle') || !lowercased.includes('heating'))) {
    return 'Gas & Fuel';
  }
  if (lowercased.includes('parking') || lowercased.includes('toll')) {
    return 'Parking & Tolls';
  }

  // Housing
  if (lowercased.includes('rent') || lowercased.includes('apartment') || 
      lowercased.includes('landlord')) {
    return 'Rent';
  }
  // Leasing (vehicle/equipment) - check before generic "lease" which maps to Rent
  if (lowercased.includes('leasing') || lowercased.includes('car lease') || 
      lowercased.includes('vehicle lease') || lowercased.includes('equipment lease')) {
    return 'Leasing';
  }
  if (lowercased.includes('lease')) {
    return 'Rent';
  }
  if (lowercased.includes('mortgage') || lowercased.includes('home loan')) {
    return 'Mortgage';
  }

  // Loans, debts
  if (lowercased.includes('loan payment') || lowercased.includes('loan installment') || 
      lowercased.includes('student loan') || lowercased.includes('personal loan') || 
      (lowercased.includes('loan') && (lowercased.includes('repayment') || lowercased.includes('payment')))) {
    return 'Loan Payments';
  }
  if (lowercased.includes('debt') || lowercased.includes('credit card payment') || 
      lowercased.includes('paying off') || lowercased.includes('payoff')) {
    return 'Debts';
  }

  // Utilities
  if (lowercased.includes('electricity') || lowercased.includes('electric') || 
      lowercased.includes('power') || lowercased.includes('energy')) {
    return 'Electricity';
  }
  if (lowercased.includes('water') || lowercased.includes('sewage') || 
      lowercased.includes('sewer')) {
    return 'Water & Sewage';
  }
  if ((lowercased.includes('gas') || lowercased.includes('heating')) && 
      (lowercased.includes('home') || lowercased.includes('house') || 
       lowercased.includes('natural gas'))) {
    return 'Gas & Heating';
  }
  if (lowercased.includes('internet') || lowercased.includes('phone') || 
      lowercased.includes('mobile') || lowercased.includes('broadband') || 
      lowercased.includes('wifi') || lowercased.includes('cellular')) {
    return 'Internet & Phone';
  }

  // Subscriptions
  if (lowercased.includes('netflix') || lowercased.includes('spotify') || 
      lowercased.includes('disney') || lowercased.includes('streaming') || 
      lowercased.includes('hulu') || lowercased.includes('amazon prime')) {
    return 'Streaming Services';
  }
  if (lowercased.includes('software') || lowercased.includes('app subscription') || 
      lowercased.includes('saas') || lowercased.includes('cloud service')) {
    return 'Software & Apps';
  }

  // Shopping
  if (lowercased.includes('clothing') || lowercased.includes('clothes') || 
      lowercased.includes('shoes') || lowercased.includes('fashion') || 
      lowercased.includes('apparel') || lowercased.includes('wardrobe')) {
    return 'Clothing & Fashion';
  }
  if (lowercased.includes('shopping') || lowercased.includes('store') || 
      lowercased.includes('retail')) {
    return 'Shopping';
  }

  // Entertainment
  if (lowercased.includes('movie') || lowercased.includes('cinema') || 
      lowercased.includes('concert') || lowercased.includes('event') || 
      lowercased.includes('game') || lowercased.includes('entertainment')) {
    return 'Entertainment';
  }

  // Health
  if (lowercased.includes('doctor') || lowercased.includes('medical') || 
      lowercased.includes('pharmacy') || lowercased.includes('medicine') || 
      lowercased.includes('hospital') || lowercased.includes('clinic') || 
      lowercased.includes('healthcare')) {
    return 'Medical & Healthcare';
  }
  if (lowercased.includes('gym') || lowercased.includes('fitness') || 
      lowercased.includes('workout') || lowercased.includes('exercise') || 
      lowercased.includes('sports') || lowercased.includes('yoga') || 
      lowercased.includes('pilates')) {
    return 'Fitness & Gym';
  }

  // Personal Care
  if (lowercased.includes('haircut') || lowercased.includes('salon') || 
      lowercased.includes('barber') || lowercased.includes('grooming') || 
      lowercased.includes('spa') || lowercased.includes('toilette') || 
      lowercased.includes('toiletries') || lowercased.includes('hygiene') || 
      lowercased.includes('personal care')) {
    return 'Personal Care';
  }

  // Education
  if (lowercased.includes('tuition') || lowercased.includes('course') || 
      lowercased.includes('education') || lowercased.includes('certification') || 
      lowercased.includes('learning') || lowercased.includes('school')) {
    return 'Education';
  }

  // Income (only for income type)
  if (type === 'income') {
    if (lowercased.includes('salary') || lowercased.includes('paycheck') || 
        lowercased.includes('wage') || lowercased.includes('pay')) {
      return 'Salary';
    }
    if (lowercased.includes('freelance') || lowercased.includes('side income') || 
        lowercased.includes('gig') || lowercased.includes('bonus') || 
        lowercased.includes('commission')) {
      return 'Freelance & Side Income';
    }
    // Default for income
    return 'Salary';
  }

  // Default for expenses: never "Other"
  return FALLBACK_EXPENSE;
}
