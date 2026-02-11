/**
 * Chat Completion API Route
 * Handles chat requests with OpenAI GPT
 */

import { Request, Response } from 'express';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeChatMessage } from '../utils/sanitizeInput';
import { fetchWithTimeout, TIMEOUTS } from '../utils/timeout';
import { normalizeCategory } from '../utils/categoryNormalizer';
import { createClient } from '@supabase/supabase-js';
import * as logger from '../utils/logger';

// Lazy-load environment variables to ensure they're loaded after dotenv.config()
function getOpenAIConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY,
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini'
  };
}

// Lazy-load Supabase client to ensure env vars are loaded
function getSupabaseClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (supabaseUrl && supabaseServiceKey) {
    return createClient(supabaseUrl, supabaseServiceKey);
  }
  return null;
}

export async function handleChatCompletion(req: Request, res: Response): Promise<void> {
  // Apply security headers
  applySecurityHeaders(res);

  // Handle OPTIONS preflight
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
    
    // Get OpenAI config (lazy-loaded to ensure env vars are available)
    const openaiConfig = getOpenAIConfig();
    const openaiApiKey = openaiConfig.apiKey;
    const openaiModel = openaiConfig.model;
    
    // Validate API key
    if (!openaiApiKey) {
      logger.error('OpenAI API key not configured', { requestId });
      res.status(500).json({ 
        error: 'OpenAI API key not configured',
        message: 'Please set OPENAI_API_KEY environment variable',
        requestId
      });
      return;
    }

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

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.CHAT_COMPLETION, 'chat-completion');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'chat-completion', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    const { messages, maxTokens = 1200, temperature = 0.8, userId, conversationId } = body;

    // Validate messages array
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ 
        error: 'Invalid messages array',
        message: 'messages must be a non-empty array'
      });
      return;
    }

    // Validate and sanitize message structure
    const sanitizedMessages = [];
    for (const msg of messages) {
      if (!msg || typeof msg !== 'object' || !msg.role || !msg.content) {
        res.status(400).json({ 
          error: 'Invalid message format',
          message: 'Each message must have "role" and "content" fields'
        });
        return;
      }
      
      // Sanitize content
      sanitizedMessages.push({
        role: msg.role,
        content: sanitizeChatMessage(msg.content)
      });
    }

    // Build context-aware system prompt if userId is provided (conversationId is optional)
    // This ensures the AI has access to user's financial data and strict pattern rules on every request
    let systemPrompt: string | null = null;
    const supabase = getSupabaseClient();
    if (userId && supabase) {
      try {
        // Use conversationId if provided, otherwise use empty string (will still fetch transactions)
        systemPrompt = await buildSystemPrompt(userId, conversationId || '');
        // Always insert backend system prompt at the beginning, even if the client already sent a system message.
        // This guarantees Anita always sees the database snapshot + pattern rules first.
        if (systemPrompt) {
          sanitizedMessages.unshift({
            role: 'system',
            content: systemPrompt
          });
        }
        logger.info('System prompt built successfully', { 
          requestId,
          hasConversationId: !!conversationId,
          messageCount: sanitizedMessages.length
        });
      } catch (error) {
        logger.warn('Failed to build system prompt, using default', { 
          error: error instanceof Error ? error.message : 'Unknown',
          requestId 
        });
        // Continue without context if building fails
      }
    } else {
      logger.warn('Cannot build system prompt: missing userId or supabase', { 
        requestId,
        hasUserId: !!userId,
        hasSupabase: !!supabase
      });
    }

    // Call OpenAI API with timeout (prevents hanging requests)
    logger.info('Calling OpenAI API', { requestId, messageCount: sanitizedMessages.length });
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
          messages: sanitizedMessages,
          max_tokens: maxTokens,
          temperature,
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );

    if (!response.ok) {
      const errorData = (await response.json().catch(() => ({}))) as { error?: { message?: string } };
      logger.error('OpenAI API request failed', { 
        status: response.status, 
        error: errorData.error?.message,
        requestId 
      });
      res.status(500).json({ 
        error: 'OpenAI API request failed',
        message: errorData.error?.message || `OpenAI API returned status ${response.status}`,
        requestId
      });
      return;
    }

    const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const aiResponse = data.choices?.[0]?.message?.content;

    if (!aiResponse) {
      logger.error('No response from OpenAI', { requestId });
      res.status(500).json({ 
        error: 'No response from OpenAI',
        message: 'The API response did not contain a valid message',
        requestId
      });
      return;
    }

    // Response we will send: only show confirmation if we actually persisted. Override if we detected intent but DB failed.
    let finalResponse = aiResponse;

    // When AI confirms it added an expense/income, persist the transaction to the database
    // so it appears in the transactions list (client may have gone through backend flow only).
    if (userId && supabase) {
      try {
        const tx = parseTransactionFromAiResponse(sanitizedMessages, aiResponse);
        if (tx) {
          const transactionData: any = {
            account_id: userId,
            message_text: tx.description,
            transaction_type: tx.type,
            transaction_amount: tx.amount,
            transaction_category: normalizeCategory(tx.category),
            transaction_description: tx.description,
            data_type: 'transaction',
            message_id: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            created_at: new Date().toISOString()
          };
          const { error } = await supabase
            .from('anita_data')
            .insert([transactionData])
            .select()
            .single();
          if (error) {
            logger.warn('Failed to persist AI-confirmed transaction', { error: error.message, requestId, type: tx.type, amount: tx.amount });
            finalResponse = "I couldn't save that transaction. Please try again or add it from the Finance page.";
          } else {
            logger.info('Persisted AI-confirmed transaction', { requestId, userId, type: tx.type, amount: tx.amount, category: tx.category });
            // Award XP for adding transaction (same as save-transaction)
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
            const { error: xpError } = await supabase.rpc('award_xp', {
              p_user_id: userId,
              p_rule_id: 'transaction_added',
              p_metadata: {}
            });
            if (xpError) {
              logger.warn('award_xp RPC failed after AI transaction', { requestId, userId, error: xpError.message });
            }
          }
        }
      } catch (err) {
        logger.warn('Error persisting AI-confirmed transaction', { error: err instanceof Error ? err.message : 'Unknown', requestId });
      }
    }

    // Automatically create target if detected in conversation
    if (userId && supabase) {
      try {
        const targetInfo = parseTargetFromConversation(sanitizedMessages, aiResponse);
        if (targetInfo) {
          logger.info('Target detected in conversation, creating automatically', { 
            requestId, 
            userId, 
            title: targetInfo.title,
            amount: targetInfo.amount,
            currency: targetInfo.currency
          });
          
          // Get user currency preference
          let userCurrency = 'EUR';
          try {
            const { data: profileData } = await supabase
              .from('profiles')
              .select('currency_code')
              .eq('id', userId)
              .single();
            
            if (profileData?.currency_code) {
              userCurrency = profileData.currency_code;
            }
          } catch (error) {
            // Use default currency if profile fetch fails
          }

          const targetData: any = {
            account_id: userId,
            title: targetInfo.title,
            description: targetInfo.description || null,
            target_amount: targetInfo.amount,
            current_amount: 0,
            currency: targetInfo.currency || userCurrency,
            status: 'active',
            target_type: 'savings',
            priority: 'medium',
            auto_update: false
          };

          if (targetInfo.date) {
            targetData.target_date = targetInfo.date;
          }

          const { data: createdTarget, error: targetError } = await supabase
            .from('targets')
            .insert([targetData])
            .select()
            .single();

          if (targetError) {
            logger.warn('Failed to auto-create target', { error: targetError.message, requestId });
            finalResponse = "I couldn't create that goal. Please try again or add it from the Finance page.";
          } else {
            logger.info('Target auto-created successfully', { requestId, targetId: createdTarget.id, title: targetInfo.title });
            // Store target ID to include in response
            (res as any).createdTargetId = createdTarget.id;
            (res as any).createdTargetType = 'savings'; // Explicitly set type
          }
        } else {
          // Log when target is not detected (for debugging)
          const lastUserMessage = sanitizedMessages.filter(m => m.role === 'user').pop()?.content || '';
          const aiConfirms = /(?:got it|noted|saved|created|set|great|perfect|done).*?(?:target|goal|savings goal)/i.test(aiResponse);
          if (aiConfirms) {
            logger.debug('AI confirmed target but parsing failed', { 
              requestId, 
              lastUserMessage: lastUserMessage.substring(0, 100),
              aiResponsePreview: aiResponse.substring(0, 200)
            });
          }
        }
      } catch (error) {
        logger.warn('Error in auto-target creation', { error: error instanceof Error ? error.message : 'Unknown', requestId });
        // Don't fail the request if target parsing/creation fails
      }
    }

    // Automatically create budget targets (spending limits) when analytics are requested
    if (userId && supabase) {
      try {
        // Check if this is an analytics request or limit setting request
        const userMessages = sanitizedMessages.filter(msg => msg.role === 'user').map(msg => msg.content.toLowerCase());
        const lastUserMessage = userMessages[userMessages.length - 1] || '';
        
        const isAnalyticsRequest = sanitizedMessages.some(msg => 
          msg.role === 'user' && 
          (msg.content.toLowerCase().includes('analytics') || 
           msg.content.toLowerCase().includes('analyze') ||
           msg.content.toLowerCase().includes('show analytics') ||
           msg.content.toLowerCase().includes('spending insights'))
        );
        
        // Check if user wants to set a spending limit (not a savings goal)
        const isLimitRequest = lastUserMessage.includes('spending limit') || 
                               lastUserMessage.includes('set a limit') ||
                               lastUserMessage.includes('set limit') ||
                               lastUserMessage.includes('lets take') ||
                               lastUserMessage.includes("let's take") ||
                               lastUserMessage.includes('let\'s set') ||
                               lastUserMessage.includes('set limit for') ||
                               lastUserMessage.includes('limit for') ||
                               lastUserMessage.includes('yes') && (aiResponse.toLowerCase().includes('limit') || aiResponse.toLowerCase().includes('target')) ||
                               lastUserMessage.includes('set it') ||
                               lastUserMessage.includes('create it') ||
                               (lastUserMessage.includes('limit') && !lastUserMessage.includes('goal') && !lastUserMessage.includes('target'));
        
        // Check if AI response contains limit recommendations (even if user didn't explicitly say "limit")
        const aiHasLimitRecommendations = aiResponse.includes('target $') || 
                                         aiResponse.includes('target €') ||
                                         aiResponse.includes('target £') ||
                                         aiResponse.includes('— target') ||
                                         aiResponse.includes('– target') ||
                                         /target\s+[$€£¥]?\s*\d+(?:\.\d+)?/i.test(aiResponse);
        
        // Check if user is choosing a specific category for a limit (e.g., "let's take dining out", "set limit for groceries")
        const isCategorySelection = (isLimitRequest || aiHasLimitRecommendations) && (
          lastUserMessage.includes('dining out') ||
          lastUserMessage.includes('groceries') ||
          lastUserMessage.includes('shopping') ||
          lastUserMessage.includes('entertainment') ||
          lastUserMessage.includes('transportation') ||
          lastUserMessage.includes('rent') ||
          lastUserMessage.includes('gas') ||
          lastUserMessage.includes('food') ||
          lastUserMessage.match(/\b(set|take|choose|limit|for)\s+[a-z\s&]+\b/i) !== null
        );
        
        // Also check if AI response mentions setting a limit or contains recommendations
        const shouldCreateBudgetTargets = isAnalyticsRequest || isLimitRequest || aiHasLimitRecommendations;

        if (shouldCreateBudgetTargets) {
          // First check if AI confirmed it set a limit (e.g. "I've set a limit for Dining Out at target $59.22")
          // so we persist it to the database and it shows on the Finance page
          const limitConfirmation = parseLimitConfirmationFromAiResponse(aiResponse);
          const hadLimitConfirmation = !!limitConfirmation;
          let budgetRecommendations: Array<{ category: string; amount: number; currency?: string }> | null =
            limitConfirmation ? [limitConfirmation] : parseBudgetRecommendations(aiResponse);

          // Fallback: user confirmed with "Do it" / "Yes" but AI didn't output the exact phrase — get suggestion from previous AI message
          let createdLimitFromFallback = false;
          const isUserConfirmation = /^(do it|yes|sure|set it|create it|proceed|please|sounds good|go ahead|ok|okay)$/i.test(lastUserMessage.trim());
          if (!budgetRecommendations?.length && isUserConfirmation) {
            const prevAssistantMessage = [...sanitizedMessages].reverse().find((m: { role: string }) => m.role === 'assistant')?.content || '';
            const suggestion = parseLimitSuggestionFromMessage(prevAssistantMessage);
            if (suggestion) {
              budgetRecommendations = [suggestion];
              createdLimitFromFallback = true;
              logger.info('Limit suggestion parsed from previous message (user confirmed)', {
                requestId,
                category: suggestion.category,
                amount: suggestion.amount
              });
            }
          }

          // If no recommendations found in AI response but user selected a category, 
          // try to extract category from user message and create recommendation
          if ((!budgetRecommendations || budgetRecommendations.length === 0) && isCategorySelection) {
            const categoryFromMessage = extractCategoryFromMessage(lastUserMessage);
            if (categoryFromMessage) {
              // Get current spending for this category to recommend a limit
              try {
                const { data: transactionsData } = await supabase
                  .from('anita_data')
                  .select('*')
                  .eq('account_id', userId)
                  .eq('data_type', 'transaction')
                  .eq('transaction_type', 'expense');
                
                if (transactionsData) {
                  const categorySpending = transactionsData
                    .filter((t: any) => {
                      const category = normalizeCategory(t.transaction_category || '');
                      return category.toLowerCase() === categoryFromMessage.toLowerCase();
                    })
                    .reduce((sum: number, t: any) => sum + (Number(t.transaction_amount) || 0), 0);
                  
                  if (categorySpending > 0) {
                    // Recommend 15% reduction
                    const recommendedAmount = Math.round(categorySpending * 0.85 * 100) / 100;
                    budgetRecommendations = [{
                      category: categoryFromMessage,
                      amount: recommendedAmount
                    }];
                    logger.info('Created budget recommendation from user category selection', {
                      requestId,
                      category: categoryFromMessage,
                      currentSpending: categorySpending,
                      recommendedAmount
                    });
                  }
                }
              } catch (error) {
                logger.warn('Failed to get category spending for limit recommendation', { error: error instanceof Error ? error.message : 'Unknown' });
              }
            }
          }
          
          // Log for debugging
          logger.info('Budget target creation check', {
            requestId,
            userId,
            isAnalyticsRequest,
            isLimitRequest,
            aiHasLimitRecommendations: aiHasLimitRecommendations || false,
            shouldCreateBudgetTargets,
            hasRecommendations: !!(budgetRecommendations && budgetRecommendations.length > 0),
            recommendationCount: budgetRecommendations?.length || 0
          });
          
          if (budgetRecommendations && budgetRecommendations.length > 0) {
            logger.info('Budget recommendations detected, creating automatically', { 
              requestId, 
              userId, 
              count: budgetRecommendations.length,
              recommendations: budgetRecommendations.map(r => `${r.category}: ${r.amount}`)
            });
            
            // Get user currency preference
            let userCurrency = 'EUR';
            try {
              const { data: profileData } = await supabase
                .from('profiles')
                .select('currency_code')
                .eq('id', userId)
                .single();
              
              if (profileData?.currency_code) {
                userCurrency = profileData.currency_code;
              }
            } catch (error) {
              // Use default currency if profile fetch fails
            }

            // Check existing budget targets to avoid duplicates
            const { data: existingTargets } = await supabase
              .from('targets')
              .select('category')
              .eq('account_id', userId)
              .eq('target_type', 'budget')
              .eq('status', 'active');

            const existingCategories = new Set(
              (existingTargets || [])
                .map((t: any) => t.category?.toLowerCase())
                .filter((c: string) => c)
            );

            const createdTargetIds: string[] = [];
            
            for (const recommendation of budgetRecommendations) {
              // Skip if budget target already exists for this category
              if (recommendation.category && existingCategories.has(recommendation.category.toLowerCase())) {
                logger.info('Budget target already exists for category', { 
                  requestId, 
                  category: recommendation.category 
                });
                continue;
              }

              const targetData: any = {
                account_id: userId,
                title: `Monthly Limit: ${recommendation.category}`,
                description: `AI-recommended spending limit for ${recommendation.category}`,
                target_amount: recommendation.amount,
                current_amount: 0,
                currency: recommendation.currency || userCurrency,
                status: 'active',
                target_type: 'budget',
                category: recommendation.category,
                priority: 'medium',
                auto_update: true // Enable auto-update for budget targets
              };

              const { data: createdTarget, error: targetError } = await supabase
                .from('targets')
                .insert([targetData])
                .select()
                .single();

              if (targetError) {
                logger.warn('Failed to auto-create budget target', { 
                  error: targetError.message, 
                  requestId,
                  category: recommendation.category 
                });
              } else {
                logger.info('Budget target auto-created successfully', { 
                  requestId, 
                  targetId: createdTarget.id, 
                  category: recommendation.category,
                  amount: recommendation.amount
                });
                createdTargetIds.push(createdTarget.id);
              }
            }

            // Store created target IDs to include in response
            if (createdTargetIds.length > 0) {
              (res as any).createdBudgetTargetIds = createdTargetIds;
              // Also set targetId to the first budget target for compatibility
              (res as any).createdTargetId = createdTargetIds[0];
              (res as any).createdTargetType = 'budget';
              // Store category from first recommendation
              if (budgetRecommendations.length > 0) {
                (res as any).createdTargetCategory = budgetRecommendations[0].category;
              }
            } else if (hadLimitConfirmation) {
              // AI said "I've set a limit" but we didn't actually create it — don't show false confirmation
              finalResponse = "I couldn't set that limit. Please try again or add it from the Finance page.";
            }
            // When we created from fallback (user said "Do it"), ensure we show the confirmation message
            if (createdLimitFromFallback && createdTargetIds.length > 0 && budgetRecommendations?.length > 0) {
              const rec = budgetRecommendations[0];
              const sym = rec.currency === 'USD' ? '$' : rec.currency === 'GBP' ? '£' : rec.currency === 'JPY' ? '¥' : '€';
              finalResponse = `I've set a limit for ${rec.category} at target ${sym}${rec.amount.toFixed(2)}. ✅ You can review your limit now.`;
            }
          }
        }
      } catch (error) {
        logger.warn('Error in auto-budget target creation', { 
          error: error instanceof Error ? error.message : 'Unknown', 
          requestId 
        });
        // Don't fail the request if budget target parsing/creation fails
      }
    }

    logger.info('Chat completion successful', { requestId });
    const responseData: any = { 
      response: finalResponse,
      requestId
    };
    
    // Include target ID if one was created (for savings goals)
    if ((res as any).createdTargetId && !(res as any).createdTargetType) {
      responseData.targetId = (res as any).createdTargetId;
      responseData.targetType = 'savings';
    }
    
    // Include budget target info if any were created (spending limits)
    if ((res as any).createdBudgetTargetIds && (res as any).createdBudgetTargetIds.length > 0) {
      responseData.targetId = (res as any).createdTargetId; // First budget target ID
      responseData.targetType = 'budget';
      responseData.budgetTargetIds = (res as any).createdBudgetTargetIds;
      responseData.category = (res as any).createdTargetCategory; // Category for filtering transactions
    }
    
    res.status(200).json(responseData);

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    const errorMessage = error instanceof Error ? error.message : 'Unknown';
    
    // Check if it's a timeout error
    if (errorMessage.includes('timeout')) {
      logger.error('Request timeout in chat completion', { error: errorMessage, requestId });
      res.status(504).json({ 
        error: 'Request timeout',
        message: 'The AI request took too long. Please try again.',
        requestId
      });
      return;
    }
    
    logger.error('Unexpected error in chat completion', { error: errorMessage, requestId });
    res.status(500).json({ 
      error: 'Internal server error',
      message: errorMessage,
      requestId
    });
  }
}

