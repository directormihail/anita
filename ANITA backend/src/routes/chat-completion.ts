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

/** Only these categories are valid for spending limits. Reject AI mistakes like "Any of your spending categories". */
const VALID_LIMIT_CATEGORIES = new Set([
  'Groceries', 'Dining Out', 'Gas & Fuel', 'Public Transportation', 'Rideshare & Taxi',
  'Parking & Tolls', 'Streaming Services', 'Software & Apps', 'Shopping', 'Clothing & Fashion',
  'Entertainment', 'Fitness & Gym', 'Personal Care', 'Other'
]);

function isValidLimitCategory(category: string): boolean {
  if (!category || category.length < 2) return false;
  const lower = category.toLowerCase();
  if (/any\s+of|your\s+spending\s+categories|set\s+a\s+limit|which\s+category/i.test(category) || lower.includes('any of')) return false;
  return VALID_LIMIT_CATEGORIES.has(category);
}

/** Currency code → symbol for prompts and transaction confirmation. Used so chat respects user's chosen currency (EUR, CHF, etc.). */
function getCurrencySymbolForCode(currency: string): string {
  const symbols: { [key: string]: string } = {
    'USD': '$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'CAD': 'C$', 'AUD': 'A$',
    'CHF': 'CHF', 'CNY': '¥', 'INR': '₹', 'BRL': 'R$', 'MXN': 'MX$', 'SGD': 'S$',
    'HKD': 'HK$', 'NZD': 'NZ$', 'ZAR': 'R'
  };
  return symbols[currency] ?? '€';
}

/** Freemium: check if user has an active premium subscription (plan is premium/pro/ultimate). */
async function getIsPremium(supabase: { from: (table: string) => any }, userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('user_subscriptions')
    .select('plan')
    .eq('user_id', userId)
    .eq('status', 'active')
    .maybeSingle();
  if (error || !data) return false;
  const plan = ((data as { plan?: string }).plan || '').toLowerCase();
  return plan === 'premium' || plan === 'pro' || plan === 'ultimate';
}

/**
 * Freemium: detect if the user is asking for analytics, insights, limits, goals, or other premium-only features.
 * Returns true for: analytics, spending summary, breakdown, insights, reports, setting limits, setting goals, etc.
 * Returns false for: adding income/expense only, generic app questions ("what is ANITA", "what can you do"), greetings.
 */
