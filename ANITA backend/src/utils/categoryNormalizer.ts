/**
 * Category Normalizer
 * Ensures categories are stored with proper formatting (not all caps)
 */

// Standard categories matching iOS and webapp
const STANDARD_CATEGORIES: { [key: string]: string } = {
  // Housing
  'rent': 'Rent',
  'mortgage': 'Mortgage',
  'housing': 'Rent',
  
  // Utilities
  'electricity': 'Electricity',
  'electric': 'Electricity',
  'water': 'Water & Sewage',
  'sewage': 'Water & Sewage',
  'gas': 'Gas & Heating',
  'heating': 'Gas & Heating',
  'internet': 'Internet & Phone',
  'phone': 'Internet & Phone',
  'utilities': 'Electricity',
  
  // Food
  'groceries': 'Groceries',
  'grocery': 'Groceries',
  'food': 'Groceries',
  'dining': 'Dining Out',
  'dining out': 'Dining Out',
  'restaurant': 'Dining Out',
  'cafe': 'Dining Out',
  'coffee': 'Dining Out',
  'pizza': 'Dining Out',
  'lunch': 'Dining Out',
  'dinner': 'Dining Out',
  'breakfast': 'Dining Out',
  'burger': 'Dining Out',
  'burger king': 'Dining Out',
  'mcdonalds': 'Dining Out',
  'mcdonald': 'Dining Out',
  'kfc': 'Dining Out',
  'subway': 'Dining Out',
  'dominos': 'Dining Out',
  'domino': 'Dining Out',
  'papa johns': 'Dining Out',
  'taco bell': 'Dining Out',
  'wendys': 'Dining Out',
  'chipotle': 'Dining Out',
  'panera': 'Dining Out',
  'olive garden': 'Dining Out',
  'outback': 'Dining Out',
  'applebees': 'Dining Out',
  'chilis': 'Dining Out',
  'red lobster': 'Dining Out',
  'ihop': 'Dining Out',
  'dennys': 'Dining Out',
  'waffle house': 'Dining Out',
  'dunkin': 'Dining Out',
  'dunkin donuts': 'Dining Out',
  'five guys': 'Dining Out',
  'shake shack': 'Dining Out',
  'in-n-out': 'Dining Out',
  'whataburger': 'Dining Out',
  'jack in the box': 'Dining Out',
  'arbys': 'Dining Out',
  'panda express': 'Dining Out',
  'pizza hut': 'Dining Out',
  'little caesars': 'Dining Out',
  'fast food': 'Dining Out',
  'takeout': 'Dining Out',
  'delivery': 'Dining Out',
  
  // Transportation
  'transportation': 'Gas & Fuel',
  'transport': 'Gas & Fuel',
  'gas & fuel': 'Gas & Fuel',
  'fuel': 'Gas & Fuel',
  'gasoline': 'Gas & Fuel',
  'public transportation': 'Public Transportation',
  'bus': 'Public Transportation',
  'train': 'Public Transportation',
  'metro': 'Public Transportation',
  'rideshare': 'Rideshare & Taxi',
  'rideshare & taxi': 'Rideshare & Taxi',
  'uber': 'Rideshare & Taxi',
  'lyft': 'Rideshare & Taxi',
  'taxi': 'Rideshare & Taxi',
  'cab': 'Rideshare & Taxi',
  'parking': 'Parking & Tolls',
  'parking & tolls': 'Parking & Tolls',
  'toll': 'Parking & Tolls',
  
  // Subscriptions
  'streaming services': 'Streaming Services',
  'streaming': 'Streaming Services',
  'netflix': 'Streaming Services',
  'spotify': 'Streaming Services',
  'disney': 'Streaming Services',
  'subscription': 'Streaming Services',
  'software & apps': 'Software & Apps',
  'software': 'Software & Apps',
  'app': 'Software & Apps',
  
  // Shopping
  'shopping': 'Shopping',
  'clothing': 'Clothing & Fashion',
  'clothing & fashion': 'Clothing & Fashion',
  'fashion': 'Clothing & Fashion',
  'clothes': 'Clothing & Fashion',
  'shoes': 'Clothing & Fashion',
  
  // Entertainment
  'entertainment': 'Entertainment',
  'movie': 'Entertainment',
  'cinema': 'Entertainment',
  'concert': 'Entertainment',
  'game': 'Entertainment',
  'fishing': 'Entertainment',
  'hobby': 'Entertainment',
  'hobbies': 'Entertainment',

  // Health
  'medical': 'Medical & Healthcare',
  'medical & healthcare': 'Medical & Healthcare',
  'healthcare': 'Medical & Healthcare',
  'doctor': 'Medical & Healthcare',
  'pharmacy': 'Medical & Healthcare',
  'medicine': 'Medical & Healthcare',
  'hospital': 'Medical & Healthcare',
  'fitness': 'Fitness & Gym',
  'fitness & gym': 'Fitness & Gym',
  'gym': 'Fitness & Gym',
  'workout': 'Fitness & Gym',
  'sports': 'Fitness & Gym',
  
  // Personal Care
  'personal care': 'Personal Care',
  'haircut': 'Personal Care',
  'salon': 'Personal Care',
  'barber': 'Personal Care',
  'grooming': 'Personal Care',
  'spa': 'Personal Care',
  'toilette': 'Personal Care',
  'toiletries': 'Personal Care',
  'hygiene': 'Personal Care',
  
  // Education
  'education': 'Education',
  'tuition': 'Education',
  'course': 'Education',
  'school': 'Education',
  
  // Loans, debts & leasing
  'loan payments': 'Loan Payments',
  'loan': 'Loan Payments',
  'loan payment': 'Loan Payments',
  'debts': 'Debts',
  'debt': 'Debts',
  'credit card': 'Debts',
  'credit card payment': 'Debts',
  'leasing': 'Leasing',
  'lease payment': 'Leasing',
  'car lease': 'Leasing',
  'vehicle lease': 'Leasing',
  'equipment lease': 'Leasing',
  
  // Income
  'salary': 'Salary',
  'income': 'Salary',
  'paycheck': 'Salary',
  'wage': 'Salary',
  'freelance': 'Freelance & Side Income',
  'freelance & side income': 'Freelance & Side Income',
  'side income': 'Freelance & Side Income',
  'bonus': 'Freelance & Side Income',
  
  // Other
  'other': 'Other',
  'misc': 'Other',
  'miscellaneous': 'Other'
};

