/**
 * AI-powered transaction categorization for bank transactions.
 * Same pattern as chat paywall: AI decides (no fixed keyword rules). We have millions of
 * different merchants—the AI reasons about each transaction and picks one category from
 * the canonical list. Rule-based is used only when the AI is unavailable (no key or failure).
 */

import { fetchWithTimeout, TIMEOUTS } from './timeout';
import * as logger from './logger';
import { CANONICAL_CATEGORIES, toCanonicalCategory } from './canonicalCategories';
import { categorizeBankTransactionByRules } from './categoryDetector';

const CATEGORY_LIST = CANONICAL_CATEGORIES.join(', ');

function getOpenAIConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
  };
}

export interface CategorizeInput {
  merchant_name?: string | null;
  description?: string | null;
  amount_cents: number;
  raw_category?: string | null;
}

/**
 * Categorize a single bank transaction using AI.
 * AI is the source of truth: it reasons about the transaction and picks one category.
 * Rule-based is used only when OpenAI is unavailable or the request fails.
 */
export async function categorizeTransactionWithAI(
  input: CategorizeInput,
  requestId?: string
): Promise<string> {
  const { merchant_name, description, amount_cents, raw_category } = input;
  const apiKey = getOpenAIConfig().apiKey;
  const model = getOpenAIConfig().model;

  if (!apiKey?.trim()) {
    logger.warn('Transaction category AI: OPENAI_API_KEY not set, using rule-based fallback', { requestId });
    return categorizeBankTransactionByRules(input);
  }

  const isIncome = amount_cents > 0;
  const amountAbs = Math.abs(amount_cents) / 100;
  const desc = [merchant_name, description].filter(Boolean).join(' — ') || 'Unknown';
  const typeLabel = isIncome ? 'income' : 'expense';

  const prompt = `You classify bank transactions into exactly one category. There are millions of different merchants and descriptions—no fixed list. You must REASON about what this transaction likely is (type of business, type of expense or income), then choose the single best category from the list below.

ALLOWED CATEGORIES (respond with exactly one, copy the name exactly including "&" and spacing):
${CATEGORY_LIST}

INSTRUCTIONS:
- Think step by step: What kind of business or payment is this? What would a reasonable person classify it as?
- Use the amount and sign (income vs expense) as context. Small expense at a vague name might be food or shopping; large income might be salary vs freelance.
- Do not match keywords literally. Infer meaning (e.g. "Rocket Rides" → transport; "Rocket Delivery" → food delivery; "Typographic" as income → likely client payment).
- Respond with ONLY the category name. No quotes, no explanation, no punctuation. One line only.

TRANSACTION:
Merchant/Description: ${desc}
Amount: ${amount_cents >= 0 ? '+' : ''}${amountAbs.toFixed(2)} (${typeLabel})
${raw_category ? `Bank suggested category (hint only): ${raw_category}` : ''}

Category:`;

  try {
    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: `You are a transaction categorizer. You reason about any merchant or description (millions of possibilities) and choose exactly one category from this list: ${CATEGORY_LIST}. Respond with only that category name, nothing else.`,
            },
            { role: 'user', content: prompt },
          ],
          max_tokens: 80,
          temperature: 0.15,
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );

    if (!response.ok) {
      const errBody = await response.text();
      logger.error('Transaction category AI: OpenAI API error, using rule-based categorization', {
        requestId,
        status: response.status,
        body: errBody.slice(0, 200),
      });
      return categorizeBankTransactionByRules(input);
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    let content = data.choices?.[0]?.message?.content?.trim();
    if (!content) {
      logger.warn('Transaction category AI: empty response, using rule-based fallback', { requestId });
      return categorizeBankTransactionByRules(input);
    }
    // If model added reasoning or "Category: X", use the category part only
    const lines = content.split(/\n/).map((s) => s.trim()).filter(Boolean);
    const lastLine = lines.length > 0 ? lines[lines.length - 1] : content;
    const afterColon = lastLine.replace(/^(?:category|answer):\s*/i, '').trim();
    if (afterColon) content = afterColon;

    const isIncome = amount_cents > 0;
    // AI is the source of truth: normalize its answer to a canonical category, do not override with rules
    const category = toCanonicalCategory(content, isIncome);
    logger.info('Transaction category AI: assigned', {
      requestId,
      merchant: merchant_name,
      amount_cents,
      assigned: category,
    });
    return category;
  } catch (error) {
    logger.error('Transaction category AI: request failed, using rule-based categorization', {
      requestId,
      error: error instanceof Error ? error.message : String(error),
    });
    return categorizeBankTransactionByRules(input);
  }
}