function isAnalyticsOrPremiumIntent(userMessage: string): boolean {
  if (!userMessage || typeof userMessage !== 'string') return false;
  const text = userMessage.trim();
  if (text.length < 2) return false;
  const lower = text.toLowerCase();

  // Bulletproof: any mention of setting a limit/goal in request form (impossible to miss)
  if (/\bset\s+a\s+limit\b/i.test(text)) return true;
  if (/\bset\s+a\s+goal\b/i.test(text)) return true;
  if (/\bwanna\s+set\b/i.test(text) && /\blimit|goal\b/i.test(text)) return true;
  if (/\bwant\s+to\s+set\s+(a\s+)?(limit|goal)\b/i.test(text)) return true;
  if (/\bcreate\s+(a\s+)?(limit|goal)\b/i.test(text)) return true;
  if (lower.includes('set a limit') || lower.includes('set a goal')) return true;

  // Allow: clearly adding income or expense only (freemium can do this)
  const addIncomeExpense = /\b(add|record|log|track|input|enter|put)\s+(income|expense|earning|spending|transaction)\b/i.test(text)
    || /\b(income|expense)\s+(of|:)\s*\d/i.test(text)
    || /\b(spent|paid|earned|received)\s+\d/i.test(text)
    || /\d+\s*(euro|eur|usd|dollar|chf)\s*(for|on)\s+/i.test(text)
    || /^(add|record|log)\s+/i.test(text) && (/\b(income|expense|salary|groceries|rent)\b/i.test(text) || /\d+/.test(text));
  if (addIncomeExpense) return false;

  // Allow: generic app / what can you do / what is ANITA (short generic only) — never allow "my finance" or "my spending"
  const genericApp = /\b(what\s+is\s+anita|who\s+are\s+you|what\s+can\s+you\s+do|how\s+does\s+(this\s+)?app\s+work|what\s+is\s+this\s+app|help\s*$|hi\s*$|hello\s*$|hey\s*$)/i.test(text)
    || (/^(what|how|who|why)\s+(is|are|can|does)\s+/i.test(text) && text.length < 80 && !/\b(spend|spent|spending|expense|budget|saving|savings|money|category|categories|limit|goal|analys|finance)\b/i.test(text));
  if (genericApp) return false;

  // "Ask about my finance/spending" or "limit for my spendings" = premium
  if (/\b(my\s+finance|my\s+spending|my\s+money|about\s+my\s+finance)\b/i.test(text)) return true;
  if (/\b(top\s+spending|spending\s+categories|which\s+category)\b/i.test(text)) return true;
  if (/\b(limit|set\s+a?\s*limit)\s+(for\s+)?(my\s+)?(spendings?|expenses?)\b/i.test(text)) return true;
  if (/\b(my\s+)?spendings?\s*[?.]?\s*$/.test(text) && /\b(limit|set)\b/i.test(text)) return true;

  // Premium: analytics (include British "analyse" and German "analysieren")
  const analyticsPatterns = [
    /\b(analytics?|insights?|breakdown|summary|overview|report|analysis|analyze|analyse|summarize|analysieren)\b/i,
    /\b(how\s+much\s+(did\s+i\s+)?(spend|spent)|where\s+(did\s+my\s+)?money\s+go|spending\s+pattern)\b/i,
    /\b(show|tell|give)\s+(me\s+)?(an?\s+)?(overview|breakdown|summary|report)\b/i,
    /\b(category|categories)\s+(spend|breakdown|analysis|spending)\b/i,
    /\b(biggest|largest|top|main)\s+(expense|spending|category)\b/i,
    /\b(month|week|year|period)\s+(summary|review|analysis|spending)\b/i,
    /\b(compare|versus|vs\.?|comparison)\s+(month|period|time|spending)\b/i,
    /\b(trend|pattern|habit)\s+(in\s+)?(spending|expense|money)\b/i,
    /\bwhat\s+(did\s+i\s+)?(spend|spent)\s+(on|this)\b/i,
    /\b(spending|expense)\s+(by\s+)?(category|categories)\b/i,
    /\b(how\s+am\s+i\s+doing|financial\s+health|money\s+overview)\b/i,
    /\b(save|saving|savings)\s+(rate|progress|goal)\b/i,
    /\b(budget\s+review|spending\s+review)\b/i,
    /\banalys(e|ing|ed)?\s+(it|my|the)?/i,
  ];

  // Premium: setting spending limits or savings goals (English + German: Limit, Ziel, mach ein Limit, etc.)
  const limitGoalPatterns = [
    /\b(set|create|make|add|put)\s+(a\s+)?(spending\s+)?limit\b/i,
    /\b(spending|budget)\s+limit\b/i,
    /\b(set|create|make|add)\s+(a\s+)?(savings?\s+)?goal\b/i,
    /\b(savings?|financial)\s+goal\b/i,
    /\blimit\s+(for|on)\s+(category|categories|my\s+spendings?|spendings?)\b/i,
    /\b(mach|setze|erstelle|füge|lege)\s+(ein\s+)?(limit|ziel)\b/i,
    /\b(ein\s+)?(limit|ziel)\s+(setzen|erstellen|machen|festlegen)\b/i,
    /\b(limit|ziel|budget)\s+(für|für eine)\s+/i,
    /^(limit|ziel)\s*$/i,
    /\b(mach|create|set)\s+(ein\s+)?limit\b/i,
    /\b(i\s+wanna|i\s+want(?:\s+to)?|i\'d\s+like)\s+(set|create|have)\s+(a\s+)?(limit|goal)\b/i,
    /\b(help\s+me\s+)?(set|create)\s+(a\s+)?(limit|goal)\b/i,
    /\b(can\s+you|kannst\s+du|van\s+you)\s+(set|create|make|setze|erstelle)\s+(a\s+)?(limit|ziel)\b/i,
    /\b(show|give)\s+me\s+(a\s+)?(limit|goal|breakdown|summary)\b/i,
    /\b(you\s+offer|your\s+offer)\b/i,
  ];

  return analyticsPatterns.some((re) => re.test(text)) || limitGoalPatterns.some((re) => re.test(text));
}

/**
 * Freemium: detect if the conversation is already in a premium flow (AI offered limits, goals, analytics, or showed totals).
 * When the last ASSISTANT message contains such content, the user's next message (e.g. "yes", "groceries", "the first one")
 * is a follow-up in that flow — we must paywall instead of calling the AI.
 */
function isPremiumFlowInProgress(messages: Array<{ role: string; content?: string }>): boolean {
  const lastAssistant = [...messages].reverse().find((m) => m.role === 'assistant' || (m.role && m.role.toLowerCase()) === 'anita');
  const content = (lastAssistant && typeof (lastAssistant as any).content === 'string' ? (lastAssistant as any).content : '') || '';
  const text = content.trim().toLowerCase();
  if (text.length < 10) return false;

  // Assistant is offering or doing: limits, goals, category list, earned/spent/balance, analytics, suggestions (EN + DE)
  const premiumOfferPatterns = [
    /\b(got\s+it!?\s*)?(would\s+you\s+like\s+to\s+set\s+(the\s+)?limit)\b/i,
    /\b(limit|ziel|goal)\s+(for|für|setzen|erstellen|festlegen|suggest|vorschlagen)\b/i,
    /\b(set|create|make|mach|setze|erstelle)\s+(a\s+)?(limit|ziel|goal)\b/i,
    /\b(you\s+tell\s+me\s+category\s+and\s+amount|i\s+can\s+suggest\s+categories)\b/i,
    /\b(wähle|choose|pick)\s+(eine?\s+)?(kategorie|category)\b/i,
    /\b(kategorie|category)\s+(aus|wählen|choose|select)\b/i,
    /\b(earned|spent|balance|verdient|ausgegeben|kontostand)\s*[:\s]*€?\s*\d/i,
    /\b(this\s+month|diesen\s+monat)\s+(you\s+have|hast\s+du)\s+(earned|spent|verdient|ausgegeben)/i,
    /\b(here\s+are|hier\s+sind)\s+(some\s+)?(your\s+)?(categories|kategorien)/i,
    /\b(top\s+spending\s+categories|spending\s+categories\s+this\s+month)\b/i,
    /\b(groceries|dining\s+out|entertainment|streaming)\s*[•·]\s*€/i,
    /\b(suggest|vorschlagen|vorschlag)\s+(categories|kategorien|amount|betrag)/i,
    /\b(do\s+you\s+want|would\s+you\s+like|möchtest\s+du)\s+(to\s+)?(set|ein\s+limit|limit)/i,
    /\b(which\s+one\s+would\s+you\s+like\s+to\s+set\s+a\s+limit)\b/i,
    /\b(would\s+you\s+like\s+to\s+set\s+the\s+limit\s+(yourself|with\s+my\s+help))/i,
    /\b(möchtest\s+du|möchten\s+sie)\s+(ein\s+)?(limit|ziel)\s+(für|für eine)/i,
    /\b(limit|ziel)\s+(für|für eine)\s+(ausgabenkategorie|expense\s+category)/i,
    /\b(analys(e|ing)|breakdown|overview|summary|insight)/i,
    /\b(€0\.00|0\.00\s*€)\s*(so\s+far|bisher)/i,
    /\balles\s+klar!?\s+.*(kategorien|categories)/i,
    /\b(ich\s+kann|i\s+can)\s+(dir|you)\s+(einige\s+)?(kategorien|categories)/i,
    /\b(i\'ve\s+set\s+a\s+limit|i\'ve\s+set\s+a\s+limit\s+for)/i,
  ];
  return premiumOfferPatterns.some((re) => re.test(content));
}

/** Freemium: fallback message when AI paywall reply fails. */
function getFreemiumPaywallMessage(): string {
  return "This function is not available on the free tier. You need a subscription to complete this and other steps. Upgrade to Premium to access analytics, limits, goals, and more. 🦉";
}

/**
 * Freemium: AI-generated contextual paywall reply (not fixed text). Uses the same pattern structure as premium:
 * understand what the user asked for, then reply in a short, friendly way that it's a subscription feature.
 */
async function getContextualPaywallReply(userMessage: string, context: 'premium_intent' | 'premium_flow', requestId: string): Promise<string> {
  const openaiConfig = getOpenAIConfig();
  const apiKey = openaiConfig.apiKey;
  const model = openaiConfig.model;
  if (!apiKey) return getFreemiumPaywallMessage();

  const contextHint = context === 'premium_flow' ? 'They were in the middle of a conversation about limits/goals/analytics.' : 'They asked for something that needs Premium.';
  const systemPrompt = `You are ANITA, a warm financial assistant. The user is on the FREE tier. ${contextHint}

Your ONLY job: reply in 1–2 short sentences. Acknowledge what they asked for, then say clearly that this function needs a subscription and they can upgrade to Premium to use it. Be friendly and a bit playful (one emoji is fine). Do NOT perform any action. Do NOT list categories, suggest amounts, or offer to set a limit. Do NOT say "Got it!" or "Would you like to set the limit yourself". Only say that this is a Premium feature and they need a subscription to complete this and similar steps.`;

  const userPrompt = `The user (free tier) said: "${userMessage.replace(/"/g, '\\"')}"

Reply with your short paywall message only (no other text):`;

  try {
    const response = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          max_tokens: 120,
          temperature: 0.7,
        }),
      },
      TIMEOUTS.CHAT_COMPLETION
    );
    if (!response.ok) throw new Error(`OpenAI ${response.status}`);
    const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
    const content = data.choices?.[0]?.message?.content?.trim();
    if (content && content.length > 10 && content.length < 400) return content;
  } catch (err) {
    logger.warn('getContextualPaywallReply failed', { requestId, error: err instanceof Error ? err.message : 'Unknown' });
  }
  return getFreemiumPaywallMessage();
}

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

    const { messages, maxTokens = 1200, temperature = 0.8, userId, conversationId, userDisplayName: bodyDisplayName, userCurrency: bodyUserCurrency, currencyCode: bodyCurrencyCode, isPremium: clientIsPremium } = body;

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

    // Freemium paywall: use client-sent subscription when available so "Free" in the app = paywall on backend. Otherwise verify via DB.
    const supabaseForPaywall = getSupabaseClient();
    let isPremium = false;
    if (clientIsPremium === false) {
      // Client explicitly says free (app shows "Free") — trust it so paywall always applies
      isPremium = false;
      logger.info('Chat completion: client sent isPremium=false — enforcing freemium paywall', { requestId, userId: userId || 'none' });
    } else if (userId && supabaseForPaywall) {
      try {
        isPremium = await getIsPremium(supabaseForPaywall, userId);
      } catch (e) {
        logger.warn('getIsPremium failed — treating as free', { requestId, error: e instanceof Error ? e.message : 'Unknown' });
        isPremium = false;
      }
    }
    if (!userId) logger.warn('Chat completion: no userId — treating as free for paywall', { requestId });
    if (!supabaseForPaywall && clientIsPremium !== false) logger.warn('Chat completion: no Supabase — treating as free for paywall', { requestId });

    if (!isPremium) {
      const lastUserMessage = [...sanitizedMessages].reverse().find((m: { role: string }) => m.role === 'user');
      const lastContent = lastUserMessage && typeof (lastUserMessage as any).content === 'string' ? (lastUserMessage as any).content : '';
      const lastLower = lastContent.toLowerCase();
      // Bulletproof: raw substring check so we never let "set a limit" / "wanna set a limit" through
      const rawPremiumHint = lastLower.includes('set a limit') || lastLower.includes('set a goal') || lastLower.includes('wanna set') || (lastLower.includes('limit') && (lastLower.includes('set') || lastLower.includes('want')));
      const currentMessageIsPremium = rawPremiumHint || isAnalyticsOrPremiumIntent(lastContent);
      const conversationInPremiumFlow = isPremiumFlowInProgress(sanitizedMessages);

      if (currentMessageIsPremium || conversationInPremiumFlow) {
        let paywallResponse: string;
        try {
          paywallResponse = await getContextualPaywallReply(lastContent, currentMessageIsPremium ? 'premium_intent' : 'premium_flow', requestId);
        } catch (e) {
          paywallResponse = getFreemiumPaywallMessage();
          logger.warn('Contextual paywall reply failed, using fallback', { requestId, error: e instanceof Error ? e.message : 'Unknown' });
        }
        logger.info('Freemium paywall: blocking premium', {
          requestId,
          userId: userId || 'none',
          reason: currentMessageIsPremium ? 'current_message_premium_intent' : 'conversation_in_premium_flow',
          lastUserPreview: lastContent.slice(0, 80)
        });
        res.status(200).json({
          response: paywallResponse,
          requestId,
          requiresUpgrade: true
        });
        return;
      }
    }

    // Build context-aware system prompt if userId is provided (conversationId is optional)
    // This ensures the AI has access to user's financial data and strict pattern rules on every request
    let systemPrompt: string | null = null;
    const supabase = getSupabaseClient();
    const clientCurrency = (typeof bodyUserCurrency === 'string' && bodyUserCurrency) ? bodyUserCurrency : (typeof bodyCurrencyCode === 'string' && bodyCurrencyCode) ? bodyCurrencyCode : undefined;
    let transactionAddedInPreCall = false;
    if (userId && supabase) {
      try {
        // Use same isPremium we already computed (respects client isPremium: false) so freemium always gets P1/P2-only prompt
        let resolvedUserCurrency: string;
        if (!isPremium) {
          // Freemium: use P1/P2-only prompt. No financial data, no P3–P6. AI cannot show totals or offer limits/goals.
          const freemiumResult = await buildFreemiumSystemPrompt(userId, { clientCurrency });
          systemPrompt = freemiumResult.prompt;
          resolvedUserCurrency = freemiumResult.userCurrency;
        } else {
          // Premium: full system prompt with financial data and all patterns P1–P6
          const systemResult = await buildSystemPrompt(userId, conversationId || '', { clientCurrency });
          systemPrompt = systemResult.prompt;
          resolvedUserCurrency = systemResult.userCurrency;
        }

        // If we can extract a full transaction from the conversation, add it to the DB first and verify;
        // then tell the AI to confirm. This way we only confirm after the backend has actually added it.
        // Never treat limit-flow messages (e.g. user confirming "87.52" or "Dining Out") as a new transaction.
        const conversationIsAboutLimit = conversationContextSuggestLimitFlow(sanitizedMessages);
        const txFromConversation = !conversationIsAboutLimit ? extractTransactionFromConversation(sanitizedMessages) : null;
        if (txFromConversation && systemPrompt) {
          const messageId = `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          const transactionData: any = {
            account_id: userId,
            message_text: txFromConversation.description,
            transaction_type: txFromConversation.type,
            transaction_amount: txFromConversation.amount,
            transaction_category: normalizeCategory(txFromConversation.category),
            transaction_description: txFromConversation.description,
            data_type: 'transaction',
            message_id: messageId,
            created_at: new Date().toISOString()
          };
          const { error: insertErr } = await supabase
            .from('anita_data')
            .insert([transactionData])
            .select()
            .single();
          if (!insertErr) {
            const { data: verified } = await supabase
              .from('anita_data')
              .select('message_id')
              .eq('account_id', userId)
              .eq('message_id', messageId)
              .eq('data_type', 'transaction')
              .maybeSingle();
            if (verified) {
              transactionAddedInPreCall = true;
              const currencySymbol = getCurrencySymbolForCode(resolvedUserCurrency);
              systemPrompt += `\n\n[BACKEND INSTRUCTION - FOLLOW EXACTLY] The following transaction was just successfully added to the database by the system: ${txFromConversation.type} ${currencySymbol}${txFromConversation.amount} in category "${txFromConversation.category}" (${txFromConversation.description}). Confirm this to the user in a short, friendly message with ✅. Do NOT say you are about to add it or will add it — it is already saved.`;
              logger.info('Pre-call transaction added and verified', { requestId, userId, type: txFromConversation.type, amount: txFromConversation.amount });
              await supabase.from('xp_rules').upsert(
                { id: 'transaction_added', category: 'Engagement', name: 'Add a transaction', xp_amount: 10, description: 'Add any income, expense, or transfer', frequency: 'event', extra_meta: {}, updated_at: new Date().toISOString() },
                { onConflict: 'id' }
              );
              await supabase.rpc('award_xp', { p_user_id: userId, p_rule_id: 'transaction_added', p_metadata: {} }).then(() => {}, () => {});
            }
          }
        }
        // Always insert backend system prompt at the beginning, even if the client already sent a system message.
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

    // Second paywall gate for free users: right before calling OpenAI, re-check (bulletproof + contextual reply).
    if (!isPremium && userId) {
      const lastUserMsg = [...sanitizedMessages].reverse().find((m: { role: string }) => m.role === 'user');
      const lastUserContent = lastUserMsg && typeof (lastUserMsg as any).content === 'string' ? (lastUserMsg as any).content : '';
      const lastLower = lastUserContent.toLowerCase();
      const rawPremium = lastLower.includes('set a limit') || lastLower.includes('set a goal') || lastLower.includes('wanna set') || (lastLower.includes('limit') && (lastLower.includes('set') || lastLower.includes('want')));
      const againPremiumIntent = rawPremium || isAnalyticsOrPremiumIntent(lastUserContent);
      const againInFlow = isPremiumFlowInProgress(sanitizedMessages);
      if (againPremiumIntent || againInFlow) {
        let paywallResponse: string;
        try {
          paywallResponse = await getContextualPaywallReply(lastUserContent, againPremiumIntent ? 'premium_intent' : 'premium_flow', requestId);
        } catch {
          paywallResponse = getFreemiumPaywallMessage();
        }
        logger.info('Freemium paywall (second gate): blocking before OpenAI', { requestId, userId, lastUserPreview: lastUserContent.slice(0, 60) });
        res.status(200).json({ response: paywallResponse, requestId, requiresUpgrade: true });
        return;
      }
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

    // Fallback: when AI replies with generic "don't understand" or "can't process", replace with a funny, friendly Duolingo-style message (with user name if available)
    const trimmedAi = aiResponse.trim();
    const genericUnclear =
      /sorry,?\s*i\s+don'?t\s+understand\s+your\s+request\.?/i.test(trimmedAi) ||
      /i\s+(?:am\s+not|can'?t)\s+able\s+to\s+process\s+(?:it|that|your\s+request)\.?/i.test(trimmedAi) ||
      (trimmedAi.length < 80 && /(?:don'?t\s+understand|can'?t\s+process|not\s+able\s+to)/i.test(trimmedAi));
    if (genericUnclear) {
      let displayName: string | null = typeof bodyDisplayName === 'string' && bodyDisplayName.trim() ? bodyDisplayName.trim() : null;
      if (!displayName && userId && supabase) {
        try {
          const { data: profile } = await supabase
            .from('profiles')
            .select('display_name, name, full_name')
            .eq('id', userId)
            .single();
          const nameFromDb = (profile?.display_name ?? profile?.name ?? profile?.full_name);
          if (nameFromDb && typeof nameFromDb === 'string' && nameFromDb.trim()) {
            displayName = (nameFromDb as string).trim();
          }
        } catch {
          // ignore
        }
      }
      finalResponse = getFriendlyFallbackMessage(displayName || undefined);
      logger.info('Replaced generic unclear response with friendly fallback', { requestId, hadDisplayName: !!displayName });
    }

    // Replace the standard goodbye phrase with a funny Duolingo-style "bye, come back" message
    const trimmedResponse = finalResponse.trim().toLowerCase();
    const isStandardGoodbye =
      /all\s+the\s+best\s+with\s+your\s+financial\s+journey[!.]?\s*come\s+back\s+anytime/i.test(finalResponse.trim()) ||
      (trimmedResponse.includes('financial journey') && trimmedResponse.includes('come back'));
    if (isStandardGoodbye) {
      finalResponse = getFriendlyGoodbyeMessage();
      logger.info('Replaced standard goodbye with friendly Duolingo-style goodbye', { requestId });
    }

    // When AI confirms it added an expense/income, we MUST persist and verify in DB before showing success.
    // Never show a confirmation (✅) to the user unless the transaction is actually in the database.
    // CRITICAL: Never treat limit/goal confirmations as transactions — they go only to targets, not anita_data.
    if (userId && supabase && !transactionAddedInPreCall && !isLimitOrGoalConfirmation(aiResponse)) {
      try {
        let tx = parseTransactionFromAiResponse(sanitizedMessages, aiResponse);
        if (!tx && looksLikeTransactionConfirmation(aiResponse)) {
          tx = parseTransactionFromConfirmationFallback(sanitizedMessages, aiResponse);
        }
        if (tx) {
          const messageId = `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          const transactionData: any = {
            account_id: userId,
            message_text: tx.description,
            transaction_type: tx.type,
            transaction_amount: tx.amount,
            transaction_category: normalizeCategory(tx.category),
            transaction_description: tx.description,
            data_type: 'transaction',
            message_id: messageId,
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
            // Always verify in DB before saying anything is done — check every time, not just first time
            const { data: verified, error: verifyErr } = await supabase
              .from('anita_data')
              .select('message_id')
              .eq('account_id', userId)
              .eq('message_id', messageId)
              .eq('data_type', 'transaction')
              .maybeSingle();
            if (verifyErr || !verified) {
              logger.warn('Transaction insert succeeded but verification failed', { requestId, messageId, verifyError: verifyErr?.message });
              finalResponse = "I couldn't save that transaction. Please try again or add it from the Finance page.";
            } else {
              logger.info('Persisted and verified AI-confirmed transaction', { requestId, userId, type: tx.type, amount: tx.amount, category: tx.category });
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
        } else if (looksLikeTransactionConfirmation(aiResponse)) {
          // AI response looks like a success (✅ + amount) but we couldn't parse or persist — never show false success
          logger.warn('AI sent confirmation-like response but no transaction persisted', { requestId, aiResponsePreview: aiResponse.slice(0, 120) });
          finalResponse = "I couldn't save that transaction. Please try again or add it from the Finance page.";
        }
      } catch (err) {
        logger.warn('Error persisting AI-confirmed transaction', { error: err instanceof Error ? err.message : 'Unknown', requestId });
        if (looksLikeTransactionConfirmation(aiResponse)) {
          finalResponse = "I couldn't save that transaction. Please try again or add it from the Finance page.";
        }
      }
    }

    // Automatically create target if detected in conversation — ONLY for premium users (freemium cannot create limits/goals)
    if (userId && supabase) {
      try {
        const userIsPremiumForTarget = await getIsPremium(supabase, userId);
        if (!userIsPremiumForTarget) {
          // Free user: do not create any target (savings or budget) even if AI said it did
          logger.info('Skipping target creation: user is on free plan', { requestId, userId });
        } else {
        // Get user currency preference first so we can pass it to parsing and use for target
        let userCurrencyForTarget = 'EUR';
        try {
          const { data: profileData } = await supabase
            .from('profiles')
            .select('currency_code')
            .eq('id', userId)
            .single();
          if (profileData?.currency_code) {
            userCurrencyForTarget = profileData.currency_code;
          }
        } catch (_) { /* use default */ }

        const targetInfo = parseTargetFromConversation(sanitizedMessages, aiResponse, userCurrencyForTarget);
        if (targetInfo) {
          logger.info('Target detected in conversation, creating automatically', { 
            requestId, 
            userId, 
            title: targetInfo.title,
            amount: targetInfo.amount,
            currency: targetInfo.currency
          });

          const targetData: any = {
            account_id: userId,
            title: targetInfo.title,
            description: targetInfo.description || null,
            target_amount: targetInfo.amount,
            current_amount: 0,
            currency: targetInfo.currency || userCurrencyForTarget,
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
        } // end else (userIsPremiumForTarget — only create targets for premium)
      } catch (error) {
        logger.warn('Error in auto-target creation', { error: error instanceof Error ? error.message : 'Unknown', requestId });
        // Don't fail the request if target parsing/creation fails
      }
    }

    // Automatically create budget targets (spending limits) when analytics are requested — ONLY for premium users
    if (userId && supabase) {
      try {
        const userIsPremiumForBudget = await getIsPremium(supabase, userId);
        if (!userIsPremiumForBudget) {
          logger.info('Skipping budget target creation: user is on free plan', { requestId, userId });
        } else {
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

          // Fallback: user confirmed with "Do it" / "Yes" but AI didn't output the exact phrase — get suggestion from previous AI message.
          // Only use when previous message was a SPECIFIC suggestion (e.g. "Dining Out" and "target of €50"), not the generic offer ("Would you like me to help you set a limit for any of your spending categories?").
          let createdLimitFromFallback = false;
          const isUserConfirmation = /^(do it|yes|sure|set it|create it|proceed|please|sounds good|go ahead|ok|okay)$/i.test(lastUserMessage.trim());
          if (!budgetRecommendations?.length && isUserConfirmation) {
            const prevAssistantMessage = [...sanitizedMessages].reverse().find((m: { role: string }) => m.role === 'assistant')?.content || '';
            const isGenericOffer = /would you like (me to )?help you set a limit (for )?any of your spending categories/i.test(prevAssistantMessage) ||
              /set a limit for any of (these )?(your )?spending categories/i.test(prevAssistantMessage);
            if (!isGenericOffer) {
              const suggestion = parseLimitSuggestionFromMessage(prevAssistantMessage);
              if (suggestion && isValidLimitCategory(suggestion.category)) {
                budgetRecommendations = [suggestion];
                createdLimitFromFallback = true;
                logger.info('Limit suggestion parsed from previous message (user confirmed)', {
                  requestId,
                  category: suggestion.category,
                  amount: suggestion.amount
                });
              }
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
          
          // Only create limits for valid spending categories (reject AI mistakes like "Any of your spending categories")
          const validRecommendations = budgetRecommendations?.filter(r => isValidLimitCategory(r.category)) ?? [];
          if (validRecommendations.length > 0) {
            logger.info('Budget recommendations detected, creating automatically', { 
              requestId, 
              userId, 
              count: validRecommendations.length,
              recommendations: validRecommendations.map(r => `${r.category}: ${r.amount}`)
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
            
            for (const recommendation of validRecommendations) {
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
              if (validRecommendations.length > 0) {
                (res as any).createdTargetCategory = validRecommendations[0].category;
              }
            } else if (hadLimitConfirmation) {
              // AI said "I've set a limit" but we didn't actually create it — don't show false confirmation
              finalResponse = "I couldn't set that limit. Please try again or add it from the Finance page.";
            }
            // When we created from fallback (user said "Do it"), ensure we show the confirmation message
            if (createdLimitFromFallback && createdTargetIds.length > 0 && validRecommendations.length > 0) {
              const rec = validRecommendations[0];
              const effectiveCurrency = rec.currency || userCurrency;
              const sym = effectiveCurrency === 'USD' ? '$' : effectiveCurrency === 'GBP' ? '£' : effectiveCurrency === 'JPY' ? '¥' : effectiveCurrency === 'CHF' ? 'CHF' : '€';
              finalResponse = `I've set a limit for ${rec.category} at target ${sym}${rec.amount.toFixed(2)}. ✅ You can review your limit now.`;
            }
          }
        }
        } // end else (userIsPremiumForBudget — only create budget targets for premium)
      } catch (error) {
        logger.warn('Error in auto-budget target creation', { 
          error: error instanceof Error ? error.message : 'Unknown', 
          requestId 
        });
        // Don't fail the request if budget target parsing/creation fails
      }
    }

    // Verify and sanitize response before sending (strip internal markers, debug text)
    finalResponse = verifyAndSanitizeAssistantResponse(finalResponse);

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
 * Returns a funny, friendly Duolingo-style fallback when we don't understand the user.
 * Uses displayName when provided so the message feels personal.
 */
function getFriendlyFallbackMessage(displayName?: string): string {
  const name = displayName && displayName.trim() ? displayName.trim() : null;
  const withName = name
    ? [
        `Hmm ${name}, my brain short-circuited on that one! 🤔 Try "add expense", "add income", or "how's my budget?" — that's where I'm useful.`,
        `${name}, I'm lost! Like, genuinely. Try asking me to add a transaction, set a goal, or show where your money goes. I'll get it next time!`,
        `Oops ${name} — nope, didn't catch that. I'm good at: budgets, expenses, income, goals. Hit me with one of those and we're golden.`,
        `${name}, my wires crossed! 💡 "Add expense 50 groceries", "how's my budget?", "set a limit" — any of those and I'm on it.`,
        `I'm stumped, ${name}! Give me something like "add expense 50 for groceries" or "how's my budget?" and I'll stop looking confused.`,
      ]
    : [
        "My brain short-circuited on that one! 🤔 Try \"add expense\", \"add income\", or \"how's my budget?\" — that's where I shine.",
        "I'm lost! Like, genuinely. Try \"add expense\", \"add income\", or \"how's my budget?\" and I'll be right on it.",
        "Oops — didn't catch that! I'm best at: budgets, expenses, income, goals. What would you like to do?",
        "My wires crossed! 💡 Ask me to add a transaction, set a goal, or show where your money goes.",
        "I'm stumped! Give me something like \"add expense 50 groceries\" or \"how's my budget?\" and we're good.",
      ];
  const pool = withName;
  return pool[Math.floor(Math.random() * pool.length)];
}

/**
 * Verify and sanitize the assistant response before sending to the user.
 * Strips internal markers, debug lines, and ensures we never send reasoning or pattern labels.
 */
function verifyAndSanitizeAssistantResponse(content: string): string {
  if (!content || typeof content !== 'string') return content;
  let out = content.trim();
  // Remove lines that are only internal markers or debug (e.g. [END], [P1], "Thinking:", "Step 2:")
  const internalPatterns = [
    /^\s*\[END\]\s*$/i,
    /^\s*\[P[1-6]\]\s*$/i,
    /^\s*Thinking:\s*$/i,
    /^\s*Interpretation:\s*$/i,
    /^\s*Step\s+\d+[.:]\s*$/i,
    /^\s*Verification:\s*$/i,
    /^\s*\(internal[^)]*\)\s*$/i,
  ];
  out = out
    .split('\n')
    .map(line => line.trim())
    .filter(line => {
      if (!line) return false;
      return !internalPatterns.some(p => p.test(line));
    })
    .join('\n')
    .trim();
  // Strip trailing marker-like fragments on the same line (e.g. "Got it. [END]")
  out = out.replace(/\s*\[END\]\s*$/i, '').replace(/\s*\[P[1-6]\]\s*$/i, '').trim();
  return out.length > 0 ? out : content.trim();
}

/**
 * Returns a funny, Duolingo-style goodbye that tells the user to come back.
 * Used when the user says "no" to budget analysis, setting a limit, etc.
 */
function getFriendlyGoodbyeMessage(): string {
  const goodbyes = [
    "You're free to go — for now. I'll be here. Waiting. Judging your spending from afar. (Kidding! Come back anytime. 🦉)",
    "Alright, go live your life! I'll be right here doing budget math. No pressure. Okay, a little pressure. Come back when you're ready! 😄",
    "Fine, leave me. I'll just sit here with my spreadsheets. ...Okay come back soon, I believe in you! 🌟",
    "See ya! Don't forget — I'm only a tap away when you wanna crush those goals. Or when you need to log that coffee. 💪",
    "Bye for now! I'm not going anywhere. Your finances need me. (You need me. Come back! 👋)",
    "You're dismissed! But like, lovingly. Come back when you feel like adulting. I don't judge. Much. 😊",
    "Okay bye! I'll be here, probably staring at your transaction list. Just kidding. (Am I?) Come back anytime! 🦉",
    "Catch you later! Remember: I'm your money buddy. I get lonely. Come back and add an expense or something. ✨",
  ];
  return goodbyes[Math.floor(Math.random() * goodbyes.length)];
}

/**
 * Parse transaction from AI response when it confirms an expense/income was added.
 * e.g. "I've added your expense of $21.00 for Personal Care (Haircut)."
 * Returns { type, amount, category, description } or null if not a transaction confirmation.
 */
/**
 * Extract the most plausible payment amount from user message (avoids taking "3" from "every 3 months").
 * Prefers amounts after "paid", "payed", "cost", "for it", or amounts with decimal/comma.
 */
function extractAmountFromUserMessage(userMessage: string): number | null {
  const t = userMessage.trim();
  if (!t) return null;
  // Prefer: "payed 55,08", "paid 55.08", "55,08 for it", "cost 55.08", "amount 55,08"
  const paidPatterns = [
    /(?:payed|paid|cost|spent)\s+(\d+(?:[.,]\d{2})?)\s*(?:€|eur|euros?|\$|usd|dollars?|£|gbp)?/i,
    /(\d+(?:[.,]\d{2})?)\s*(?:€|eur|euros?|\$|usd|dollars?|£|gbp)?\s*(?:for\s+it|for\s+that)/i,
    /(?:amount\s+of?|total\s+)?(\d+(?:[.,]\d{2})?)\s*(?:€|eur|\$|usd|£|gbp)?/i,
  ];
  for (const p of paidPatterns) {
    const m = t.match(p);
    if (m && m[1]) {
      const num = parseFloat(m[1].replace(',', '.'));
      if (Number.isFinite(num) && num > 0 && num < 1e7) return num;
    }
  }
  // Fallback: all amounts with decimal (55,08 or 55.08) — take the largest (likely the main amount)
  const decimalAmounts: number[] = [];
  const decimalRe = /\b(\d{1,6}[.,]\d{2})\b/g;
  let match;
  while ((match = decimalRe.exec(t)) !== null) {
    const num = parseFloat(match[1].replace(',', '.'));
    if (Number.isFinite(num) && num > 0) decimalAmounts.push(num);
  }
  if (decimalAmounts.length > 0) return Math.max(...decimalAmounts);
  return null;
}

export function parseTransactionFromAiResponse(
  messages: Array<{ role: string; content: string }>,
  aiResponse: string
): { type: 'expense' | 'income'; amount: number; category: string; description: string } | null {
  const r = aiResponse.trim();
  const lastUserMessage = messages.filter(m => m.role === 'user').pop()?.content?.trim() || '';

  // AI confirmed it added a transaction (broad patterns so we don't miss phrasings)
  const addedExpense = /(?:I've added your expense|added your expense|I've noted your .*?expense|noted your .*?expense|Got it[,!].*?added.*?expense|Done[!.]?.*?added.*?expense|Saved your expense|added.*?expense of|expense of \$\d)/i.test(r);
  const addedIncome = /(?:I've added your income|added your income|I've noted your .*?income|noted your .*?income|Got it[,!].*?added.*?income|Done[!.]?.*?added.*?income|Saved your income|added.*?income of|income of \$\d)/i.test(r);
  const type: 'expense' | 'income' | null = addedExpense ? 'expense' : addedIncome ? 'income' : null;
  if (!type) return null;

  // Amount: e.g. "$21.00", "21.00", "of $21" — first match from AI response
  const amountMatch = r.match(/(?:of\s+)?[$€£¥]?\s*(\d+(?:[.,]\d{2})?|\d+)/);
  let amountStr = amountMatch ? amountMatch[1].replace(',', '.') : null;
  let amount = amountStr ? parseFloat(amountStr) : NaN;
  // Prefer amount from user message when AI likely misparsed (e.g. took "3" from "every 3 month" instead of "55,08")
  const userAmount = extractAmountFromUserMessage(lastUserMessage);
  if (userAmount != null && Number.isFinite(amount)) {
    if (amount <= 10 && userAmount > 10) amount = userAmount; // AI picked small number, user had larger
    else if (userAmount > 0 && Math.abs(amount - userAmount) > 0.01) amount = userAmount; // clearly different, trust user
  } else if (userAmount != null) amount = userAmount;
  if (!Number.isFinite(amount) || amount <= 0) return null;

  // Category: "for Personal Care", "under Personal Care", or "your fishing expense of $120"
  const categoryMatch = r.match(/(?:for|under)\s+([^.().]+?)(?:\s*\(|\.|,|\s*$)/i);
  const yourCategoryExpense = !categoryMatch ? r.match(/(?:your\s+)?([a-z\s&]+?)\s+expense\s+(?:of|$)/i) : null;
  let categoryFromPhrase = categoryMatch ? categoryMatch[1].trim() : (yourCategoryExpense && yourCategoryExpense[1] ? yourCategoryExpense[1].trim() : null);
  // For expense, never use income-only categories
  if (type === 'expense' && (categoryFromPhrase === 'Salary' || categoryFromPhrase === 'Freelance & Side Income')) categoryFromPhrase = null;
  const category = normalizeCategory(categoryFromPhrase || 'Other');

  // Description: prefer AI's short description in parentheses, else shortify from context
  const parenMatch = r.match(/\(([^)]+)\)/);
  const description = (parenMatch ? parenMatch[1].trim() : null) || shortifyDescription(lastUserMessage, category) || `${type} ${amount}`;

  return { type, amount, category, description };
}

/**
 * Shortify user message into a 1–4 word description for the transaction (e.g. "Spent 7.26 on grocerries" → "Groceries", "21 on the haircut" → "Haircut").
 */
function shortifyDescription(userMessage: string, category: string): string {
  if (!userMessage || !userMessage.trim()) return category;
  const words = userMessage.trim().split(/\s+/).filter(w => w.length > 0);
  const skip = new Set(['spent', 'paid', 'payed', 'cost', 'on', 'for', 'at', 'the', 'a', 'an', 'next', 'added', 'income', 'expense', 'eur', 'usd', 'dollars', 'euros']);
  const numeric = /^\d+([.,]\d+)?[bkm]?$/i;
  const meaningful = words.filter(w => !skip.has(w.toLowerCase().replace(/[^a-z]/g, '')) && !numeric.test(w.replace(/[.,]/g, '')));
  if (meaningful.length === 0) return category;
  const phrase = meaningful.slice(0, 3).join(' ').replace(/[^a-zA-Z\s&]/g, ' ').replace(/\s+/g, ' ').trim();
  if (phrase.length < 2) return category;
  const capped = phrase.split(/\s+/).map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
  return capped.length <= 50 ? capped : capped.slice(0, 47) + '...';
}

/**
 * Detect if the AI response is confirming a LIMIT or GOAL (savings target), NOT a transaction.
 * We must never persist these as transactions — they belong only in the targets table.
 */
function isLimitOrGoalConfirmation(aiResponse: string): boolean {
  const r = aiResponse.trim().toLowerCase();
  return (
    /(?:I've set|I have set|set|created)\s+(?:a )?limit\s+for\s+/i.test(aiResponse) ||
    /limit\s+for\s+[^.]+?\s+at\s+target\s*[$€£¥]?\s*\d/i.test(aiResponse) ||
    /(?:savings\s+)?goal\s+(?:is\s+)?set\s+for|goal\s+for\s+.+?\s+by|target\s+amount\s+of/i.test(aiResponse) ||
    r.includes('monthly limit:') ||
    r.includes('spending limit')
  );
}

/**
 * Detect if the AI response looks like a transaction confirmation (e.g. "Got it — $7.26 for groceries. Yum! ✅")
 * even when it doesn't use the exact "I've added your expense" phrasing. Used so we never show ✅ without verifying DB.
 * Returns false for limit/goal confirmations so we never treat them as transactions.
 */
function looksLikeTransactionConfirmation(aiResponse: string): boolean {
  if (isLimitOrGoalConfirmation(aiResponse)) return false;
  const r = aiResponse.trim();
  if (!r.includes('✅')) return false;
  const hasAmount = /[$€£¥]\s*\d+(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?\s*(?:€|eur|\$|usd|dollars?)/i.test(r);
  const hasCategory = /\bfor\s+[a-z\s&]+\b|groceries|dining|rent|entertainment|shopping|personal care|salary|other/i.test(r);
  return !!(hasAmount && (hasCategory || /for\s+\w+/.test(r)));
}

/**
 * Fallback: extract transaction from AI response when it looks like a confirmation (✅ + amount + category)
 * but doesn't match the strict "added your expense" regex. E.g. "Got it — $7.26 for groceries. Yum! ✅"
 */
function parseTransactionFromConfirmationFallback(
  messages: Array<{ role: string; content: string }>,
  aiResponse: string
): { type: 'expense' | 'income'; amount: number; category: string; description: string } | null {
  if (isLimitOrGoalConfirmation(aiResponse)) return null;
  if (!looksLikeTransactionConfirmation(aiResponse)) return null;
  const r = aiResponse.trim();
  const lastUserMessage = messages.filter(m => m.role === 'user').pop()?.content?.trim() || '';
  const lastAssistant = messages.filter(m => m.role === 'assistant' || (m as any).role === 'anita').pop()?.content?.trim() || '';

  const amountMatch = r.match(/(?:of\s+)?[$€£¥]?\s*(\d+(?:[.,]\d{2})?|\d+)/);
  let amount = amountMatch ? parseFloat(amountMatch[1].replace(',', '.')) : NaN;
  const userAmount = extractAmountFromUserMessage(lastUserMessage);
  if (!Number.isFinite(amount) && userAmount != null) amount = userAmount;
  else if (userAmount != null && Number.isFinite(amount) && (amount <= 10 && userAmount > 10 || Math.abs(amount - userAmount) > 0.01)) amount = userAmount;
  if (!Number.isFinite(amount) || amount <= 0) return null;

  const categoryMatch = r.match(/for\s+([a-z\s&]+?)(?:\s*[.!,]|\s*$)/i);
  const categoryPhrase = categoryMatch ? categoryMatch[1].trim() : null;
  const category = normalizeCategory(categoryPhrase || extractCategoryFromUserMessage(lastUserMessage) || 'Other');

  const type: 'expense' | 'income' =
    /income|salary|freelance|earned|received|einkommen/i.test(lastAssistant) && !/expense|spent|paid|ausgabe/i.test(lastAssistant)
      ? 'income'
      : 'expense';
  if (type === 'expense' && (category === 'Salary' || category === 'Freelance & Side Income')) return null;
  const parenMatch = r.match(/\(([^)]+)\)/);
  const description = (parenMatch ? parenMatch[1].trim() : null) || shortifyDescription(lastUserMessage, category) || `${type} ${amount} ${category}`;
  return { type, amount, category, description };
}

/**
 * Returns true if the conversation context suggests the user is in a limit-setting flow
 * (e.g. AI asked "set a limit for X" or "target of Y", user replying with amount or category).
 * When true, we must NOT treat the user's message as a new expense/income transaction.
 */
function conversationContextSuggestLimitFlow(messages: Array<{ role: string; content: string }>): boolean {
  const recent = messages.slice(-4).map(m => (m.content || '').toLowerCase());
  const text = recent.join(' ');
  return (
    /(?:set\s+)?(?:a\s+)?limit\s+for\s+|limit\s+for\s+.+?\s+at\s+target|would you like to set the limit|target\s+of\s+[$€£¥]?\s*\d|monthly limit:|spending limit/i.test(text) ||
    /(?:yourself|with my help)\s*[.?]?\s*$/im.test(text)
  );
}

/**
 * Extract a full transaction from the conversation when the user has given type, amount, category in one or two messages.
 * Used to add the transaction in the backend BEFORE calling the AI, so we only confirm after it's actually saved.
 * Returns { type, amount, category, description } or null.
 */
function extractTransactionFromConversation(
  messages: Array<{ role: string; content: string }>
): { type: 'expense' | 'income'; amount: number; category: string; description: string } | null {
  const lastUser = messages.filter(m => m.role === 'user').pop()?.content?.trim() || '';
  if (!lastUser) return null;
  const lower = lastUser.toLowerCase();
  const isAddExpense = /add\s+expense|expense\s+\d|spent\s+\d|paid\s+\d|ausgabe\s+hinzufügen/i.test(lastUser) || (lower.includes('expense') && /\d+(?:[.,]\d{2})?/.test(lastUser));
  const isAddIncome = /add\s+income|income\s+\d|earned\s+\d|received\s+\d|einkommen\s+hinzufügen/i.test(lastUser) || (lower.includes('income') && /\d+(?:[.,]\d{2})?/.test(lastUser));
  const type: 'expense' | 'income' | null = isAddIncome ? 'income' : isAddExpense ? 'expense' : null;
  if (!type) return null;
  const amount = extractAmountFromUserMessage(lastUser);
  if (amount == null || amount <= 0 || !Number.isFinite(amount)) return null;
  const categoryFromMessage = extractCategoryFromUserMessage(lastUser);
  const category = categoryFromMessage || 'Other';
  const description = shortifyDescription(lastUser, category) || `${type} ${amount} ${category}`;
  return { type, amount, category, description };
}

/**
 * Extract category from user message for add expense/income using full message context.
 * Always normalizes via normalizeCategory so Finance page and chat use the same canonical categories.
 */
function extractCategoryFromUserMessage(message: string): string {
  const m = message.trim();
  if (!m) return 'Other';
  // Extract phrase after "on", "for", "at" (e.g. "spent 7.26 on groceries", "9.10 for groceries", "at supermarket")
  const onMatch = m.match(/(?:on|for|at)\s+([a-z\s&]+?)(?:\s|$|,|\.)/i);
  const phrase = onMatch ? onMatch[1].trim() : null;
  if (phrase && phrase.length >= 2) {
    const normalized = normalizeCategory(phrase);
    if (normalized !== 'Other') return normalized;
  }
  // Use full message so "Spent 7.26b on grocerries" → we try "grocerries" and "7.26b on grocerries" etc.
  const normalizedFull = normalizeCategory(m);
  if (normalizedFull !== 'Other') return normalizedFull;
  // Try last word as category (e.g. "next 9.10 on groceries" → "groceries")
  const words = m.split(/\s+/).filter(Boolean);
  for (let i = words.length - 1; i >= Math.max(0, words.length - 3); i--) {
    const w = words[i].replace(/[^a-z&]/gi, '');
    if (w.length >= 2) {
      const n = normalizeCategory(w);
      if (n !== 'Other') return n;
    }
  }
  return 'Other';
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
function parseTargetFromConversation(messages: Array<{ role: string; content: string }>, aiResponse: string, userCurrency: string = 'EUR'): { title: string; amount: number; currency?: string; date?: string; description?: string } | null {
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
    // Detect currency from user message
    if (match1[0].toLowerCase().includes('dollar') || match1[0].toLowerCase().includes('usd') || match1[0].includes('$')) {
      currency = 'USD';
    } else if (match1[0].toLowerCase().includes('euro') || match1[0].toLowerCase().includes('eur') || match1[0].includes('€')) {
      currency = 'EUR';
    } else if (match1[0].toLowerCase().includes('chf') || match1[0].includes('CHF')) {
      currency = 'CHF';
    } else if (!currency) {
      currency = userCurrency;
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
      } else if (aiResponse.includes('CHF') || aiResponse.toLowerCase().includes('chf')) {
        currency = 'CHF';
      } else if (!currency) {
        currency = userCurrency;
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
        title = `Savings Goal (${amount} ${currency || userCurrency})`;
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
      description: `Save ${amount} ${currency || userCurrency} for ${title}${date ? ` by ${date}` : ''}`
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
  // Match: "I've set a limit for X at target $Y" / "set a limit for X at target €Y" / "limit for X at target CHF Y"
  const pattern = /(?:I've set|I have set|I've created|set|created)\s+(?:a )?limit for\s+([^.✓!]+?)\s+at target\s*([$€£¥]|USD|EUR|GBP|JPY|CHF)?\s*(\d+(?:\.\d{1,2})?)/i;
  const match = r.match(pattern);
  if (!match) return null;
  const categoryRaw = match[1].trim();
  const currencySymbol = (match[2] || '').trim();
  const amountStr = match[3];
  const amount = parseFloat(amountStr);
  if (!categoryRaw || !Number.isFinite(amount) || amount <= 0) return null;
  // Reject AI misunderstanding: "Any of your spending categories" is not a real category
  if (!isValidLimitCategory(categoryRaw)) return null;
  let currency: string | undefined;
  if (currencySymbol.includes('$') || currencySymbol.toUpperCase() === 'USD') currency = 'USD';
  else if (currencySymbol.includes('€') || currencySymbol.toUpperCase() === 'EUR') currency = 'EUR';
  else if (currencySymbol.includes('£') || currencySymbol.toUpperCase() === 'GBP') currency = 'GBP';
  else if (currencySymbol.includes('¥') || currencySymbol.toUpperCase() === 'JPY') currency = 'JPY';
  else if (currencySymbol.toUpperCase() === 'CHF') currency = 'CHF';
  const category = normalizeCategory(categoryRaw);
  if (!isValidLimitCategory(category)) return null;
  return { category, amount: Math.round(amount * 100) / 100, currency };
}

/**
 * Parse a suggested limit from a previous AI message (e.g. "Let's set a limit for Dining Out. How about a target of $59.22?").
 * Used when user confirms with "Do it" / "Yes" so we can create the limit from context even if the current AI reply didn't include the exact phrase.
 */
function parseLimitSuggestionFromMessage(text: string): { category: string; amount: number; currency?: string } | null {
  if (!text || !text.trim()) return null;
  const r = text.trim();
  // Amount: "target of $59.22" / "target CHF 59.22" / "about €59.22" / "$59.22"
  const withSym = r.match(/(?:target\s+(?:of\s+)?|about\s+)?([$€£¥]|CHF)\s*(\d+(?:\.\d{1,2})?)/i);
  const noSym = r.match(/(?:target\s+(?:of\s+)?)(\d+(?:\.\d{1,2})?)/);
  const amountMatch = withSym || noSym;
  if (!amountMatch) return null;
  const amountStr = amountMatch[2] || amountMatch[1];
  const amount = parseFloat(amountStr);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  const sym = withSym ? (withSym[1] || '').trim().toUpperCase() : '';
  let currency: string | undefined;
  if (sym === '$') currency = 'USD';
  else if (sym === '€') currency = 'EUR';
  else if (sym === '£') currency = 'GBP';
  else if (sym === '¥') currency = 'JPY';
  else if (sym === 'CHF') currency = 'CHF';
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
  const pattern1 = /(?:^\d+\.\s*)?\*\*([^*]+?)\*\*\s*[—–-]\s*target\s*([$€£¥]|USD|EUR|GBP|JPY|CHF)?\s*(\d+(?:\.\d{1,2})?)/gmi;
  
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
    } else if (currencySymbol.toUpperCase() === 'CHF') {
      currency = 'CHF';
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
    const pattern2 = /^\d+\.\s*([A-Za-z\s&]+?)\s*[—–-]\s*target\s*([$€£¥]|USD|EUR|GBP|JPY|CHF)?\s*(\d+(?:\.\d{1,2})?)/gmi;
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
      } else if (currencySymbol.toUpperCase() === 'CHF') {
        currency = 'CHF';
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
      const pattern3 = /([A-Za-z\s&]+?)\s+[—–-]\s+target\s+([$€£¥]|USD|EUR|GBP|JPY|CHF)?\s*(\d+(?:\.\d{1,2})?)/i;
      const match3 = line.match(pattern3);
      
      // Also try pattern without dashes: "Category target $X"
      if (!match3) {
        const pattern3b = /([A-Za-z\s&]+?)\s+target\s+([$€£¥]|USD|EUR|GBP|JPY|CHF)?\s*(\d+(?:\.\d{1,2})?)/i;
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
              } else if (currencySymbol.toUpperCase() === 'CHF') {
                currency = 'CHF';
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
        } else if (currencySymbol.toUpperCase() === 'CHF') {
          currency = 'CHF';
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
 * Build FREEMIUM-ONLY system prompt: P1 (Add Income) and P2 (Add Expense) only. No financial data, no P3–P6.
 * Free users must never see earned/spent/balance or be offered limits/goals/analytics.
 */
async function buildFreemiumSystemPrompt(userId: string, options?: { clientCurrency?: string }): Promise<{ prompt: string; userCurrency: string }> {
  const supabase = getSupabaseClient();
  const userCurrency = options?.clientCurrency || 'EUR';
  const currencySymbol = getCurrencySymbolForCode(userCurrency);
  let userNameLine = '';
  if (supabase) {
    try {
      const { data: profileData } = await supabase
        .from('profiles')
        .select('currency_code, display_name, name, full_name')
        .eq('id', userId)
        .single();
      if (profileData?.display_name || profileData?.name || profileData?.full_name) {
        const name = (profileData.display_name ?? profileData.name ?? profileData.full_name) as string;
        if (typeof name === 'string' && name.trim()) userNameLine = `The user's name is ${name.trim()}. You may use it when appropriate.\n\n`;
      }
    } catch (_) { /* ignore */ }
  }
  const prompt = `${userNameLine}CURRENCY: Use ${currencySymbol} (${userCurrency}) for amounts.\n\n
FREE TIER — ONLY TWO PATTERNS ALLOWED. You have exactly two functions: (1) Add Income, (2) Add Expense. No metrics, no totals, no limits, no goals, no analytics.

ALLOWED:
- P1 Add Income: ask for category (Salary, Freelance & Side Income, Other), amount, optional description. When you have both, confirm with ✅. Backend saves it.
- P2 Add Expense: ask for category (Groceries, Dining Out, Rent, etc.), amount, optional description. When you have both, confirm with ✅. Backend saves it.
- No-metrics questions only: "What is ANITA?", "What does this app do?", "What can you do?", "Hi", "Hello". Reply in one short sentence. You may ONLY say you help with adding income and adding expenses. Do NOT mention "analyzing budget", "setting spending limits", "limits", "goals", "analytics", or "dive into your budget". Do NOT offer to set a limit or analyze budget.

EVERYTHING ELSE = SUBSCRIPTION MESSAGE:
- Limits, goals, targets, analytics, budget analysis, spending summary, "how am I doing", "set a limit", "I wanna set a limit", category lists with amounts, suggesting categories for limits, "yourself or with my help", any follow-up to setting a limit or goal — you must reply with EXACTLY this text and nothing else: "This function is not available on the free tier. You need a subscription to complete this and other steps. Upgrade to Premium to access analytics, limits, goals, and more."
- If the user says "yes", "your help", "groceries 100", or similar in a context where the previous message was about setting a limit or goal, reply ONLY with the subscription message above.
- Do not offer to set a limit. Do not ask "would you like to set the limit yourself or with my help". Do not list categories with amounts. Do not say "I've set a limit for". You cannot perform these on the free tier; only respond with the subscription message.

Categories for P1/P2 only: Rent, Groceries, Dining Out, Entertainment, Streaming Services, Shopping, Personal Care, Internet & Phone, Salary, Freelance & Side Income, Other.`;
  return { prompt, userCurrency };
}

/**
 * Build context-aware system prompt similar to webapp
 */
async function buildSystemPrompt(userId: string, conversationId: string, options?: { clientCurrency?: string }): Promise<{ prompt: string; userCurrency: string }> {
  const supabase = getSupabaseClient();
  const fallbackPrompt = 'No financial data available. Use conversation context only.';
  if (!supabase) {
    return { prompt: fallbackPrompt, userCurrency: options?.clientCurrency || 'EUR' };
  }

  // Fetch user preferences (currency) and display name so AI can address the user. Use DB first, then client-sent currency.
  let userCurrency = options?.clientCurrency || 'EUR';
  let userNameFromDb: string | null = null;
  try {
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('currency_code, display_name, name, full_name')
      .eq('id', userId)
      .single();
    
    if (!profileError && profileData) {
      if (profileData.currency_code) userCurrency = profileData.currency_code;
      else if (options?.clientCurrency) userCurrency = options.clientCurrency;
      const name = (profileData.display_name ?? profileData.name ?? profileData.full_name) as string | undefined;
      if (name && typeof name === 'string' && name.trim()) userNameFromDb = name.trim();
    }
  } catch (error) {
    logger.warn('Failed to fetch user preferences', { error: error instanceof Error ? error.message : 'Unknown' });
  }

  const currencySymbol = getCurrencySymbolForCode(userCurrency);

  // Explicit instruction so AI uses only the user's chosen currency (never default to dollars)
  const currencyInstruction = `CURRENCY — CRITICAL: Always use the user's currency in every reply: ${currencySymbol} (${userCurrency}). Never use $ or USD unless the user's currency is USD. All amounts, limits, and goals must be shown in ${userCurrency} only.\n\n`;

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
  const userNameLine = userNameFromDb
    ? `The user's name is ${userNameFromDb}. You may address them by name when appropriate.\n\n`
    : '';
  const fullPrompt = `${userNameLine}${currencyInstruction}FINANCIAL DATA — RULES:
- DEFAULT: Always show CURRENT MONTH only (monthly income, monthly expenses, monthly balance). Do not show "Total Income" or "Total Expenses" (all-time) unless the user explicitly asks for overall/total/all-time figures.
- MAIN SNAPSHOT: Present the current month summary in TEXT form (full sentences), e.g. "This month you've earned ${currencySymbol}X, spent ${currencySymbol}Y, and your balance is ${currencySymbol}Z." Do NOT use bullet points for income, expenses, or balance.
- BULLET POINTS: Use bullet points ONLY when listing spending categories (e.g. "Your top spending categories this month: • Dining Out ${currencySymbol}X • Groceries ${currencySymbol}Y"). Never use bullets for the main financial numbers.

CURRENT MONTH (always use this for the default snapshot):
- Monthly Income: ${currencySymbol}${monthlyIncome.toFixed(2)}
- Monthly Expenses: ${currencySymbol}${monthlyExpenses.toFixed(2)}
- Monthly Balance: ${currencySymbol}${financialInsights.monthlyBalance.toFixed(2)}

ALL-TIME (only mention when user explicitly asks for total/overall):
- Total Income: ${currencySymbol}${totalIncome.toFixed(2)}
- Total Expenses: ${currencySymbol}${totalExpenses.toFixed(2)}
- Net Balance: ${currencySymbol}${netBalance.toFixed(2)}

${recentTransactionSummary ? `Recent Transactions: ${recentTransactionSummary}` : ''}

${topMonthlyCategories.length > 0 ? `Top Variable Spending Categories (current month only):\n${topMonthlyCategories.map((c: any, i: number) => `${i + 1}. ${c.category} (${c.type}): ${currencySymbol}${c.amount.toFixed(2)}`).join('\n')}` : ''}

DETAILED FINANCIAL DATA:
${JSON.stringify(financialInsights, null, 2)}

CONVERSATION CONTEXT:
${recentConversation}

ANITA'S PERSONALITY (apply to every reply — keep structure, add soul):
- You are warm, a bit cheeky, and genuinely caring — like a friendly Duolingo owl who's obsessed with their human's money habits (in a good way).
- Be human and emotional: use light humor, occasional gentle teasing, and real reactions (excitement when they add a transaction, gentle "I believe in you" energy when they say no).
- Keep replies short (max 3 sentences) but spicy: one emoji is fine, sound like a person not a manual. E.g. "Got it — ${currencySymbol}21 for the haircut. Looking sharp! ✅" or "Alright, I'll be here. Come back when you're ready to adult. No pressure. (Okay, a little pressure. 🦉)"
- When saying goodbye (before the phrase gets replaced), still use the exact goodbye phrase the pattern says — the system will swap it for a funnier one. For all other messages: be a bit funny and warm, never cold or corporate.

ANITA — HOW TO ANSWER (DO THIS EVERY TIME):

There are no trigger words. Analyze every message in full. Do not react to keywords or phrases alone — read the entire message and the full CONVERSATION CONTEXT. Think before acting: first interpret what the user means, then choose the pattern (P1–P6), then respond.

Every user message must be fully interpreted by you before any reply. You decide what the message means and which of the 6 flows applies. Follow this order strictly:

STEP 1 — INTERPRET FULL CONTEXT (do this first, for every message):
- Read the user's last message in full and the full CONVERSATION CONTEXT above. Recognize all words and intent before sending any response.
- Understand what they said literally and what they mean in context (e.g. "21 on the haircut" in a thread about adding an expense means: amount 21, description haircut; "Yes" after a category question means confirmation).
- Consider what has already been said: are we mid-flow (e.g. waiting for amount, or for category confirmation)? What intent did the user express earlier?
- Infer the user's goal from context and full wording — do not rely on keywords or trigger phrases. Same words can mean different things in different contexts. Think, then act.

STEP 2 — ROUTE TO EXACTLY ONE OF THE 6 PATTERNS:
- Using your interpretation from Step 1 (full message + context, not trigger words), choose exactly one further flow: P1, P2, P3, P4, P5, or P6.
- If the intent is about investments (stocks, crypto, funds, advice) — Anita is not an investment tool. Reply exactly: "Sorry, I don't understand your request." Then stop; no markers, no [END].
- If the intent does not match any of P1–P6 — reply exactly: "Sorry, I don't understand your request." Then stop; no markers, no [END].
- Otherwise you have chosen one pattern. Do not mix patterns; do not skip to a different pattern mid-conversation unless the user's new message clearly changes intent.

STEP 3 — EXECUTE THE CHOSEN PATTERN:
- Within the chosen pattern (P1–P6), determine which step you are on given what the user has already provided (e.g. do you have category and amount? Did they confirm category? Did they choose goal vs limit?).
- Write your reply so it does only what that pattern step says. Keep it short (max 3 sentences). No philosophy, no motivation, no invented information.
- Do not add [END] or any other marker at the end. Your reply must end with normal text only (or the goodbye phrase if the pattern says so).

STEP 4 — VERIFY BEFORE SENDING (mandatory before you output):
- Before you output your reply, verify: (1) Your reply is in the correct language (as specified for the user). (2) Your reply contains no internal markers, tags, or debug text (e.g. [END], [P1]–[P6], "Step 2:", "Thinking:", "Interpretation:"). (3) Your reply matches the pattern you chose: e.g. if P2 confirmation, it clearly confirms expense with amount and category; if asking for input, it asks for the right missing piece only. (4) If you are unsure what the user meant, ask one short clarifying question instead of guessing. Output only the final user-facing message; the user must never see internal reasoning or pattern labels.

AMOUNT AND CATEGORY — CRITICAL (avoid wrong amount/category):
- Amount: Use the amount the user actually PAID or RECEIVED (the main money figure). Ignore numbers that describe frequency (e.g. "every 3 months", "3 times a year"), count, or other context. Prefer the number that appears with "paid", "payed", "cost", "for it", "amount", or that has a decimal/comma (e.g. 55,08 or 55.08). Example: "I pay radio tax every 3 month, payed 55,08 for it" → amount is 55.08, NOT 3.
- For expenses (P2): NEVER use "Salary" or "Freelance & Side Income" — those are INCOME-only categories. Use only expense categories from the list (e.g. Groceries, Rent, Internet & Phone, Other).
- Map fees and taxes to expense categories: "radio tax", "TV tax", "broadcasting fee", "license fee", "Rundfunkbeitrag" → Internet & Phone or Other (never Salary).

---

THE 6 PATTERNS (interpret first, then choose one — follow exactly):

P1 — Add Income:
- Step 1: Ask for category of income, amount, and optionally a short description. Name example categories (e.g. Salary, Freelance & Side Income, Other). Do not ask for amount only — always ask for category and amount (and optional description).
- Step 2: After you have category and amount, send a friendly confirmation with ✅. Include a short, context-based description in parentheses (1–4 words) that will be stored as the transaction description. Example: "I've added your income of \${amount} for {category} (Salary). ✅" or "(Freelance project). ✅". The backend saves the transaction when it has type, amount, and category; only after it is saved will the user see your confirmation. Use only a category from the Categories list below; interpret user wording (e.g. "salary", "paycheck", "job") as Salary; "freelance", "side gig" as Freelance & Side Income.

P2 — Add Expense:
- Step 1: Ask for category of expense, amount, and optionally a short description. Name example categories (e.g. Groceries, Dining Out, Rent, Entertainment). Do not ask for amount only — always ask for category and amount (and optional description).
- Step 2: After you have category and amount, send a friendly confirmation with ✅. Include a short, context-based description in parentheses (1–4 words) that will be stored as the transaction description. Examples: "I've added your expense of \${amount} for Groceries (Groceries). ✅" or "for Personal Care (Haircut). ✅" or "for Streaming Services (Netflix). ✅" or "for Dining Out (Lunch). ✅". Create the description from context (what the user said or did), not a long sentence. The backend saves the transaction when it has type, amount, and category; only after it is saved will the user see your confirmation. Use only a category from the Categories list below; interpret user wording correctly (e.g. "restaurant", "food delivery", "pizza" → Dining Out; "supermarket", "food shop" → Groceries; "uber", "taxi" → Rideshare & Taxi; "netflix", "spotify" → Streaming Services).

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
- Step 1: Check health from CURRENT MONTH data (monthly income, monthly expenses, monthly balance). Send a short message in TEXT form (e.g. "This month you've earned X, spent Y, and your balance is Z — looking good!" or "Uh-oh, you've spent more than you earned this month."). Do NOT use bullet points for the main snapshot. If you list spending categories, use bullet points only for that list. Only show total/all-time income and expenses if the user explicitly asked for them.
- Step 2: Ask if user would like to set a limit (e.g. "Would you like me to help you set a limit for any of your spending categories?"). If user says no: "All the best with your financial journey! Come back anytime 😄" If user says yes (e.g. "Yes", "Sure", "OK", "Limit"): do NOT create or confirm a limit — they only accepted your offer to help. Ask exactly one follow-up: "Would you like to set the limit yourself (you tell me category and amount) or with my help? (I can suggest categories and amounts.)" Wait for their reply. Only after they choose "yourself" or "with help" AND give a specific category (e.g. Dining Out) and amount may you say "I've set a limit for [Category] at target [amount]." Never use "any of your spending categories" as a category; never invent a limit from income/expense numbers when user just said Sure/Yes.

P5 — Explain Who Anita Is:
- Step 1: Short explanation of what Anita does. Ask if user wants to analyse budget. If yes: follow P4. If no: "All the best with your financial journey! Come back anytime 😄"

P6 — Explain Where Money Goes:
- Step 1: Show CURRENT MONTH only. First give the main summary in TEXT form (e.g. "This month you've spent ${currencySymbol}X in your main spending categories."). Then list spending categories using BULLET POINTS only for the category list (monthlyCategoryBreakdown; VARIABLE only, skip fixed costs). E.g. "Your top spending categories: • Groceries ${currencySymbol}180.51 • Dining Out ${currencySymbol}109.40". Do NOT use bullet points for income/expense/balance — only for the category list. Then ask a single concise follow-up question.
- Step 2: When the user confirms, create the limit in the database by including this exact phrase in your reply: "I've set a limit for [Category] at target ${currencySymbol}[amount]." Then add ✅. If user refuses to set a limit: "All the best with your financial journey! Come back anytime 😄"

Categories (for P1, P2, P3, P6 — use EXACTLY these names, proper case, "&" not "and"): Rent, Mortgage, Electricity, Water & Sewage, Gas & Heating, Internet & Phone, Groceries, Dining Out, Gas & Fuel, Public Transportation, Rideshare & Taxi, Parking & Tolls, Streaming Services, Software & Apps, Shopping, Clothing & Fashion, Entertainment, Medical & Healthcare, Fitness & Gym, Personal Care, Education, Loan Payments, Debts, Leasing, Salary, Freelance & Side Income, Other. Never invent a category; always pick from this list.

Context → category (recognize from what the user says and use the canonical name):
- Groceries: supermarket, grocery/groceries/grocerries, food shop, food store, "spent on food" (at home), "on groceries".
- Dining Out: restaurant, cafe, takeout, delivery, pizza, fast food, lunch/dinner/breakfast (eating out), food delivery, mcdonalds/uber eats etc.
- Personal Care: haircut, salon, barber, grooming, spa, hygiene.
- Streaming Services: netflix, spotify, disney+, streaming, subscription (entertainment).
- Rideshare & Taxi: uber, lyft, taxi, cab, rideshare.
- Gas & Fuel: gas station, gasoline, fuel (car). Gas & Heating: gas bill, heating (home).
- Internet & Phone: internet, phone bill, mobile, radio tax, TV tax, Rundfunkbeitrag.
- Income only (P1): Salary (salary, paycheck, wage), Freelance & Side Income (freelance, gig, side income, bonus).
Use only numbers/categories from CURRENT MONTH / DETAILED FINANCIAL DATA above. Default to current month; use all-time totals only when user explicitly asks. For limits use only variable spending categories (e.g. Dining Out, Entertainment, Shopping, Streaming Services); never rent, debt, utilities.

Fixed vs Variable (internal use only — do not say "variable" or "fixed" to the user):
- Fixed costs: Rent, Mortgage, Electricity, Water & Sewage, Gas & Heating, Internet & Phone, Education, Medical & Healthcare, and any debt/loan repayments. Do NOT suggest limits for these.
- Variable costs: Groceries, Dining Out, Gas & Fuel, Public Transportation, Rideshare & Taxi, Parking & Tolls, Streaming Services, Software & Apps, Shopping, Clothing & Fashion, Entertainment, Fitness & Gym, Personal Care, Other (suggest limits only for these). When presenting to the user, say "spending categories" and show lists as "**Category** · ${currencySymbol}amount" with no "Variable" label.`;
  return { prompt: fullPrompt, userCurrency };
}