// Context phrases checked first (longer = more specific). Order matters: e.g. "food delivery" must match before "food".
const CONTEXT_PHRASES: Array<{ phrase: string; category: string }> = [
  // Dining Out (check before "food" → Groceries)
  { phrase: 'food delivery', category: 'Dining Out' },
  { phrase: 'dining out', category: 'Dining Out' },
  { phrase: 'takeout', category: 'Dining Out' },
  { phrase: 'take out', category: 'Dining Out' },
  { phrase: 'fast food', category: 'Dining Out' },
  { phrase: 'restaurant', category: 'Dining Out' },
  { phrase: 'cafe', category: 'Dining Out' },
  { phrase: 'coffee shop', category: 'Dining Out' },
  { phrase: 'pizza', category: 'Dining Out' },
  { phrase: 'delivery', category: 'Dining Out' },
  { phrase: 'lunch', category: 'Dining Out' },
  { phrase: 'dinner', category: 'Dining Out' },
  { phrase: 'breakfast', category: 'Dining Out' },
  // Groceries (supermarket, food at home)
  { phrase: 'grocerries', category: 'Groceries' },
  { phrase: 'groceries', category: 'Groceries' },
  { phrase: 'grocery', category: 'Groceries' },
  { phrase: 'supermarket', category: 'Groceries' },
  { phrase: 'food shop', category: 'Groceries' },
  { phrase: 'food store', category: 'Groceries' },
  // Personal care
  { phrase: 'haircut', category: 'Personal Care' },
  { phrase: 'salon', category: 'Personal Care' },
  { phrase: 'barber', category: 'Personal Care' },
  { phrase: 'personal care', category: 'Personal Care' },
  // Streaming
  { phrase: 'streaming services', category: 'Streaming Services' },
  { phrase: 'streaming', category: 'Streaming Services' },
  { phrase: 'netflix', category: 'Streaming Services' },
  { phrase: 'spotify', category: 'Streaming Services' },
  { phrase: 'subscription', category: 'Streaming Services' },
  // Transport
  { phrase: 'rideshare & taxi', category: 'Rideshare & Taxi' },
  { phrase: 'rideshare', category: 'Rideshare & Taxi' },
  { phrase: 'uber', category: 'Rideshare & Taxi' },
  { phrase: 'lyft', category: 'Rideshare & Taxi' },
  { phrase: 'taxi', category: 'Rideshare & Taxi' },
  { phrase: 'public transportation', category: 'Public Transportation' },
  { phrase: 'gas & heating', category: 'Gas & Heating' },
  { phrase: 'gas bill', category: 'Gas & Heating' },
  { phrase: 'heating', category: 'Gas & Heating' },
  { phrase: 'gas & fuel', category: 'Gas & Fuel' },
  { phrase: 'gasoline', category: 'Gas & Fuel' },
  { phrase: 'gas station', category: 'Gas & Fuel' },
  { phrase: 'gas', category: 'Gas & Fuel' },
  { phrase: 'fuel', category: 'Gas & Fuel' },
  // Income (for add-income flow only)
  { phrase: 'freelance & side income', category: 'Freelance & Side Income' },
  { phrase: 'freelance', category: 'Freelance & Side Income' },
  { phrase: 'side income', category: 'Freelance & Side Income' },
  { phrase: 'salary', category: 'Salary' },
  { phrase: 'paycheck', category: 'Salary' },
  { phrase: 'wage', category: 'Salary' },
];