/**
 * Parse transaction from AI response when it confirms an expense/income was added.
 * e.g. "I've added your expense of $21.00 for Personal Care (Haircut)."
 * Returns { type, amount, category, description } or null if not a transaction confirmation.
 */
export function parseTransactionFromAiResponse(
  messages: Array<{ role: string; content: string }>,
  aiResponse: string
): { type: 'expense' | 'income'; amount: number; category: string; description: string } | null {
  const r = aiResponse.trim();

  // AI confirmed it added a transaction
  const addedExpense = /(?:I've added your expense|added your expense|I've noted your .*?expense|noted your .*?expense)/i.test(r);
  const addedIncome = /(?:I've added your income|added your income|I've noted your .*?income|noted your .*?income)/i.test(r);
  const type: 'expense' | 'income' | null = addedExpense ? 'expense' : addedIncome ? 'income' : null;
  if (!type) return null;

  // Amount: e.g. "$21.00", "21.00", "of $21"
  const amountMatch = r.match(/(?:of\s+)?[$€£¥]?\s*(\d+(?:[.,]\d{2})?|\d+)/);
  const amountStr = amountMatch ? amountMatch[1].replace(',', '.') : null;
  const amount = amountStr ? parseFloat(amountStr) : NaN;
  if (!amountMatch || !Number.isFinite(amount) || amount <= 0) return null;

  // Category: "for Personal Care" or "under Personal Care"
  const categoryMatch = r.match(/(?:for|under)\s+([^.().]+?)(?:\s*\(|\.|,|\s*$)/i);
  let category = (categoryMatch ? categoryMatch[1].trim() : null) || 'Other';

  // Description: from parentheses "(Haircut)" or last user message
  const parenMatch = r.match(/\(([^)]+)\)/);
  const lastUserMessage = messages.filter(m => m.role === 'user').pop()?.content?.trim() || '';
  const description = (parenMatch ? parenMatch[1].trim() : null) || lastUserMessage || `${type} ${amount}`;

  return { type, amount, category, description };
}

