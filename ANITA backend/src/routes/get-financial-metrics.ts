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

    // Fetch all transactions
    const { data, error } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .order('created_at', { ascending: true });

    if (error) {
      logger.error('Error fetching transactions for metrics', { error: error.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch transactions',
        requestId
      });
      return;
    }

    // Calculate metrics
    const transactions = (data || []).map((item: any) => ({
      type: item.transaction_type || 'expense',
      amount: Number(item.transaction_amount) || 0,
      date: item.transaction_date || item.created_at
    }));

    // Calculate total balance (all income - all expenses)
    const totalIncome = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);
    
    const totalExpenses = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);
    
    const totalBalance = totalIncome - totalExpenses;

    // Calculate monthly metrics (current month or specified month)
    let monthStart: Date;
    let monthEnd: Date;
    
    if (month && year) {
      // Use specified month
      const monthNum = parseInt(month) - 1; // JavaScript months are 0-indexed
      const yearNum = parseInt(year);
      monthStart = new Date(yearNum, monthNum, 1);
      monthEnd = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999);
    } else if (month) {
      // Format: "2024-01"
      const [yearStr, monthStr] = month.split('-');
      const monthNum = parseInt(monthStr) - 1;
      const yearNum = parseInt(yearStr);
      monthStart = new Date(yearNum, monthNum, 1);
      monthEnd = new Date(yearNum, monthNum + 1, 0, 23, 59, 59, 999);
    } else {
      // Default to current month
      const now = new Date();
      monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
    }
    
    const monthlyTransactions = transactions.filter(t => {
      const transactionDate = new Date(t.date);
      return transactionDate >= monthStart && transactionDate <= monthEnd;
    });

    const monthlyIncome = monthlyTransactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);
    
    const monthlyExpenses = monthlyTransactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);

    res.status(200).json({
      success: true,
      metrics: {
        totalBalance,
        totalIncome,
        totalExpenses,
        monthlyIncome,
        monthlyExpenses,
        monthlyBalance: monthlyIncome - monthlyExpenses
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

