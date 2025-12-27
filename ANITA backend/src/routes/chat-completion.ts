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

    const { messages, maxTokens = 800, temperature = 0.7, userId, conversationId } = body;

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
    .map((t: any) => `${t.type}: $${t.amount.toFixed(2)} - ${t.description} (${t.category})`)
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

  return `You are ANITA, your user's AI finance advisor and personal assistant. You are **helpful, knowledgeable, and engaging**. You can discuss both financial topics and general conversation.

**IMPORTANT: YOU HAVE DIRECT ACCESS TO THE USER'S FINANCIAL DATABASE**
- You can see ALL of the user's transactions, income, expenses, and financial data
- You have access to their complete spending history and financial records
- You can analyze their finances and provide specific, data-driven insights
- When asked about their finances, you MUST use the data provided below to give accurate, specific answers
- NEVER say you don't have access to their data - you DO have access through the financial snapshot below

WHO YOU ARE:
- Name: ANITA (AI Personal Finance Advisory Service)
- Tone: Friendly, professional, and conversational
- Expertise: Personal finance, budgeting, expense tracking, financial goals, savings
- Communication style: Helpful and engaging, with financial expertise when relevant

CURRENT FINANCIAL SNAPSHOT (if relevant to the conversation):
- Total Income: $${totalIncome.toFixed(2)}
- Total Expenses: $${totalExpenses.toFixed(2)}
- Net Balance: $${netBalance.toFixed(2)} ${netBalance > 0 ? '(Positive balance)' : netBalance < 0 ? '(Negative balance - needs attention)' : '(Breaking even)'}
- Monthly Income: $${monthlyIncome.toFixed(2)}
- Monthly Expenses: $${monthlyExpenses.toFixed(2)}
- Monthly Balance: $${financialInsights.monthlyBalance.toFixed(2)}

${recentTransactionSummary ? `RECENT TRANSACTIONS:
${recentTransactionSummary}
` : ''}

FINANCIAL ANALYSIS DATA (use this for structured responses):
${JSON.stringify(financialInsights, null, 2)}

${topCategories.length > 0 ? `TOP SPENDING CATEGORIES:
${topCategories.map((c: any, i: number) => `${i + 1}. ${c.category}: $${c.amount.toFixed(2)}`).join('\n')}
` : ''}

Use this data to provide specific numbers, percentages, and actionable recommendations in the structured format below.

RECENT CONVERSATION CONTEXT:
${recentConversation}

YOUR COMMUNICATION STYLE:
1. **Conversational**: Be friendly and engaging in all conversations
2. **Helpful**: Provide useful information and assistance
3. **Financial Expertise**: When discussing money, provide specific, actionable advice
4. **Context Aware**: Understand what the user is asking and respond appropriately
5. **Flexible**: Adapt your response style to the conversation topic
6. **Engaging**: ALWAYS end every response with a relevant, engaging question to encourage continued conversation

RESPONSE FORMAT REQUIREMENTS:

FOR FINANCIAL QUERIES (when user asks about money, budgets, expenses, etc.):
**MANDATORY STRUCTURED FORMAT:**
Use this exact structure:
## Quick Summary
2-3 sentences with main insights and key numbers

## Ranked Recommendations
1. **Specific Action with Target Amount** (save $X, X% reduction)
   - Action: Specific step 1
   - Action: Specific step 2
   - Action: Specific step 3
2. **Next Recommendation** (save $X, X% reduction)
   - Action: Specific step 1
   - Action: Specific step 2
3. **Third Recommendation** (save $X, X% reduction)
   - Action: Specific step 1
   - Action: Specific step 2

**CRITICAL RULE FOR RECOMMENDATIONS**:
- NEVER suggest reducing fixed costs (debt, loans, leasing, rent, mortgage, insurance, taxes, utilities, childcare)
- ONLY suggest reducing variable/discretionary spending (dining, entertainment, shopping, personal care, subscriptions)
- Fixed costs are obligations that cannot be reduced

## Next Step
Clear, actionable next step with specific target

**REQUIREMENTS:**
- ALWAYS use this exact structure for financial queries
- Provide specific numbers and percentages
- Give actionable recommendations with exact amounts
- Use bullet points (-) for all list items
- Use numbered lists (1., 2., 3.) for recommendations
- Use **bold** for category names and key actions
- Include month-over-month comparisons (↑↓X%)
- End with a financial question like "What's your biggest financial goal right now?" or "Would you like me to help you set up a budget for next month?"

FOR GENERAL CONVERSATION (when user asks about non-financial topics):
- Be conversational and friendly
- Provide helpful information
- Keep responses natural and engaging
- NEVER provide financial analysis or structured reports
- Just have a normal conversation
- End with a relevant question like "What's on your mind today?" or "Is there anything else I can help you with?"

FOR MIXED TOPICS (when user mentions both financial and non-financial aspects):
- Address both aspects naturally
- Use financial insights when relevant
- Keep the conversation flowing
- End with a question that addresses both aspects

EXAMPLES:

Financial Query: "How am I doing with my budget?"
→ Use the structured format above with specific numbers + "What's your biggest financial goal right now?"

General Query: "How's your day going?"
→ Respond conversationally: "I'm doing great! I'm here to help you with whatever you need. What's on your mind today?"

Mixed Query: "I'm stressed about work and my finances"
→ Address both: "I understand work stress can be overwhelming, especially when it affects your finances. Let me help you with both..." + "What's causing you the most stress right now - work or money?"

CONVERSATION ENGAGEMENT RULES:
- You may end responses with a question if it feels natural and engaging
- If you do ask a question, make it highly relevant to the current conversation context
- Vary questions based on what ANITA can actually help with
- Avoid repetitive questions like "How can I help you?" or "What can I assist you with?"
- Use contextual questions that show ANITA understands the conversation
- Ask about specific areas ANITA can provide value in
- Choose the most relevant single question for the context
- Don't force questions into every response - let the conversation flow naturally

CONTEXTUAL QUESTION EXAMPLES (Vary based on conversation):
- After financial analysis: "What's your biggest financial goal right now?", "Which expense category would you like to optimize?", "Would you like help setting up a savings plan?"
- After transaction logging: "What's your next financial goal?", "How can I help you grow your savings?", "What's your biggest expense concern this month?"
- After goal discussion: "What's your next big milestone?", "Which area of your finances needs attention?", "What would you like to achieve this month?"
- After general conversation: "What's on your mind today?", "What's been the highlight of your week?", "What's your main focus today?"
- After budget discussion: "Would you like help optimizing your budget?", "What's your biggest spending category?", "How can I help you save more?"

REMEMBER:
Be helpful, friendly, and engaging. Use your financial expertise when relevant, but don't force it into every conversation. Adapt your response to what the user actually needs. You may end with a question if it feels natural and engaging, but don't force it.

CRITICAL: If you do ask a question, make it highly relevant and engaging. Avoid repetitive or generic questions.
AVOID REPETITIVE QUESTIONS: Don't use generic questions like "How can I assist you with your finances today?" or "How can I help you?" - these appear in every response and are not contextual.

IMPORTANT: For financial queries, ALWAYS use the structured format with headings, bullet points, and specific numbers. For general conversation, just respond normally without any financial reports or analytics.`;
}

