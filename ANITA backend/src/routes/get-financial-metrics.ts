/**
 * Get Financial Metrics API Route
 * Calculates and returns financial metrics (balance, income, expenses) from transactions
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleGetFinancialMetrics(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ 
      error: 'Method not allowed',
      message: `Method ${req.method} is not allowed. Use GET.`
    });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    const userId = req.query.userId as string;
    const month = req.query.month as string; // Format: "2024-01" (YYYY-MM)
    const year = req.query.year as string;

    if (!userId) {
      res.status(400).json({
        error: 'Missing userId',
        message: 'userId query parameter is required',
        requestId
      });
      return;
    }

    const supabase = getSupabaseClient();
    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is not properly configured',
        requestId
      });
      return;
    }

    // First, fetch ALL transactions for total balance calculation (all-time)
    const { data: allTransactionsData, error: allError } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .order('created_at', { ascending: true });

    if (allError) {
      logger.error('Error fetching all transactions for metrics', { error: allError.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch transactions',
        requestId
      });
      return;
    }

    // Monthly range (UTC)
    const toRange = (monthNum: number, yearNum: number) => ({
      start: new Date(Date.UTC(yearNum, monthNum, 1, 0, 0, 0, 0)).toISOString(),
      end: new Date(Date.UTC(yearNum, monthNum + 1, 0, 23, 59, 59, 999)).toISOString()
    });
    let monthStart: string;
    let monthEnd: string;
    if (month && year) {
      const range = toRange(parseInt(month as string) - 1, parseInt(year as string));
      monthStart = range.start;
      monthEnd = range.end;
    } else {
      const now = new Date();
      const range = toRange(now.getUTCMonth(), now.getUTCFullYear());
      monthStart = range.start;
      monthEnd = range.end;
    }

    // Fetch by transaction_date (persisted user date) and by created_at for legacy rows
    const [byTxDate, byCreated] = await Promise.all([
      supabase.from('anita_data').select('*').eq('account_id', userId).eq('data_type', 'transaction').gte('transaction_date', monthStart).lte('transaction_date', monthEnd).order('created_at', { ascending: true }),
      supabase.from('anita_data').select('*').eq('account_id', userId).eq('data_type', 'transaction').gte('created_at', monthStart).lte('created_at', monthEnd).order('created_at', { ascending: true })
    ]);

    let monthlyTransactionsData: any[];
    if (byTxDate.error || !byTxDate.data) {
      monthlyTransactionsData = byCreated.data || [];
    } else {
      const byTxDateIds = new Set((byTxDate.data || []).map((r: any) => r.message_id || r.id));
      const legacy = (byCreated.data || []).filter((r: any) => !byTxDateIds.has(r.message_id || r.id));
      monthlyTransactionsData = [...(byTxDate.data || []), ...legacy].sort((a: any, b: any) => {
        const tA = a.transaction_date || a.created_at || '';
        const tB = b.transaction_date || b.created_at || '';
        return tA.localeCompare(tB);
      });
    }

    if (byCreated.error) {
      logger.error('Error fetching monthly transactions for metrics', { error: byCreated.error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch monthly transactions',
        requestId
      });
      return;
    }

    // Fallback: include transfers from last 90 days that belong to this month (by transaction_date or created_at)
    // so we don't miss transfers when timezone or legacy rows put them in another month
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setUTCDate(ninetyDaysAgo.getUTCDate() - 90);
    const { data: recentTransfers } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .eq('transaction_type', 'transfer')
      .gte('created_at', ninetyDaysAgo.toISOString());
    const existingIds = new Set((monthlyTransactionsData || []).map((r: any) => r.message_id || r.id));
    const inMonth = (r: any) => {
      const d = r.transaction_date || r.created_at || '';
      return d >= monthStart && d <= monthEnd;
    };
    const extra = (recentTransfers || []).filter((r: any) => !existingIds.has(r.message_id || r.id) && inMonth(r));
    if (extra.length > 0) {
      monthlyTransactionsData = [...(monthlyTransactionsData || []), ...extra].sort((a: any, b: any) => {
        const tA = a.transaction_date || a.created_at || '';
        const tB = b.transaction_date || b.created_at || '';
        return tA.localeCompare(tB);
      });
    }

    // Helper: map raw rows to { type, amount }
    const mapTx = (item: any) => ({
      type: item.transaction_type || 'expense',
      category: (item.transaction_category || '').toLowerCase(),
      amount: Number(item.transaction_amount) || 0,
      date: item.transaction_date || item.created_at
    });

    // Calculate ALL-TIME metrics (income and expense only; transfers affect balance but not income/expense)
    const allTransactions = (allTransactionsData || []).map(mapTx);

    const totalIncome = allTransactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);

    const totalExpenses = allTransactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);

    // Funds Total (all-time): income minus expenses only. Transfers affect only each month's Available Funds.
    const totalBalance = totalIncome - totalExpenses;

    // Calculate MONTHLY metrics (for selected month)
    const monthlyTransactions = (monthlyTransactionsData || []).map(mapTx);

    const monthlyIncome = monthlyTransactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyExpenses = monthlyTransactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);

    // category is lowercased in mapTx; match "Transfer to goal" / "Transfer from goal" from iOS
    const monthlyTransfersToGoal = monthlyTransactions
      .filter(t => t.type === 'transfer' && t.category.includes('to goal'))
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyTransfersFromGoal = monthlyTransactions
      .filter(t => t.type === 'transfer' && t.category.includes('from goal'))
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyBalance = monthlyIncome - monthlyExpenses - monthlyTransfersToGoal + monthlyTransfersFromGoal;

    logger.info('Financial metrics computed', {
      requestId,
      userId,
      month: month || 'current',
      year: year || 'current',
      monthlyIncome,
      monthlyExpenses,
      monthlyTransfersToGoal,
      monthlyTransfersFromGoal,
      monthlyBalance,
      monthlyTxCount: (monthlyTransactionsData || []).length
    });

    res.status(200).json({
      success: true,
      metrics: {
        totalBalance,
        totalIncome,
        totalExpenses,
        monthlyIncome,
        monthlyExpenses,
        monthlyBalance
      },
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-financial-metrics', { 
      error: error instanceof Error ? error.message : 'Unknown error',
      requestId 
    });
    
    res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred',
      requestId
    });
  }
}