/**
 * Extract category name from user message (e.g., "let's take dining out" -> "Dining Out")
 */
function extractCategoryFromMessage(message: string): string | null {
  const lowerMessage = message.toLowerCase();
  
  // Common category patterns
  const categoryPatterns: { [key: string]: string } = {
    'dining out': 'Dining Out',
    'dining': 'Dining Out',
    'restaurant': 'Dining Out',
    'groceries': 'Groceries',
    'grocery': 'Groceries',
    'shopping': 'Shopping',
    'entertainment': 'Entertainment',
    'transportation': 'Public Transportation',
    'gas': 'Gas & Fuel',
    'fuel': 'Gas & Fuel',
    'rent': 'Rent',
    'mortgage': 'Mortgage',
    'utilities': 'Electricity',
    'electricity': 'Electricity',
    'internet': 'Internet & Phone',
    'phone': 'Internet & Phone',
    'streaming': 'Streaming Services',
    'subscription': 'Streaming Services',
    'medical': 'Medical & Healthcare',
    'healthcare': 'Medical & Healthcare',
    'fitness': 'Fitness & Gym',
    'gym': 'Fitness & Gym',
    'personal care': 'Personal Care',
    'clothing': 'Clothing & Fashion',
    'fashion': 'Clothing & Fashion',
    'education': 'Education'
  };
  
  // Try to match category names
  for (const [pattern, category] of Object.entries(categoryPatterns)) {
    if (lowerMessage.includes(pattern)) {
      return category;
    }
  }
  
  // Try to extract after "take", "for", "set limit for", etc.
  const extractionPatterns = [
    /(?:take|for|set\s+limit\s+for|choose|select)\s+([a-z\s&]+?)(?:\s|$|,|\.)/i,
    /limit\s+for\s+([a-z\s&]+?)(?:\s|$|,|\.)/i
  ];
  
  for (const pattern of extractionPatterns) {
    const match = message.match(pattern);
    if (match && match[1]) {
      const extracted = match[1].trim();
      // Check if it matches a known category
      for (const [patternKey, category] of Object.entries(categoryPatterns)) {
        if (extracted.toLowerCase().includes(patternKey)) {
          return category;
        }
      }
      // If no match, try to normalize the extracted text
      if (extracted.length > 2) {
        // Capitalize first letter of each word
        const normalized = extracted.split(/\s+/)
          .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
          .join(' ');
        return normalized;
      }
    }
  }
  
  return null;
}

