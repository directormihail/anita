/**
 * Runs AI categorization on bank transactions that don't have a proper category yet.
 * Used after sync in refresh-bank-transactions and stripe webhook.
 */

import { SupabaseClient } from '@supabase/supabase-js';
import * as logger from './logger';
import { categorizeTransactionWithAI } from './transactionCategoryAI';

const NEEDS_CATEGORIZATION = ['', 'other', 'uncategorized', 'unclassified'];
const DELAY_MS = 350;

function needsCategorization(category: string | null | undefined): boolean {
  if (category == null) return true;
  const lower = category.trim().toLowerCase();
  return lower === '' || NEEDS_CATEGORIZATION.includes(lower);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Fetch uncategorized bank transactions for a user and run AI categorization on each.
 * Updates the category column. Runs sequentially with a short delay to avoid rate limits.
 */
export async function categorizeUncategorizedBankTransactions(
  supabase: SupabaseClient,
  userId: string,
  requestId?: string
): Promise<{ updated: number; failed: number }> {
  const { data: rows, error } = await supabase
    .from('bank_transactions')
    .select('id, merchant_name, description, amount_cents, category, raw_category')
    .eq('user_id', userId);

  if (error) {
    logger.error('categorizeUncategorizedBankTransactions: fetch error', {
      requestId,
      userId,
      error: error.message,
    });
    return { updated: 0, failed: 0 };
  }

  const toProcess = (rows || []).filter((r) =>
    needsCategorization((r as { category?: string | null }).category)
  );
  if (toProcess.length === 0) return { updated: 0, failed: 0 };

  let updated = 0;
  let failed = 0;

  for (const row of toProcess) {
    const r = row as {
      id: string;
      merchant_name?: string | null;
      description?: string | null;
      amount_cents: number;
      raw_category?: string | null;
    };
    try {
      const category = await categorizeTransactionWithAI(
        {
          merchant_name: r.merchant_name,
          description: r.description,
          amount_cents: r.amount_cents,
          raw_category: r.raw_category,
        },
        requestId
      );
      const { error: updateError } = await supabase
        .from('bank_transactions')
        .update({ category, updated_at: new Date().toISOString() })
        .eq('id', r.id);

      if (updateError) {
        logger.warn('categorizeUncategorizedBankTransactions: update failed', {
          requestId,
          id: r.id,
          error: updateError.message,
        });
        failed++;
      } else {
        updated++;
      }
    } catch (err) {
      logger.warn('categorizeUncategorizedBankTransactions: AI or update failed', {
        requestId,
        id: r.id,
        error: err instanceof Error ? err.message : String(err),
      });
      failed++;
    }
    await sleep(DELAY_MS);
  }

  if (updated > 0 || failed > 0) {
    logger.info('categorizeUncategorizedBankTransactions: done', {
      requestId,
      userId,
      updated,
      failed,
      totalProcessed: toProcess.length,
    });
  }

  return { updated, failed };
}
