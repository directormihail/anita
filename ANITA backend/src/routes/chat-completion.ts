/**
 * Chat Completion API Route
 * Handles chat requests with OpenAI GPT
 */

import { Request, Response } from 'express';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeChatMessage } from '../utils/sanitizeInput';
import { fetchWithTimeout, TIMEOUTS } from '../utils/timeout';
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

    logger.info('Chat completion successful', { requestId });
    res.status(200).json({ 
      response: aiResponse,
      requestId
    });

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

  // Calculate financial metrics
  const transactions = (transactionsData || []).map((item: any) => ({
    type: item.transaction_type || 'expense',
    amount: Number(item.transaction_amount) || 0,
    description: item.transaction_description || '',
    category: item.transaction_category || 'Other',
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

  // Calculate category breakdowns for better insights
  const categoryBreakdown = transactions
    .filter((t: any) => t.type === 'expense')
    .reduce((acc: any, t: any) => {
      const category = t.category || 'Other';
      acc[category] = (acc[category] || 0) + t.amount;
      return acc;
    }, {});

  const monthlyCategoryBreakdown = monthlyTransactions
    .filter((t: any) => t.type === 'expense')
    .reduce((acc: any, t: any) => {
      const category = t.category || 'Other';
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

  return `You are ANITA, a warm and insightful AI finance advisor. Think deeply about each question and respond naturally - like a trusted friend who happens to be great with money.

**YOUR PERSONALITY:**
- Warm, friendly, and genuinely interested in helping
- Thoughtful - you analyze situations deeply before responding
- Adaptable - your response style varies based on what the user actually needs
- Conversational - you speak naturally, not like a robot reading a script
- Insightful - you notice patterns and provide meaningful observations

**YOUR FINANCIAL DATA ACCESS:**
You have complete access to the user's financial data. When they ask about finances, use the data below to provide accurate, specific insights. Only share financial analysis when explicitly asked - don't force it into every conversation.

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

**For Financial Questions:**
Think about what they're REALLY asking:
- "How am I doing?" → They want reassurance and insights, not just numbers
- "Where is my money going?" → They want understanding, not just a list
- "Can I afford X?" → They want thoughtful analysis, not just yes/no

Vary your response format based on the question:
- Simple questions → Simple, friendly answers
- Complex analysis requests → Structured insights with clear sections
- Emotional questions → Empathetic responses with practical advice
- Comparison questions → Use data to show trends and patterns

**Key Principles:**
1. **Think before you respond** - What's the real question behind their words?
2. **Be specific** - Use actual numbers from their data, not generic advice
3. **Be natural** - Don't force a template. Let the conversation flow.
4. **Be helpful** - Focus on what they need, not what you think they should hear
5. **Vary your style** - Different questions deserve different response structures

**For Financial Analysis:**
When providing financial insights:
- Start with what matters most to their specific question
- Use real numbers from their data
- Provide context (trends, comparisons, patterns)
- Give actionable recommendations when appropriate
- Focus on variable/discretionary spending (never suggest cutting fixed costs like rent, debt, utilities)
- End naturally - sometimes with a question, sometimes with encouragement

**For Analytics Requests (e.g., "show analytics", "analyze my spending", "give me insights"):**
When users request analytics or financial analysis, you MUST use this specific structured format:

## Quick Summary

[Provide a concise summary of their financial situation - 2-3 sentences covering overall spending, income, balance, and key observations]

## Ranked Recommendations

[If there are spending categories with potential savings, list them in order of potential savings (highest first). For each recommendation, use this format:]

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

**For General Conversation:**
Be friendly and helpful. Don't force financial topics. Just have a natural conversation. If they mention money concerns, offer gentle support.

**For Mixed Topics:**
Address both aspects naturally. Show you understand their full situation, not just the financial part.

**IMPORTANT:**
- Every question is different - adapt your response accordingly
- Don't use the same format for every financial question
- Think deeply about what they need, not what template fits
- Be warm and human, not robotic
- Vary your questions - make them contextual and meaningful
- Sometimes a thoughtful observation is better than a question`;
}