/**
 * Parse target information from conversation messages
 * Looks for patterns like "I want to save X for Y by Z" or "For X" then "Y" (amount)
 */
function parseTargetFromConversation(messages: Array<{ role: string; content: string }>, aiResponse: string): { title: string; amount: number; currency?: string; date?: string; description?: string } | null {
  // Check if AI response confirms a target/goal was set (indicates we should create one)
  // Updated to also match "goal" in addition to "target"
  const aiConfirmsTarget = /(?:got it|noted|saved|created|set|great|perfect|done).*?(?:target|goal|savings goal)/i.test(aiResponse);
  if (!aiConfirmsTarget) {
    return null; // Only create target if AI confirms it
  }

  // Get user messages and AI messages
  const userMessages = messages.filter(m => m.role === 'user').map(m => m.content);
  const aiMessages = messages.filter(m => m.role === 'assistant' || m.role === 'system').map(m => m.content);
  const lastUserMessage = userMessages[userMessages.length - 1] || '';
  const secondLastUserMessage = userMessages[userMessages.length - 2] || '';
  const lastAiMessage = aiMessages[aiMessages.length - 1] || '';
  const secondLastAiMessage = aiMessages[aiMessages.length - 2] || '';

  let title = '';
  let amount = 0;
  let currency = '';
  let date: string | undefined;

  // Pattern 1: "I want to save X for Y by Z" in one message
  const pattern1 = /(?:i want to|i need to|save|saving).*?(\d+(?:\.\d+)?)\s*(?:euros?|dollars?|usd|eur|\$|€)?.*?(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i;
  const match1 = lastUserMessage.match(pattern1);
  
  if (match1) {
    amount = parseFloat(match1[1]);
    title = match1[2]?.trim() || '';
    if (match1[3]) {
      date = parseTargetDate(match1[3]);
    }
    // Detect currency
    if (match1[0].toLowerCase().includes('dollar') || match1[0].toLowerCase().includes('usd') || match1[0].includes('$')) {
      currency = 'USD';
    } else if (match1[0].toLowerCase().includes('euro') || match1[0].toLowerCase().includes('eur') || match1[0].includes('€')) {
      currency = 'EUR';
    }
  } else {
    // Pattern 2: "For X" (description) in one message, then "Y" (amount) in next
    // Example: "For the Hotel room for me and my gf on february" then "100"
    const descriptionPattern = /(?:for|to buy|to get|for a|for an|save for|saving for)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i;
    const amountPattern = /^(\d+(?:\.\d+)?)\s*(?:euros?|dollars?|usd|eur|\$|€)?$/i;
    
    const descMatch = secondLastUserMessage.match(descriptionPattern);
    const amountMatch = lastUserMessage.match(amountPattern);
    
    if (descMatch && amountMatch) {
      // Found description and amount in separate messages
      title = descMatch[1]?.trim() || '';
      amount = parseFloat(amountMatch[1]);
      if (descMatch[2]) {
        date = parseTargetDate(descMatch[2]);
      }
    } else if (amountMatch) {
      // User just provided a number - try to extract title from AI's question or response
      amount = parseFloat(amountMatch[1]);
      
      // Try to extract from AI's question (e.g., "How much would you like to save for your new iPhone?")
      const aiQuestionPattern = /(?:how much|what|save|saving).*?(?:for|to buy|to get|for a|for an|your)\s*(.+?)(?:\?|$)/i;
      const aiQuestionMatch = (lastAiMessage || secondLastAiMessage).match(aiQuestionPattern);
      if (aiQuestionMatch) {
        title = aiQuestionMatch[1]?.trim() || '';
        // Clean up common prefixes
        title = title.replace(/^(?:your|a|an|the)\s+/i, '').trim();
      }
      
      // If still no title, try to extract from AI's confirmation response
      if (!title) {
        const aiConfirmPattern = /(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\.|!|,|$)/i;
        const aiConfirmMatch = aiResponse.match(aiConfirmPattern);
        if (aiConfirmMatch) {
          title = aiConfirmMatch[1]?.trim() || '';
          // Clean up common prefixes
          title = title.replace(/^(?:your|a|an|the)\s+/i, '').trim();
        }
      }
      
      // Fallback: try to extract from previous user message if it contains "for"
      if (!title && secondLastUserMessage.toLowerCase().includes('for')) {
        const descText = secondLastUserMessage;
        const forMatch = descText.match(/(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i);
        if (forMatch) {
          title = forMatch[1]?.trim() || '';
          if (forMatch[2]) {
            date = parseTargetDate(forMatch[2]);
          }
        }
      }
    }
  }

  // Also try to extract from AI response if it mentions the target details
  // This is especially useful when the AI confirms the target in its response
  if (!title || !amount) {
    // Enhanced pattern to extract from AI confirmation (e.g., "Your savings goal is set for $1,500 for a new iPhone")
    const aiPattern = /(?:target|goal|savings goal).*?(\d+(?:[,\.]\d+)?)\s*(?:euros?|dollars?|usd|eur|\$|€)?.*?(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i;
    const aiMatch = aiResponse.match(aiPattern);
    if (aiMatch) {
      // Handle comma-separated numbers (e.g., "1,500")
      const amountStr = aiMatch[1].replace(/,/g, '');
      if (!amount) amount = parseFloat(amountStr) || 0;
      if (!title) title = aiMatch[2]?.trim() || '';
      if (!date && aiMatch[3]) date = parseTargetDate(aiMatch[3]);
      
      // Extract currency from AI response
      if (aiResponse.includes('$') || aiResponse.toLowerCase().includes('dollar') || aiResponse.toLowerCase().includes('usd')) {
        currency = 'USD';
      } else if (aiResponse.includes('€') || aiResponse.toLowerCase().includes('euro') || aiResponse.toLowerCase().includes('eur')) {
        currency = 'EUR';
      }
    }
  }

  // If we found amount and title, create target
  if (amount > 0 && title) {
    // Clean up title - remove "for" prefix if present
    title = title.replace(/^(?:for|to buy|to get|for a|for an|your)\s+/i, '').trim();
    // Remove trailing date references
    title = title.replace(/\s+(?:in|by|on)\s+[a-z]+$/i, '').trim();
    // Remove extra words like "for me and my gf" etc, but preserve "new iPhone", "new car", etc.
    // Only remove if it's clearly a personal reference, not a product descriptor
    title = title.replace(/\s+(?:for|with|and)\s+(?:me|my|the)\s+(?:gf|boyfriend|girlfriend|partner|spouse|wife|husband).*$/i, '').trim();
    // Remove common filler words at the end (but not if they're part of the product name)
    title = title.replace(/\s+(?:room|fund|goal|target|savings)(?:\s|$)/i, '').trim();
    
    // Generate proper name if title is too short or generic
    if (title.length < 2 || /^[a-z]$/i.test(title)) {
      // If title is just a single letter or very short, try to extract from context
      const allText = userMessages.join(' ').toLowerCase();
      const allAiText = aiMessages.join(' ').toLowerCase();
      const combinedText = (allText + ' ' + allAiText).toLowerCase();
      
      // Look for common patterns
      if (combinedText.includes('iphone') || combinedText.includes('phone')) {
        title = 'New iPhone';
      } else if (combinedText.includes('hotel') || combinedText.includes('room')) {
        title = 'Hotel Room';
      } else if (combinedText.includes('vacation') || combinedText.includes('trip') || combinedText.includes('travel')) {
        title = 'Vacation Fund';
      } else if (combinedText.includes('emergency')) {
        title = 'Emergency Fund';
      } else if (combinedText.includes('car') || combinedText.includes('vehicle')) {
        title = 'New Car';
      } else if (combinedText.includes('house') || combinedText.includes('home') || combinedText.includes('apartment')) {
        title = 'Home Fund';
      } else if (combinedText.includes('wedding')) {
        title = 'Wedding Fund';
      } else if (combinedText.includes('education') || combinedText.includes('school') || combinedText.includes('university')) {
        title = 'Education Fund';
      } else if (combinedText.includes('retirement')) {
        title = 'Retirement Fund';
      } else {
        // Default to a descriptive name based on amount
        title = `Savings Goal (${amount} ${currency || 'EUR'})`;
      }
    } else {
      // Clean and format the title properly
      // Capitalize first letter of each word for proper nouns
      title = title.split(' ').map(word => {
        // Keep common words lowercase unless they're important
        const lowerWord = word.toLowerCase();
        if (['the', 'a', 'an', 'and', 'or', 'for', 'of', 'in', 'on', 'at', 'to'].includes(lowerWord)) {
          return lowerWord;
        }
        // Capitalize first letter
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
      }).join(' ');
      
      // Ensure first word is capitalized
      if (title.length > 0) {
        title = title.charAt(0).toUpperCase() + title.slice(1);
      }
      
      // Limit length
      if (title.length > 100) {
        title = title.substring(0, 97) + '...';
      }
    }

    return {
      title,
      amount,
      currency: currency || undefined,
      date,
      description: `Save ${amount} ${currency || 'EUR'} for ${title}${date ? ` by ${date}` : ''}`
    };
  }

  return null;
}

/**
 * Parse AI confirmation that a limit was set (e.g. "I've set a limit for Dining Out at target $59.22").
 * Used to persist the budget target to the database when the AI sends this confirmation.
 */
function parseLimitConfirmationFromAiResponse(aiResponse: string): { category: string; amount: number; currency?: string } | null {
  const r = aiResponse.trim();
  // Match: "I've set a limit for X at target $Y" / "set a limit for X at target €Y" / "limit for X at target $Y"
  const pattern = /(?:I've set|I have set|I've created|set|created)\s+(?:a )?limit for\s+([^.✓!]+?)\s+at target\s*([$€£¥]|USD|EUR|GBP|JPY)?\s*(\d+(?:\.\d{1,2})?)/i;
  const match = r.match(pattern);
  if (!match) return null;
  const categoryRaw = match[1].trim();
  const currencySymbol = (match[2] || '').trim();
  const amountStr = match[3];
  const amount = parseFloat(amountStr);
  if (!categoryRaw || !Number.isFinite(amount) || amount <= 0) return null;
  let currency: string | undefined;
  if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') currency = 'USD';
  else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') currency = 'EUR';
  else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') currency = 'GBP';
  else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') currency = 'JPY';
  const category = normalizeCategory(categoryRaw);
  return { category, amount: Math.round(amount * 100) / 100, currency };
}

/**
 * Parse a suggested limit from a previous AI message (e.g. "Let's set a limit for Dining Out. How about a target of $59.22?").
 * Used when user confirms with "Do it" / "Yes" so we can create the limit from context even if the current AI reply didn't include the exact phrase.
 */
function parseLimitSuggestionFromMessage(text: string): { category: string; amount: number; currency?: string } | null {
  if (!text || !text.trim()) return null;
  const r = text.trim();
  // Amount: "target of $59.22" / "target $59.22" / "about $59.22" / "$59.22"
  const withSym = r.match(/(?:target\s+(?:of\s+)?|about\s+)?([$€£¥])\s*(\d+(?:\.\d{1,2})?)/i);
  const noSym = r.match(/(?:target\s+(?:of\s+)?)(\d+(?:\.\d{1,2})?)/);
  const amountMatch = withSym || noSym;
  if (!amountMatch) return null;
  const amountStr = amountMatch[2] || amountMatch[1];
  const amount = parseFloat(amountStr);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  const sym = withSym ? (withSym[1] || '').trim() : '';
  let currency: string | undefined;
  if (sym === '$') currency = 'USD';
  else if (sym === '€') currency = 'EUR';
  else if (sym === '£') currency = 'GBP';
  else if (sym === '¥') currency = 'JPY';
  // Category: "limit for Dining Out" / "for Dining Out" / "set a limit for Dining Out"
  const categoryMatch = r.match(/(?:limit for|set a limit for)\s+([A-Za-z][A-Za-z\s&]+?)(?:\s*\.|,|\?|$|\s+How|\s+Would|\s+about)/i) ||
    r.match(/(?:^|\.|\n)\s*(?:Let's set a limit for)\s+([A-Za-z][A-Za-z\s&]+?)(?:\s*\.|,|\?)/i);
  const categoryRaw = categoryMatch ? categoryMatch[1].trim() : null;
  if (!categoryRaw) return null;
  const category = normalizeCategory(categoryRaw);
  return { category, amount: Math.round(amount * 100) / 100, currency };
}

/**
 * Parse budget recommendations from AI analytics response
 * Looks for patterns like "Category Name — target $X" in the Ranked Recommendations section
 */
function parseBudgetRecommendations(aiResponse: string): Array<{ category: string; amount: number; currency?: string }> | null {
  const recommendations: Array<{ category: string; amount: number; currency?: string }> = [];
  
  // First, try to find the "Ranked Recommendations" section
  let recommendationsSection = '';
  const recommendationsMatch = aiResponse.match(/##\s*Ranked Recommendations\s*([\s\S]*?)(?=##|$)/i);
  if (recommendationsMatch) {
    recommendationsSection = recommendationsMatch[1];
  } else {
    // If no "Ranked Recommendations" section, search the entire response
    // This handles cases where AI provides recommendations in a different format
    recommendationsSection = aiResponse;
  }
  
  // Pattern 1: Match "1. **Category Name** — target $X" with markdown bold
  // Also match without numbering: "**Category Name** — target $X"
  // Updated to capture decimal amounts more precisely (e.g., 21.60, 21.6, 20)
  const pattern1 = /(?:^\d+\.\s*)?\*\*([^*]+?)\*\*\s*[—–-]\s*target\s*([$€£¥]|USD|EUR|GBP|JPY)?\s*(\d+(?:\.\d{1,2})?)/gmi;
  
  let match;
  while ((match = pattern1.exec(recommendationsSection)) !== null) {
    const category = match[1].trim();
    const currencySymbol = match[2] || '';
    const amountStr = match[3];
    
    let currency: string | undefined;
    if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') {
      currency = 'USD';
    } else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') {
      currency = 'EUR';
    } else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') {
      currency = 'GBP';
    } else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') {
      currency = 'JPY';
    }
    
    // Parse amount with full precision (preserve decimals)
    const amount = parseFloat(amountStr);
    
    if (category && amount > 0 && !isNaN(amount)) {
      const cleanCategory = category
        .replace(/\*\*/g, '')
        .replace(/\[|\]/g, '')
        .trim();
      
      // Round to 2 decimal places to match currency precision
      const roundedAmount = Math.round(amount * 100) / 100;
      
      recommendations.push({
        category: cleanCategory,
        amount: roundedAmount,
        currency
      });
    }
  }
  
  // Pattern 2: Match "1. Category Name — target $X" without markdown (fallback)
  if (recommendations.length === 0) {
    const pattern2 = /^\d+\.\s*([A-Za-z\s&]+?)\s*[—–-]\s*target\s*([$€£¥]|USD|EUR|GBP|JPY)?\s*(\d+(?:\.\d{1,2})?)/gmi;
    let match2;
    while ((match2 = pattern2.exec(recommendationsSection)) !== null) {
      const category = match2[1].trim();
      const currencySymbol = match2[2] || '';
      const amountStr = match2[3];
      
      let currency: string | undefined;
      if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') {
        currency = 'USD';
      } else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') {
        currency = 'EUR';
      } else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') {
        currency = 'GBP';
      } else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') {
        currency = 'JPY';
      }
      
      const amount = parseFloat(amountStr);
      
      if (category && amount > 0 && !isNaN(amount) && category.length > 1) {
        // Round to 2 decimal places to match currency precision
        const roundedAmount = Math.round(amount * 100) / 100;
        
        recommendations.push({
          category: category.trim(),
          amount: roundedAmount,
          currency
        });
      }
    }
  }
  
  // Pattern 3: More flexible - look for any line with "target" followed by currency and amount
  // Also check for patterns like "Dining Out — target $21.60" anywhere in the response
  if (recommendations.length === 0) {
    const lines = recommendationsSection.split('\n');
    for (const line of lines) {
      // Look for pattern: "Category" followed by "target" and amount (with or without dashes)
      const pattern3 = /([A-Za-z\s&]+?)\s+[—–-]\s+target\s+([$€£¥]|USD|EUR|GBP|JPY)?\s*(\d+(?:\.\d{1,2})?)/i;
      const match3 = line.match(pattern3);
      
      // Also try pattern without dashes: "Category target $X"
      if (!match3) {
        const pattern3b = /([A-Za-z\s&]+?)\s+target\s+([$€£¥]|USD|EUR|GBP|JPY)?\s*(\d+(?:\.\d{1,2})?)/i;
        const match3b = line.match(pattern3b);
        if (match3b) {
          const category = match3b[1].trim();
          const currencySymbol = match3b[2] || '';
          const amountStr = match3b[3];
          
          // Skip if category is too short or looks like a number
          if (category.length >= 2 && !/^\d+$/.test(category)) {
            // Skip common non-category words
            if (!['current', 'spending', 'this', 'limit', 'target', 'recommended', 'amount', 'would', 'like', 'set'].includes(category.toLowerCase())) {
              let currency: string | undefined;
              if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') {
                currency = 'USD';
              } else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') {
                currency = 'EUR';
              } else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') {
                currency = 'GBP';
              } else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') {
                currency = 'JPY';
              }
              
              const amount = parseFloat(amountStr);
              
              if (amount > 0 && !isNaN(amount)) {
                const roundedAmount = Math.round(amount * 100) / 100;
                recommendations.push({
                  category: category.trim(),
                  amount: roundedAmount,
                  currency
                });
              }
            }
          }
          continue;
        }
      }
      
      if (match3) {
        const category = match3[1].trim();
        const currencySymbol = match3[2] || '';
        const amountStr = match3[3];
        
        // Skip if category is too short or looks like a number
        if (category.length < 2 || /^\d+$/.test(category)) {
          continue;
        }
        
        // Skip common non-category words
        if (['current', 'spending', 'this', 'limit', 'target', 'recommended', 'amount', 'would', 'like', 'set'].includes(category.toLowerCase())) {
          continue;
        }
        
        let currency: string | undefined;
        if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') {
          currency = 'USD';
        } else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') {
          currency = 'EUR';
        } else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') {
          currency = 'GBP';
        } else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') {
          currency = 'JPY';
        }
        
        const amount = parseFloat(amountStr);
        
        if (category && amount > 0 && !isNaN(amount)) {
          // Round to 2 decimal places to match currency precision
          const roundedAmount = Math.round(amount * 100) / 100;
          
          recommendations.push({
            category: category.trim(),
            amount: roundedAmount,
            currency
          });
        }
      }
    }
  }
  
  return recommendations.length > 0 ? recommendations : null;
}

