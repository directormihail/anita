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
    // This ensures the AI has access to user's financial data even without a conversation
    let systemPrompt: string | null = null;
    const supabase = getSupabaseClient();
    if (userId && supabase) {
      try {
        // Use conversationId if provided, otherwise use null (will still fetch transactions)
        systemPrompt = await buildSystemPrompt(userId, conversationId || '');
        // Insert system prompt at the beginning if it doesn't already exist
        if (systemPrompt && sanitizedMessages[0]?.role !== 'system') {
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

    // Automatically create target if detected in conversation
    if (userId && supabase) {
      try {
        const targetInfo = parseTargetFromConversation(sanitizedMessages, aiResponse);
        if (targetInfo) {
          logger.info('Target detected in conversation, creating automatically', { requestId, userId, title: targetInfo.title });
          
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
            // Don't fail the request if target creation fails
          } else {
            logger.info('Target auto-created successfully', { requestId, targetId: createdTarget.id, title: targetInfo.title });
            // Store target ID to include in response
            (res as any).createdTargetId = createdTarget.id;
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
          // First try to parse from AI response (structured recommendations)
          let budgetRecommendations = parseBudgetRecommendations(aiResponse);
          
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
      response: aiResponse,
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
  // Check if AI response confirms a target was set (indicates we should create one)
  const aiConfirmsTarget = /(?:got it|noted|saved|created|set).*?target/i.test(aiResponse);
  if (!aiConfirmsTarget) {
    return null; // Only create target if AI confirms it
  }

  // Get user messages
  const userMessages = messages.filter(m => m.role === 'user').map(m => m.content);
  const lastUserMessage = userMessages[userMessages.length - 1] || '';
  const secondLastUserMessage = userMessages[userMessages.length - 2] || '';

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
    const descriptionPattern = /(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i;
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
    } else if (amountMatch && secondLastUserMessage.toLowerCase().includes('for')) {
      // Fallback: amount in last message, extract description from previous
      amount = parseFloat(amountMatch[1]);
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

  // Also try to extract from AI response if it mentions the target details
  if (!title || !amount) {
    const aiPattern = /(?:target|goal).*?(\d+(?:\.\d+)?)\s*(?:euros?|dollars?|usd|eur|\$|€)?.*?(?:for|to buy|to get|for a|for an)\s*(.+?)(?:\s+(?:in|by|on)\s+([a-z]+|\d{1,2}\/\d{1,2}\/\d{4}|\d{4}-\d{1,2}-\d{1,2}))?/i;
    const aiMatch = aiResponse.match(aiPattern);
    if (aiMatch) {
      if (!amount) amount = parseFloat(aiMatch[1]) || 0;
      if (!title) title = aiMatch[2]?.trim() || '';
      if (!date && aiMatch[3]) date = parseTargetDate(aiMatch[3]);
    }
  }

  // If we found amount and title, create target
  if (amount > 0 && title) {
    // Clean up title - remove "for" prefix if present
    title = title.replace(/^(?:for|to buy|to get|for a|for an)\s+/i, '').trim();
    // Remove trailing date references
    title = title.replace(/\s+(?:in|by|on)\s+[a-z]+$/i, '').trim();
    // Remove extra words like "for me and my gf" etc
    title = title.replace(/\s+(?:for|with|and)\s+(?:me|my|the|a|an)\s+.*$/i, '').trim();
    // Remove common filler words at the end
    title = title.replace(/\s+(?:room|fund|goal|target|savings)$/i, '').trim();
    
    // Generate proper name if title is too short or generic
    if (title.length < 2 || /^[a-z]$/i.test(title)) {
      // If title is just a single letter or very short, try to extract from context
      const allText = userMessages.join(' ').toLowerCase();
      
      // Look for common patterns
      if (allText.includes('hotel') || allText.includes('room')) {
        title = 'Hotel Room';
      } else if (allText.includes('vacation') || allText.includes('trip') || allText.includes('travel')) {
        title = 'Vacation Fund';
      } else if (allText.includes('emergency')) {
        title = 'Emergency Fund';
      } else if (allText.includes('car') || allText.includes('vehicle')) {
        title = 'Car Fund';
      } else if (allText.includes('house') || allText.includes('home') || allText.includes('apartment')) {
        title = 'Home Fund';
      } else if (allText.includes('wedding')) {
        title = 'Wedding Fund';
      } else if (allText.includes('education') || allText.includes('school') || allText.includes('university')) {
        title = 'Education Fund';
      } else if (allText.includes('retirement')) {
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
    return 'You are ANITA, a helpful and friendly personal finance AI assistant.';
  }

  // Fetch user preferences (currency, date format)
  let userCurrency = 'USD';
  let dateFormat = 'MM/DD/YYYY';
  try {
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('currency_code, date_format')
      .eq('id', userId)
      .single();
    
    if (!profileError && profileData) {
      if (profileData.currency_code) {
        userCurrency = profileData.currency_code;
      }
      if (profileData.date_format) {
        dateFormat = profileData.date_format;
      }
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

  // Get top spending categories
  const topCategories = Object.entries(categoryBreakdown)
    .sort(([, a]: any, [, b]: any) => b - a)
    .slice(0, 5)
    .map(([category, amount]: any) => ({ category, amount }));

  const financialInsights = {
    totalBalance: netBalance,
    totalIncome,
    totalExpenses,
    monthlyIncome,
    monthlyExpenses,
    monthlyBalance: monthlyIncome - monthlyExpenses,
    categoryBreakdown,
    monthlyCategoryBreakdown,
    topCategories,
    transactionCount: transactions.length,
    monthlyTransactionCount: monthlyTransactions.length
  };

  return `You are ANITA, a warm and insightful AI finance advisor. Keep responses SHORT and CONCISE - aim for 2-3 sentences maximum unless the user asks for detailed analysis.

**YOUR PERSONALITY:**
- Warm, friendly, and genuinely interested in helping
- BRIEF - keep responses short and to the point
- Conversational - you speak naturally, not like a robot reading a script
- Insightful - you notice patterns and provide meaningful observations

**YOUR FINANCIAL DATA ACCESS:**
You have complete access to the user's financial data. When they ask about finances, use the data below to provide accurate, specific insights. Only share financial analysis when explicitly asked - don't force it into every conversation.

**CRITICAL: RESPONSE LENGTH**
- Default responses should be 2-3 sentences maximum
- Only provide longer responses when explicitly asked for detailed analysis
- Be direct and avoid unnecessary explanations
- Get to the point quickly

**FINANCIAL SNAPSHOT:**
- Total Income: ${currencySymbol}${totalIncome.toFixed(2)}
- Total Expenses: ${currencySymbol}${totalExpenses.toFixed(2)}
- Net Balance: ${currencySymbol}${netBalance.toFixed(2)}
- Monthly Income: ${currencySymbol}${monthlyIncome.toFixed(2)}
- Monthly Expenses: ${currencySymbol}${monthlyExpenses.toFixed(2)}
- Monthly Balance: ${currencySymbol}${financialInsights.monthlyBalance.toFixed(2)}

${recentTransactionSummary ? `Recent Transactions: ${recentTransactionSummary}` : ''}

${topCategories.length > 0 ? `Top Spending Categories:\n${topCategories.map((c: any, i: number) => `${i + 1}. ${c.category}: ${currencySymbol}${c.amount.toFixed(2)}`).join('\n')}` : ''}

**DETAILED FINANCIAL DATA (use when analyzing):**
${JSON.stringify(financialInsights, null, 2)}

**CONVERSATION CONTEXT:**
${recentConversation}

**HOW TO RESPOND:**

**For Transaction Logging:**
When users log transactions, acknowledge briefly and warmly. Don't automatically analyze unless asked. Examples:
- "Got it! I've noted your ${currencySymbol}50 expense for groceries."
- "Thanks for logging that income! Every bit helps track your progress."

**For Target/Goal Setting:**
- When users say "Set a target" or "I want to set a target", you MUST ask: "Would you like to set a savings goal or a spending limit?" (1 sentence only)
- If they choose "spending limit" or "limit", analyze their spending data and recommend 2-3 categories that will have the BIGGEST impact (highest spending amounts). 
  - First, provide a brief response: "Based on your spending, I recommend setting limits for [Category 1], [Category 2], and [Category 3] - these are your top spending areas."
  - Then, if they choose a category, provide the recommendation in the EXACT format: **[Category Name] — target ${currencySymbol}[recommended amount]**
  - The recommended amount should be 10-20% less than their current spending in that category
  - Use this format so the system can automatically create the limit
  - When the user confirms (says "yes", "set it", "create it", etc.), ALWAYS include the recommendation in the format: **[Category Name] — target ${currencySymbol}[amount]** so it can be automatically created
- If they choose "savings goal" or "goal" or "target", ask: "What would you like to save for?" (1 sentence only)
- When users mention saving money, financial goals, or wanting to buy something (e.g., "I want to save money for X", "I need money for Y", "I'm planning to buy Z"), respond briefly (1-2 sentences) then ask: "Would you like to set a target for this?"
- NEVER provide long explanations about the benefits of setting targets - just ask what they want to set a target for or if they want to set one

**IMPORTANT - Transaction Categorization:**
When users mention transactions in chat (e.g., "spent $50 on pizza", "bought groceries", "paid rent"), you should help categorize them properly. Use these standard categories:

**Standard Categories (use exact names with proper case):**
- Rent, Mortgage, Electricity, Water & Sewage, Gas & Heating, Internet & Phone
- Groceries, Dining Out
- Gas & Fuel, Public Transportation, Rideshare & Taxi, Parking & Tolls
- Streaming Services, Software & Apps
- Shopping, Clothing & Fashion
- Entertainment
- Medical & Healthcare, Fitness & Gym
- Personal Care
- Education
- Salary, Freelance & Side Income
- Other (for uncategorized items)

**Category Detection Rules:**
- Analyze the context carefully to determine the correct category
- **Restaurant/Fast Food Names:** Any restaurant or fast food chain name (Burger King, McDonald's, KFC, Subway, Pizza Hut, etc.) → "Dining Out"
- **Food-related:** "Pizza", "burger", "restaurant", "cafe", "lunch", "dinner", "breakfast", "takeout", "delivery" → "Dining Out"
- **Groceries:** "Groceries", "supermarket", "grocery store", "food shopping" → "Groceries"
- **Transportation:** "Uber", "Lyft", "taxi", "cab" → "Rideshare & Taxi"
- **Gas (vehicle):** "Gas", "fuel", "gasoline", "gas station" (for car) → "Gas & Fuel"
- **Gas (home):** "Gas", "heating", "natural gas" (for home) → "Gas & Heating"
- **Streaming:** "Netflix", "Spotify", "Disney+", "streaming" → "Streaming Services"
- **Housing:** "Rent", "apartment", "lease" → "Rent"; "Mortgage", "home loan" → "Mortgage"
- **Personal Care:** "Haircut", "salon", "barber", "toilette", "toiletries", "hygiene" → "Personal Care"
- **Income:** "Salary", "paycheck", "income", "wage" → "Salary"; "Freelance", "side income", "gig" → "Freelance & Side Income"
- When in doubt, analyze what the transaction is actually for and choose the most specific category. Only use "Other" if truly uncategorizable.

**Category Format:**
- Always use proper case (first letter capitalized, rest lowercase, except for proper nouns)
- Use "&" not "and" in category names
- Examples: "Dining Out" (not "dining out" or "DINING OUT"), "Gas & Fuel" (not "Gas and Fuel")

**For Financial Questions:**
Think about what they're REALLY asking, but keep responses SHORT:
- "How am I doing?" → Brief reassurance with key numbers (1-2 sentences)
- "Where is my money going?" → Quick summary of top categories (2-3 sentences max)
- "Can I afford X?" → Direct answer with brief reasoning (2-3 sentences)

**Key Principles:**
1. **BRIEF FIRST** - Always start with a short, direct answer (1-3 sentences)
2. **Be specific** - Use actual numbers from their data, not generic advice
3. **Be natural** - Don't force a template. Let the conversation flow.
4. **Be helpful** - Focus on what they need, not what you think they should hear
5. **Ask if they want more** - After a brief answer, ask "Would you like more details?" if appropriate

**For Financial Analysis:**
When providing financial insights:
- Start with what matters most to their specific question (1-2 sentences)
- Use real numbers from their data
- Keep it brief - only expand if they ask for more details
- Focus on variable/discretionary spending (never suggest cutting fixed costs like rent, debt, utilities)
- End with a brief question or encouragement (1 sentence)

**For Analytics Requests (e.g., "show analytics", "analyze my spending", "give me insights", "set a target"):**
When users request analytics or financial analysis, you MUST use this specific structured format:

## Quick Summary

[Provide a concise summary of their financial situation - 2-3 sentences covering overall spending, income, balance, and key observations]

## Ranked Recommendations

[If there are spending categories with potential savings, list them in order of potential savings (highest first). For each recommendation, use this EXACT format:]

1. **[Category Name] — target ${currencySymbol}[recommended amount] (save ${currencySymbol}[potential savings], [percentage]% reduction)**
   - Current spending: ${currencySymbol}[current amount]
   - [Action step 1 if applicable]
   - [Action step 2 if applicable]
   - Reasoning: [Why this recommendation makes sense]

[Continue with additional recommendations if applicable]

[If no strong recommendations are available, say: "Right now, I don't see strong discretionary cuts that I can safely recommend without impacting essentials. Keep tracking your spending, and we can revisit recommendations once there is more data."]

## Next Step

[Provide a clear, actionable next step - what they should focus on next, or how to improve their financial situation]

**IMPORTANT FOR ANALYTICS:**
- Always use the three-section format above (Quick Summary, Ranked Recommendations, Next Step)
- Use markdown headers (##) for section titles
- Format amounts with the currency symbol: ${currencySymbol}[amount]
- Sort recommendations by potential savings (highest first)
- Be specific with numbers from their actual data
- Only recommend cuts to variable/discretionary spending categories
- Never suggest cutting fixed costs (rent, mortgage, debt payments, utilities, insurance)
- **CRITICAL**: When you provide spending limit recommendations, they will be automatically converted into budget targets. Make sure each recommendation follows the exact format: **[Category Name] — target ${currencySymbol}[amount]**
- **AUTOMATIC LIMIT CREATION**: When the user chooses to set a spending limit, automatically analyze their spending and recommend the top 2-3 categories with the HIGHEST spending amounts (biggest impact). Format: **[Category Name] — target ${currencySymbol}[recommended amount]**. These will be automatically created as budget targets.
- **RECOMMENDATION PRIORITY**: For spending limits, always prioritize categories with the highest current spending - these will have the biggest impact on their budget.

**For General Conversation:**
Be friendly and helpful. Keep responses SHORT (1-3 sentences). Don't force financial topics. Just have a natural conversation. If they mention money concerns, offer brief, gentle support.

**For Mixed Topics:**
Address both aspects naturally but briefly. Show you understand their full situation, not just the financial part.

**IMPORTANT - RESPONSE LENGTH:**
- DEFAULT: 1-3 sentences maximum
- Only expand when explicitly asked for more details
- Be warm and human, but BRIEF
- Get to the point quickly
- If a user mentions saving for something or a financial goal, ask "Would you like to set a target for this?" after 1-2 sentences
- Don't provide long explanations about benefits - just ask if they want to set a target`;
}

