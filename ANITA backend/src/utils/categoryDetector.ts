/**
 * Category Detector
 * Detects transaction category from description text
 * Uses pattern matching and keyword detection
 */

/**
 * Detect category from transaction description
 * Returns normalized category name
 */
export function detectCategoryFromDescription(
  description: string,
  type: 'income' | 'expense'
): string {
  if (!description || description.trim().length === 0) {
    return 'Other';
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

  // Groceries
  const groceryKeywords = ['grocery', 'groceries', 'supermarket', 'food store', 'food shopping'];
  for (const keyword of groceryKeywords) {
    if (lowercased.includes(keyword)) {
      return 'Groceries';
    }
  }

  // Transportation
  if (lowercased.includes('uber') || lowercased.includes('lyft') || 
      lowercased.includes('taxi') || lowercased.includes('cab') || 
      lowercased.includes('rideshare')) {
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
      lowercased.includes('lease') || lowercased.includes('landlord')) {
    return 'Rent';
  }
  if (lowercased.includes('mortgage') || lowercased.includes('home loan')) {
    return 'Mortgage';
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

  // Default for expenses
  return 'Other';
}
