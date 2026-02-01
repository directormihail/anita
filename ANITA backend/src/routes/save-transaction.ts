/**
 * Save Transaction API Route
 * Saves a transaction to Supabase anita_data table
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { normalizeCategory } from '../utils/categoryNormalizer';
import { detectCategoryFromDescription } from '../utils/categoryDetector';
import { generateTransactionDescription } from '../utils/transactionDescriptionGenerator';
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

export async function handleSaveTransaction(req: Request, res: Response): Promise<void> {
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ 
      error: 'Method not allowed',
      message: `Method ${req.method} is not allowed. Use POST.`
    });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    
    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        res.status(400).json({ 
          error: 'Invalid JSON in request body',
          message: 'Failed to parse request body as JSON'
        });
        return;
      }
    }

    const { 
      userId, 
      transactionId,
      type, // 'income' or 'expense'
      amount,
      category,
      description,
      date
    } = body;

    // Validate required fields
    if (!userId || !type || amount === undefined || !description) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'userId, type, amount, and description are required',
        requestId
      });
      return;
    }

    // Validate type
    if (type !== 'income' && type !== 'expense') {
      res.status(400).json({
        error: 'Invalid transaction type',
        message: 'type must be either "income" or "expense"',
        requestId
      });
      return;
    }

    // Validate amount
    if (typeof amount !== 'number' || amount <= 0) {
      res.status(400).json({
        error: 'Invalid amount',
        message: 'amount must be a positive number',
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

    // Check for duplicate transactions (same amount, type, and description within 5 minutes)
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { data: existingTransactions } = await supabase
      .from('anita_data')
      .select('id, message_id, transaction_amount, transaction_type, transaction_description, created_at')
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .eq('transaction_type', type)
      .eq('transaction_amount', amount)
      .gte('created_at', fiveMinutesAgo);

    if (existingTransactions && existingTransactions.length > 0) {
      // Check if description is similar (basic duplicate check)
      const isDuplicate = existingTransactions.some((t: any) => {
        const existingDesc = t.transaction_description || '';
        return existingDesc.toLowerCase().trim() === description.toLowerCase().trim();
      });

      if (isDuplicate) {
        logger.warn('Duplicate transaction detected', { requestId, userId, type, amount });
        res.status(200).json({
          success: true,
          message: 'Duplicate transaction - already exists',
          duplicate: true,
          requestId
        });
        return;
      }
    }

    // Detect category from description if category is missing or "Other"
    let detectedCategory = category;
    if (!detectedCategory || detectedCategory.trim().length === 0 || 
        detectedCategory.toLowerCase() === 'other') {
      detectedCategory = detectCategoryFromDescription(description, type as 'income' | 'expense');
      logger.info('Detected category from description', { 
        requestId, 
        description, 
        detectedCategory 
      });
    }
    
    // Normalize category to ensure proper formatting (not all caps)
    const normalizedCategory = normalizeCategory(detectedCategory);
    
    // Get currency symbol for description generation
    let currencySymbol = '$';
    try {
      const { data: profileData } = await supabase
        .from('profiles')
        .select('currency_code')
        .eq('id', userId)
        .single();
      
      if (profileData?.currency_code) {
        const currencySymbols: { [key: string]: string } = {
          'USD': '$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'CAD': 'C$',
          'AUD': 'A$', 'CHF': 'CHF', 'CNY': '¥', 'INR': '₹', 'BRL': 'R$',
          'MXN': 'MX$', 'SGD': 'S$', 'HKD': 'HK$', 'NZD': 'NZ$', 'ZAR': 'R'
        };
        currencySymbol = currencySymbols[profileData.currency_code] || '$';
      }
    } catch (error) {
      // Use default if currency lookup fails
    }
    
    // Generate clean, meaningful transaction description using AI
    let finalDescription = description;
    try {
      const generatedDescription = await generateTransactionDescription(
        description,
        type as 'income' | 'expense',
        amount,
        normalizedCategory,
        currencySymbol
      );
      finalDescription = generatedDescription;
      logger.info('Generated transaction description', { 
        requestId, 
        original: description, 
        generated: finalDescription 
      });
    } catch (error) {
      logger.warn('Failed to generate transaction description, using original', { 
        error: error instanceof Error ? error.message : 'Unknown',
        requestId 
      });
      // Use original description if generation fails
    }
    
    // Prepare transaction data
    const transactionData: any = {
      account_id: userId,
      message_text: description, // Keep original for reference
      transaction_type: type,
      transaction_amount: amount,
      transaction_category: normalizedCategory,
      transaction_description: finalDescription, // Use AI-generated clean description
      data_type: 'transaction',
      message_id: transactionId || `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      created_at: date ? new Date(date).toISOString() : new Date().toISOString()
    };

    // Save transaction to anita_data table
    const { error } = await supabase
      .from('anita_data')
      .insert([transactionData])
      .select()
      .single();

    if (error) {
      logger.error('Error saving transaction', { error: error.message, requestId, userId, type, amount });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to save transaction',
        requestId
      });
      return;
    }

    logger.info('Transaction saved successfully', { requestId, userId, type, amount, transactionId: transactionData.message_id });

    res.status(200).json({
      success: true,
      transaction: {
        id: transactionData.message_id,
        type: type,
        amount: amount,
        category: normalizedCategory,
        description: finalDescription, // Return the clean, AI-generated description
        date: transactionData.created_at
      },
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in save-transaction', { 
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