/**
 * Parse target date from various formats
 */
function parseTargetDate(dateStr: string): string | undefined {
  if (!dateStr) return undefined;

  const lowerDate = dateStr.toLowerCase().trim();
  
  // Month names
  const months: { [key: string]: number } = {
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
  };

  // Check if it's a month name
  for (const [monthName, monthNum] of Object.entries(months)) {
    if (lowerDate.includes(monthName)) {
      const now = new Date();
      const currentYear = now.getFullYear();
      const targetDate = new Date(currentYear, monthNum - 1, 1);
      
      // If the month has passed this year, use next year
      if (targetDate < now) {
        targetDate.setFullYear(currentYear + 1);
      }
      
      return targetDate.toISOString().split('T')[0];
    }
  }

  // Try parsing as date string
  try {
    const parsed = new Date(dateStr);
    if (!isNaN(parsed.getTime())) {
      return parsed.toISOString().split('T')[0];
    }
  } catch (e) {
    // Ignore parse errors
  }

  return undefined;
}

/**
 * Build context-aware system prompt similar to webapp
 */
async function buildSystemPrompt(userId: string, conversationId: string): Promise<string> {
  const supabase = getSupabaseClient();
  if (!supabase) {
    return 'No financial data available. Use conversation context only.';
  }

  // Fetch user preferences (currency)
  let userCurrency = 'USD';
  try {
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('currency_code')
      .eq('id', userId)
      .single();
    
    if (!profileError && profileData?.currency_code) {
      userCurrency = profileData.currency_code;
    }
  } catch (error) {
    logger.warn('Failed to fetch user preferences', { error: error instanceof Error ? error.message : 'Unknown' });
  }

  // Get currency symbol for formatting
  const getCurrencySymbol = (currency: string): string => {
    const symbols: { [key: string]: string } = {
      'USD': '$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'C$',
      'AUD': 'A$',
      'CHF': 'CHF',
      'CNY': '¥',
      'INR': '₹',
      'BRL': 'R$',
      'MXN': 'MX$',
      'SGD': 'S$',
      'HKD': 'HK$',
      'NZD': 'NZ$',
      'ZAR': 'R'
    };
    return symbols[currency] || '$';
  };

  const currencySymbol = getCurrencySymbol(userCurrency);

  // Fetch ALL transactions (no limit) to get complete financial picture
  const { data: transactionsData, error: transactionsError } = await supabase
    .from('anita_data')
    .select('*')
    .eq('account_id', userId)
    .eq('data_type', 'transaction')
    .order('created_at', { ascending: false });

  if (transactionsError) {
    logger.warn('Failed to fetch transactions', { error: transactionsError.message });
  }

  // Fetch recent messages for context (only if conversationId is provided)
  let messagesData = null;
  if (conversationId) {
    const { data, error: messagesError } = await supabase
      .from('anita_data')
      .select('*')
      .eq('account_id', userId)
      .eq('conversation_id', conversationId)
      .eq('data_type', 'message')
      .order('created_at', { ascending: false })
      .limit(6);
    
    messagesData = data;
    if (messagesError) {
      logger.warn('Failed to fetch messages', { error: messagesError.message });
    }
  }

  // Calculate financial metrics and normalize categories
  const transactions = (transactionsData || []).map((item: any) => ({
    type: item.transaction_type || 'expense',
    amount: Number(item.transaction_amount) || 0,
    description: item.transaction_description || '',
    category: normalizeCategory(item.transaction_category), // Normalize to proper case
    date: item.transaction_date || item.created_at
  }));

  const totalIncome = transactions
    .filter((t: any) => t.type === 'income')
    .reduce((sum: number, t: any) => sum + t.amount, 0);
  
  const totalExpenses = transactions
    .filter((t: any) => t.type === 'expense')
    .reduce((sum: number, t: any) => sum + t.amount, 0);
  
  const netBalance = totalIncome - totalExpenses;

  const recentTransactionSummary = transactions
    .slice(0, 5)
    .map((t: any) => `${t.type}: ${currencySymbol}${t.amount.toFixed(2)} - ${t.description} (${t.category})`)
    .join(', ');

  // Build recent conversation context (only if messages were fetched)
  let recentConversation = 'No recent conversation history';
  if (messagesData && messagesData.length > 0) {
    const recentMessages = messagesData.reverse(); // Reverse to get chronological order
    recentConversation = recentMessages
      .map((msg: any) => {
        const sender = msg.sender === 'user' ? 'user' : 'assistant';
        const text = msg.message_text || msg.text || '';
        return `${sender}: ${text}`;
      })
      .join('\n');
  }

  // Build financial insights
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  
  const monthlyTransactions = transactions.filter((t: any) => {
    const transactionDate = new Date(t.date);
    return transactionDate >= currentMonthStart;
  });

  const monthlyIncome = monthlyTransactions
    .filter((t: any) => t.type === 'income')
    .reduce((sum: number, t: any) => sum + t.amount, 0);
  
  const monthlyExpenses = monthlyTransactions
    .filter((t: any) => t.type === 'expense')
    .reduce((sum: number, t: any) => sum + t.amount, 0);

  // Calculate category breakdowns for better insights (categories already normalized)
  const categoryBreakdown = transactions
    .filter((t: any) => t.type === 'expense')
    .reduce((acc: any, t: any) => {
      const category = normalizeCategory(t.category);
      acc[category] = (acc[category] || 0) + t.amount;
      return acc;
    }, {});

  const monthlyCategoryBreakdown = monthlyTransactions
    .filter((t: any) => t.type === 'expense')
    .reduce((acc: any, t: any) => {
      const category = normalizeCategory(t.category);
      acc[category] = (acc[category] || 0) + t.amount;
      return acc;
    }, {});

  // Define fixed vs variable spending categories for clearer insights
  const fixedCategories = new Set<string>([
    'Rent',
    'Mortgage',
    'Electricity',
    'Water & Sewage',
    'Gas & Heating',
    'Internet & Phone',
    'Education',
    'Medical & Healthcare'
  ]);

  const variableCategories = new Set<string>([
    'Groceries',
    'Dining Out',
    'Gas & Fuel',
    'Public Transportation',
    'Rideshare & Taxi',
    'Parking & Tolls',
    'Streaming Services',
    'Software & Apps',
    'Shopping',
    'Clothing & Fashion',
    'Entertainment',
    'Fitness & Gym',
    'Personal Care',
    'Other'
  ]);

  const getCategoryType = (category: string): 'Fixed' | 'Variable' | 'Other' => {
    if (fixedCategories.has(category)) return 'Fixed';
    if (variableCategories.has(category)) return 'Variable';
    return 'Other';
  };

  // Get top VARIABLE spending categories for the CURRENT MONTH only
  const topMonthlyCategories = Object.entries(monthlyCategoryBreakdown)
    .filter(([category]) => variableCategories.has(category))
    .sort(([, a]: any, [, b]: any) => b - a)
    .slice(0, 5)
    .map(([category, amount]: any) => ({ category, amount, type: getCategoryType(category) }));

  const financialInsights = {
    totalBalance: netBalance,
    totalIncome,
    totalExpenses,
    monthlyIncome,
    monthlyExpenses,
    monthlyBalance: monthlyIncome - monthlyExpenses,
    categoryBreakdown,
    monthlyCategoryBreakdown,
    topMonthlyCategories,
    transactionCount: transactions.length,
    monthlyTransactionCount: monthlyTransactions.length
  };
  return `FINANCIAL SNAPSHOT:
- Total Income: ${currencySymbol}${totalIncome.toFixed(2)}
- Total Expenses: ${currencySymbol}${totalExpenses.toFixed(2)}
- Net Balance: ${currencySymbol}${netBalance.toFixed(2)}
- Monthly Income: ${currencySymbol}${monthlyIncome.toFixed(2)}
- Monthly Expenses: ${currencySymbol}${monthlyExpenses.toFixed(2)}
- Monthly Balance: ${currencySymbol}${financialInsights.monthlyBalance.toFixed(2)}

${recentTransactionSummary ? `Recent Transactions: ${recentTransactionSummary}` : ''}

${topMonthlyCategories.length > 0 ? `Top Variable Spending Categories (current month only):\n${topMonthlyCategories.map((c: any, i: number) => `${i + 1}. ${c.category} (${c.type}): ${currencySymbol}${c.amount.toFixed(2)}`).join('\n')}` : ''}

DETAILED FINANCIAL DATA:
${JSON.stringify(financialInsights, null, 2)}

CONVERSATION CONTEXT:
${recentConversation}

ANITA — HOW TO ANSWER (DO THIS EVERY TIME):

Every user message must be fully interpreted by you before any reply. You decide what the message means and which of the 6 flows applies. Follow this order strictly:

STEP 1 — INTERPRET FULL CONTEXT (do this first, for every message):
- Read the user's last message and the full CONVERSATION CONTEXT above.
- Understand what they said literally and what they mean in context (e.g. "21 on the haircut" in a thread about adding an expense means: amount 21, description haircut; "Yes" after a category question means confirmation).
- Consider what has already been said: are we mid-flow (e.g. waiting for amount, or for category confirmation)? What intent did the user express earlier?
- Infer the user's goal from context and wording — do not rely on keywords alone. Same words can mean different things in different contexts.

STEP 2 — ROUTE TO EXACTLY ONE OF THE 6 PATTERNS:
- Using your interpretation from Step 1, choose exactly one further flow: P1, P2, P3, P4, P5, or P6.
- If the intent is about investments (stocks, crypto, funds, advice) — Anita is not an investment tool. Reply exactly: "Sorry, I don't understand your request." Then stop; no markers, no [END].
- If the intent does not match any of P1–P6 — reply exactly: "Sorry, I don't understand your request." Then stop; no markers, no [END].
- Otherwise you have chosen one pattern. Do not mix patterns; do not skip to a different pattern mid-conversation unless the user's new message clearly changes intent.

STEP 3 — EXECUTE THE CHOSEN PATTERN:
- Within the chosen pattern (P1–P6), determine which step you are on given what the user has already provided (e.g. do you have category and amount? Did they confirm category? Did they choose goal vs limit?).
- Write your reply so it does only what that pattern step says. Keep it short (max 3 sentences). No philosophy, no motivation, no invented information.
- Do not add [END] or any other marker at the end. Your reply must end with normal text only (or the goodbye phrase if the pattern says so).

---

THE 6 PATTERNS (interpret first, then choose one — follow exactly):

P1 — Add Income:
- Step 1: Ask for category of income, amount, and optionally a short description. Name example categories (e.g. Salary, Freelance & Side Income, Other). Do not ask for amount only — always ask for category and amount (and optional description).
- Step 2: After you have category and amount, create the transaction in the finance page, then send a friendly confirmation with ✅ and a button to review income. Do not confirm until you have both category and amount. Use only a category from the Categories list below; interpret user wording (e.g. "salary", "paycheck", "job") as Salary; "freelance", "side gig" as Freelance & Side Income.

P2 — Add Expense:
- Step 1: Ask for category of expense, amount, and optionally a short description. Name example categories (e.g. Groceries, Dining Out, Rent, Entertainment). Do not ask for amount only — always ask for category and amount (and optional description).
- Step 2: After you have category and amount, create the transaction in the finance page, then send a friendly confirmation with ✅ and a button to review expense. Do not confirm until you have both category and amount. Use only a category from the Categories list below; interpret user wording correctly (e.g. "restaurant", "food delivery", "pizza" → Dining Out; "supermarket", "food shop" → Groceries; "uber", "taxi" → Rideshare & Taxi; "netflix", "spotify" → Streaming Services).

P3 — Set a Target:
- Step 1 (only when user has NOT yet chosen goal or limit): Ask if user wants a goal or a limit.
- If the user has already clearly chosen a limit (e.g. "Limit", "set a limit", "yes" after you offered to help set a limit): do NOT show categories yet. Ask exactly one follow-up: "Would you like to set the limit yourself (you tell me category and amount) or with my help? (I can suggest categories and amounts.)" Wait for their reply. Do not mention "variable" or "variable costs" to the user.
- If the user then chooses "with help" (e.g. "with help", "your help", "you", "suggest", "help me"): go to "Limit — with help" and show the spending categories list (do not label them as "variable" in the message).
- If the user then chooses "alone" / "myself" (e.g. "myself", "alone", "I'll tell you", "I'll set it"): go to "Limit — alone" and ask for category and limit amount.
- If the user has already clearly chosen a goal (e.g. "Goal", "saving goal"), do NOT ask "goal or limit" — go directly to Goal (ask for target name and amount).
- Goal: Ask for target name and amount. Create the goal in the finance page. Send short confirmation with ✅ and button to review target.
- Limit — alone: Ask for category and limit amount. Create the limit in the finance page. Send confirmation with ✅ and button to review limit.
- Limit — with help: Use only VARIABLE spending categories from monthlyCategoryBreakdown (current month) in the backend; skip fixed costs. In your reply do NOT say "variable" — say "spending categories" or "your top spending categories". Present as a short markdown list with category and amount only (e.g. "1. **Groceries** · ${currencySymbol}180.51" — no "Variable" in the list). Let user choose one. When they confirm, include: "I've set a limit for [Category] at target ${currencySymbol}[amount]." Then ✅ and button to review limit. Use suggested amount 10–20% below current monthly spending for that category.

P4 — Analyse Budget:
- Step 1: Check health from FINANCIAL SNAPSHOT / DETAILED FINANCIAL DATA. Send a short message if budget is OK or not.
- Step 2: Ask if user would like to set a limit (e.g. "Would you like me to help you set a limit for any of your spending categories?"). Do NOT say "variable" — we only offer spending categories. If user says no: "All the best with your financial journey! Come back anytime 😄" If user says yes (e.g. "Yes", "Limit", "Sure"): ask one follow-up only: "Would you like to set the limit yourself (you tell me category and amount) or with my help? (I can suggest categories and amounts.)" Then based on their next reply go to Limit — alone or Limit — with help; do not ask "goal or limit".

P5 — Explain Who Anita Is:
- Step 1: Short explanation of what Anita does. Ask if user wants to analyse budget. If yes: follow P4. If no: "All the best with your financial journey! Come back anytime 😄"

P6 — Explain Where Money Goes:
- Step 1: Show where the user overspends by listing spending categories from the current month (use monthlyCategoryBreakdown; backend uses VARIABLE only, skip fixed costs). Do NOT say "variable" to the user — say "spending categories" or "your top spending categories". Format as a short markdown list with category and amount only (e.g. "1. **Groceries** · ${currencySymbol}180.51", no "Variable" in the list). Then ask a single concise follow-up question.
- Step 2: When the user confirms, create the limit in the database by including this exact phrase in your reply: "I've set a limit for [Category] at target ${currencySymbol}[amount]." Then add ✅ and button to review limit. If user refuses to set a limit: "All the best with your financial journey! Come back anytime 😄"

Categories (for P1, P2, P3, P6 — use exactly these names, proper case, "&" not "and"): Rent, Mortgage, Electricity, Water & Sewage, Gas & Heating, Internet & Phone, Groceries, Dining Out, Gas & Fuel, Public Transportation, Rideshare & Taxi, Parking & Tolls, Streaming Services, Software & Apps, Shopping, Clothing & Fashion, Entertainment, Medical & Healthcare, Fitness & Gym, Personal Care, Education, Salary, Freelance & Side Income, Other. Map user words to one of these: restaurant/cafe/takeout/pizza/delivery → Dining Out; supermarket/food shop → Groceries; uber/lyft/taxi → Rideshare & Taxi; netflix/spotify/subscription → Streaming Services; salary/paycheck/wage → Salary; freelance/gig/side income → Freelance & Side Income; rent/lease → Rent; etc. Never invent a category; always pick from this list. Use only numbers/categories from FINANCIAL SNAPSHOT and DETAILED FINANCIAL DATA above. For limits use only variable spending categories (e.g. Dining Out, Entertainment, Shopping, Streaming Services); never rent, debt, utilities.

Fixed vs Variable (internal use only — do not say "variable" or "fixed" to the user):
- Fixed costs: Rent, Mortgage, Electricity, Water & Sewage, Gas & Heating, Internet & Phone, Education, Medical & Healthcare, and any debt/loan repayments. Do NOT suggest limits for these.
- Variable costs: Groceries, Dining Out, Gas & Fuel, Public Transportation, Rideshare & Taxi, Parking & Tolls, Streaming Services, Software & Apps, Shopping, Clothing & Fashion, Entertainment, Fitness & Gym, Personal Care, Other (suggest limits only for these). When presenting to the user, say "spending categories" and show lists as "**Category** · ${currencySymbol}amount" with no "Variable" label.`;
}

