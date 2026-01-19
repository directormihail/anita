/**
 * Update Transaction API Route
 * Updates a transaction in Supabase anita_data table
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

export async function handleUpdateTransaction(req: Request, res: Response): Promise<void> {
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
          message: 'Failed to parse request body as JSON',
          requestId
        });
        return;
      }
    }

    const { 
      transactionId, 
      userId, 
      type, // 'income' or 'expense'
      amount,
      category,
      description,
      date
    } = body;

    if (!transactionId || !userId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'transactionId and userId are required',
        requestId
      });
      return;
    }

    // Validate type if provided
    if (type !== undefined && type !== 'income' && type !== 'expense') {
      res.status(400).json({
        error: 'Invalid transaction type',
        message: 'type must be either "income" or "expense"',
        requestId
      });
      return;
    }

    // Validate amount if provided
    if (amount !== undefined && (typeof amount !== 'number' || amount <= 0)) {
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

    // Get existing transaction to use its description if needed
    const { data: existingTransaction } = await supabase
      .from('anita_data')
      .select('*')
      .eq('message_id', transactionId)
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .single();

    if (!existingTransaction) {
      res.status(404).json({
        error: 'Transaction not found',
        message: 'Transaction not found or you do not have permission to update it',
        requestId
      });
      return;
    }

    // Build update object with only provided fields
    const updateData: any = {
      updated_at: new Date().toISOString()
    };

    // Use provided description or existing one
    const finalDescription = description !== undefined ? description : existingTransaction.transaction_description || existingTransaction.message_text;
    const finalType = type !== undefined ? type : existingTransaction.transaction_type;
    const finalAmount = amount !== undefined ? amount : existingTransaction.transaction_amount;

    // Detect category from description if category is missing or "Other"
    let detectedCategory = category !== undefined ? category : existingTransaction.transaction_category;
    if (!detectedCategory || detectedCategory.trim().length === 0 || 
        detectedCategory.toLowerCase() === 'other') {
      detectedCategory = detectCategoryFromDescription(finalDescription, finalType as 'income' | 'expense');
      logger.info('Detected category from description', { 
        requestId, 
        description: finalDescription, 
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
    
    // Generate clean, meaningful transaction description using AI if description changed
    let finalTransactionDescription = finalDescription;
    if (description !== undefined) {
      try {
        const generatedDescription = await generateTransactionDescription(
          finalDescription,
          finalType as 'income' | 'expense',
          finalAmount,
          normalizedCategory,
          currencySymbol
        );
        finalTransactionDescription = generatedDescription;
        logger.info('Generated transaction description', { 
          requestId, 
          original: finalDescription, 
          generated: finalTransactionDescription 
        });
      } catch (error) {
        logger.warn('Failed to generate transaction description, using original', { 
          error: error instanceof Error ? error.message : 'Unknown',
          requestId 
        });
        // Use original description if generation fails
      }
    } else {
      // Use existing AI-generated description if available
      finalTransactionDescription = existingTransaction.transaction_description || finalDescription;
    }

    if (type !== undefined) {
      updateData.transaction_type = type;
    }
    if (amount !== undefined) {
      updateData.transaction_amount = Number(amount);
    }
    if (category !== undefined) {
      updateData.transaction_category = normalizedCategory;
    }
    if (description !== undefined) {
      updateData.message_text = description; // Keep original for reference
      updateData.transaction_description = finalTransactionDescription; // Use AI-generated clean description
    }
    if (date !== undefined) {
      updateData.created_at = new Date(date).toISOString();
    }

    // Update the transaction
    const { data, error } = await supabase
      .from('anita_data')
      .update(updateData)
      .eq('message_id', transactionId)
      .eq('account_id', userId)
      .eq('data_type', 'transaction')
      .select()
      .single();

    if (error) {
      logger.error('Error updating transaction', { error: error.message, requestId, transactionId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to update transaction',
        requestId
      });
      return;
    }

    if (!data) {
      res.status(404).json({
        error: 'Transaction not found',
        message: 'Transaction not found or you do not have permission to update it',
        requestId
      });
      return;
    }

    // Transform data to match expected format
    const updatedTransaction = {
      id: data.message_id || data.id,
      type: data.transaction_type || 'expense',
      amount: Number(data.transaction_amount) || 0,
      category: normalizeCategory(data.transaction_category),
      description: data.transaction_description || '',
      date: data.transaction_date || data.created_at
    };

    res.status(200).json({
      success: true,
      transaction: updatedTransaction,
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in update-transaction', { 
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
