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
    if (type !== 'income' && type !== 'expense' && type !== 'transfer') {
      res.status(400).json({
        error: 'Invalid transaction type',
        message: 'type must be "income", "expense", or "transfer"',
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

    // Allow multiple transactions with the same amount/description (e.g. two lunches, two coffees)

    const isTransfer = type === 'transfer';

    // For transfers: use category and description as-is (no AI). For income/expense: detect category and optionally AI description.
    let detectedCategory = category;
    let normalizedCategory: string;
    let finalDescription: string;

    if (isTransfer) {
      normalizedCategory = (category && category.trim().length > 0)
        ? normalizeCategory(category)
        : 'Transfer';
      finalDescription = description;
    } else {
      if (!detectedCategory || detectedCategory.trim().length === 0 ||
          detectedCategory.toLowerCase() === 'other') {
        detectedCategory = detectCategoryFromDescription(description, type as 'income' | 'expense');
        logger.info('Detected category from description', {
          requestId,
          description,
          detectedCategory
        });
      }
      normalizedCategory = normalizeCategory(detectedCategory);

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
        finalDescription = description;
      }
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

    // Ensure XP rule exists (works even if migration not run)
    await supabase.from('xp_rules').upsert(
      {
        id: 'transaction_added',
        category: 'Engagement',
        name: 'Add a transaction',
        xp_amount: 10,
        description: 'Add any income, expense, or transfer',
        frequency: 'event',
        extra_meta: {},
        updated_at: new Date().toISOString()
      },
      { onConflict: 'id' }
    );

    // Award 10 XP for adding any transaction; stored in user_xp_events and user_xp_stats
    const { error: xpError } = await supabase.rpc('award_xp', {
      p_user_id: userId,
      p_rule_id: 'transaction_added',
      p_metadata: {}
    });
    if (xpError) {
      logger.warn('award_xp RPC failed, inserting XP event directly', {
        requestId,
        userId,
        error: xpError.message
      });
      // Fallback: insert XP event so get-xp-stats sees the new XP
      const eventId = `xp_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
      const { error: insertErr } = await supabase.from('user_xp_events').insert({
        id: eventId,
        user_id: userId,
        rule_id: 'transaction_added',
        xp_amount: 10,
        description: 'Add any income, expense, or transfer',
        metadata: {}
      });
      if (insertErr) {
        logger.error('Failed to insert XP event fallback', { requestId, userId, error: insertErr.message });
      }
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