/**
 * Normalize category name to standard format
 * - Converts to proper case (not all caps)
 * - Maps common variations to standard names (context-aware: longer phrases first)
 * - Detects restaurant/fast food names and maps to "Dining Out"
 * - Returns "Other" as default
 */
export function normalizeCategory(category: string | null | undefined): string {
  if (!category || category.trim().length === 0) {
    return 'Other';
  }
  
  const trimmed = category.trim();
  const lowercased = trimmed.toLowerCase();
  
  // Special handling: Check if category contains restaurant/fast food chain names
  const restaurantChains = [
    'burger king', 'mcdonalds', 'mcdonald', 'kfc', 'subway', 'dominos', 'domino',
    'papa johns', 'taco bell', 'wendys', 'chipotle', 'panera', 'olive garden',
    'outback', 'applebees', 'chilis', 'red lobster', 'ihop', 'dennys', 'waffle house',
    'dunkin', 'dunkin donuts', 'five guys', 'shake shack', 'in-n-out', 'whataburger',
    'jack in the box', 'arbys', 'panda express', 'pizza hut', 'little caesars'
  ];
  
  for (const chain of restaurantChains) {
    if (lowercased.includes(chain) || chain.includes(lowercased)) {
      return 'Dining Out';
    }
  }
  
  // Context-aware: match longer phrases first so "food delivery" → Dining Out, not "food" → Groceries
  for (const { phrase, category } of CONTEXT_PHRASES) {
    if (lowercased.includes(phrase) || phrase.includes(lowercased)) {
      return category;
    }
  }
  
  // Check if it's already a standard category (case-insensitive)
  if (STANDARD_CATEGORIES[lowercased]) {
    return STANDARD_CATEGORIES[lowercased];
  }
  
  // Check if it matches any standard category (fuzzy match) — shorter keys may match now
  for (const [key, value] of Object.entries(STANDARD_CATEGORIES)) {
    if (lowercased.includes(key) || key.includes(lowercased)) {
      return value;
    }
  }
  
  // If it's all caps, convert to proper case
  if (trimmed === trimmed.toUpperCase() && trimmed.length > 1) {
    // Try to find match ignoring case
    for (const [key, value] of Object.entries(STANDARD_CATEGORIES)) {
      if (key.toUpperCase() === lowercased || value.toUpperCase() === trimmed) {
        return value;
      }
    }
    // If no match, convert first letter to uppercase, rest to lowercase
    return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
  }
  
  // Return as-is if it looks like proper case already
  if (trimmed.charAt(0) === trimmed.charAt(0).toUpperCase()) {
    return trimmed;
  }
  
  // Default: capitalize first letter
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
}
