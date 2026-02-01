/**
 * Transaction Description Generator
 * Uses AI to generate clean, meaningful transaction descriptions
 */

import { fetchWithTimeout, TIMEOUTS } from './timeout';
import * as logger from './logger';

// Lazy-load OpenAI config
function getOpenAIConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini'
  };
}

/**
 * Generate a clean, meaningful transaction description from user input
 * Examples:
 * - "10 Euros on Pizza" → "Pizza"
 * - "1200" → "Salary" (if income) or "Expense" (if expense)
 * - "I Sprint 37 Euros on groceries" → "Groceries"
 * - "Das 1200 as income" → "Salary"
 */
export async function generateTransactionDescription(
  userInput: string,
  type: 'income' | 'expense',
  amount: number,
  category: string,
  currencySymbol: string = '$'
): Promise<string> {
  const openaiConfig = getOpenAIConfig();
  const openaiApiKey = openaiConfig.apiKey;
  const openaiModel = openaiConfig.model;

  // If no API key, return a cleaned version of the input
  if (!openaiApiKey) {
    return cleanDescriptionFallback(userInput, type, amount, category);
  }

  // If the description is already clean and meaningful, return it
  if (isDescriptionClean(userInput)) {
    return userInput;
  }

  try {
    const prompt = `You are ANITA, a financial advisor AI. Generate a clean, concise transaction description for a mobile finance app.

USER INPUT: "${userInput}"
TRANSACTION TYPE: ${type}
AMOUNT: ${currencySymbol}${amount.toFixed(2)}
CATEGORY: ${category}

Generate a SHORT, CLEAN description (2-5 words max) that clearly describes what this transaction is about.

Rules:
- Remove filler words like "I spent", "on", "Euros", currency symbols, amounts
- Extract the core item/service (e.g., "Pizza", "Groceries", "Salary", "Rent")
- For income: Use professional terms (e.g., "Salary", "Freelance Payment", "Bonus")
- For expenses: Use item/service name (e.g., "Pizza", "Groceries", "Gas", "Rent")
- Keep it simple and clear
- Don't include amounts or currency in the description
- If the input is just a number, infer what it likely is based on type and category

Examples:
- "10 Euros on Pizza" → "Pizza"
- "1200" (income, Salary category) → "Salary"
- "I spent 37 Euros on groceries" → "Groceries"
- "Das 1200 as income" → "Salary"
- "1,50 on Toilette" → "Toiletries"
- "paid rent" → "Rent"

Return ONLY the description, nothing else.`;

    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: openaiModel,
          messages: [
            {
              role: 'system',
              content: 'You are a helpful assistant that generates clean, concise transaction descriptions for a finance app.'
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          max_tokens: 50,
          temperature: 0.3, // Lower temperature for more consistent, factual output
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );

    if (!response.ok) {
      logger.warn('OpenAI API error generating transaction description', { 
        status: response.status 
      });
      return cleanDescriptionFallback(userInput, type, amount, category);
    }

    const data = await response.json() as { choices?: Array<{ message?: { content?: string } }> };
    const generatedDescription = data.choices?.[0]?.message?.content?.trim();

    if (generatedDescription && generatedDescription.length > 0 && generatedDescription.length < 100) {
      return generatedDescription;
    }

    return cleanDescriptionFallback(userInput, type, amount, category);
  } catch (error) {
    logger.warn('Error generating transaction description', { 
      error: error instanceof Error ? error.message : 'Unknown' 
    });
    return cleanDescriptionFallback(userInput, type, amount, category);
  }
}

/**
 * Check if description is already clean and meaningful
 */
function isDescriptionClean(description: string): boolean {
  const trimmed = description.trim();
  
  // If it's just a number, it's not clean
  if (/^\d+([.,]\d+)?$/.test(trimmed)) {
    return false;
  }
  
  // If it's very short (1-2 words) and doesn't contain common filler words, it might be clean
  const words = trimmed.split(/\s+/).filter(w => w.length > 0);
  if (words.length <= 2) {
    const fillerWords = ['on', 'for', 'spent', 'paid', 'received', 'got', 'euros', 'dollars', '€', '$'];
    const hasFiller = words.some(w => fillerWords.includes(w.toLowerCase()));
    return !hasFiller;
  }
  
  // If it contains common patterns that indicate it needs cleaning
  const needsCleaning = /(spent|paid|received|got|on|for|euros?|dollars?|€|\$|\d+)/i.test(trimmed);
  return !needsCleaning;
}

/**
 * Fallback: Generate a clean description without AI
 */
function cleanDescriptionFallback(
  userInput: string,
  type: 'income' | 'expense',
  _amount: number,
  category: string
): string {
  const trimmed = userInput.trim();
  
  // If it's just a number, use category or type
  if (/^\d+([.,]\d+)?$/.test(trimmed)) {
    if (category && category !== 'Other') {
      return category;
    }
    return type === 'income' ? 'Income' : 'Expense';
  }
  
  // Remove common filler words and patterns
  let cleaned = trimmed
    .replace(/\b(spent|paid|received|got|earned|made|on|for|euros?|dollars?|€|\$)\b/gi, '')
    .replace(/\d+([.,]\d+)?\s*/g, '') // Remove amounts
    .replace(/^\s*(I|Das|Der|Die|Das)\s+/i, '') // Remove common sentence starters
    .trim();
  
  // Capitalize first letter
  if (cleaned.length > 0) {
    cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1).toLowerCase();
  }
  
  // If cleaned is empty or too short, use category
  if (cleaned.length < 2) {
    return category && category !== 'Other' ? category : (type === 'income' ? 'Income' : 'Expense');
  }
  
  // Limit length
  if (cleaned.length > 50) {
    cleaned = cleaned.substring(0, 47) + '...';
  }
  
  return cleaned;
}
