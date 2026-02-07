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

    // Build query for monthly transactions (filtered by month/year if provided)
    let monthlyQuery = supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction');
    
    // Filter by month if provided
    if (month && year) {
      const monthNum = parseInt(month as string) - 1; // JavaScript months are 0-indexed
      const yearNum = parseInt(year as string);
      const monthStart = new Date(yearNum, monthNum, 1).toISOString();
      const monthEnd = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999).toISOString();
      monthlyQuery = monthlyQuery.gte('created_at', monthStart).lte('created_at', monthEnd);
    } else {
      // Default to current month if no month/year specified
      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999).toISOString();
      monthlyQuery = monthlyQuery.gte('created_at', monthStart).lte('created_at', monthEnd);
    }
    
    const { data: monthlyTransactionsData, error: monthlyError } = await monthlyQuery.order('created_at', { ascending: true });

    if (monthlyError) {
      logger.error('Error fetching monthly transactions for metrics', { error: monthlyError.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch monthly transactions',
        requestId
      });
      return;
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

    const monthlyTransfersToGoal = monthlyTransactions
      .filter(t => t.type === 'transfer' && t.category.includes('to goal'))
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyTransfersFromGoal = monthlyTransactions
      .filter(t => t.type === 'transfer' && t.category.includes('from goal'))
      .reduce((sum, t) => sum + t.amount, 0);

    const monthlyBalance = monthlyIncome - monthlyExpenses - monthlyTransfersToGoal + monthlyTransfersFromGoal;

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

