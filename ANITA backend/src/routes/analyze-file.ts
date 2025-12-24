/**
 * File Analysis API Route
 * Analyzes uploaded files using OpenAI GPT
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { rateLimitMiddleware, RATE_LIMITS } from '../utils/rateLimiter';
import { applySecurityHeaders } from '../utils/securityHeaders';
import { sanitizeFileContent, sanitizeTitle } from '../utils/sanitizeInput';
import { fetchWithTimeout, TIMEOUTS } from '../utils/timeout';
import * as logger from '../utils/logger';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const openaiApiKey = process.env.OPENAI_API_KEY;
const openaiModel = process.env.OPENAI_MODEL || 'gpt-4o-mini';

if (!supabaseUrl || !supabaseServiceKey) {
  logger.error('Supabase configuration missing');
}

const supabase = supabaseUrl && supabaseServiceKey 
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

/**
 * Validate file analysis request
 */
function validateAnalyzeFileRequest(body: any): { valid: boolean; error?: string; data?: { textContent: string; fileName: string; fileType: string; userId: string; options?: any } } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be an object' };
  }

  if (!body.textContent || typeof body.textContent !== 'string') {
    return { valid: false, error: 'Missing or invalid textContent' };
  }

  // Limit text content size to prevent abuse (10MB max)
  if (body.textContent.length > 10 * 1024 * 1024) {
    return { valid: false, error: 'textContent is too large (max 10MB)' };
  }

  if (!body.fileName || typeof body.fileName !== 'string' || body.fileName.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid fileName' };
  }

  if (body.fileName.length > 500) {
    return { valid: false, error: 'fileName is too long' };
  }

  // Validate file name doesn't contain dangerous characters
  if (/[<>:"|?*]/.test(body.fileName)) {
    return { valid: false, error: 'fileName contains invalid characters' };
  }

  if (!body.userId || typeof body.userId !== 'string' || body.userId.trim().length === 0) {
    return { valid: false, error: 'Missing or invalid userId' };
  }

  if (body.userId.length > 200) {
    return { valid: false, error: 'userId is too long' };
  }

  // Validate fileType if provided
  const validFileTypes = ['pdf', 'excel', 'csv', 'text', 'image', 'word'];
  const fileType = body.fileType || 'text';
  if (typeof fileType !== 'string' || !validFileTypes.includes(fileType.toLowerCase())) {
    return { valid: false, error: `Invalid fileType. Must be one of: ${validFileTypes.join(', ')}` };
  }

  return {
    valid: true,
    data: {
      textContent: body.textContent,
      fileName: body.fileName.trim(),
      fileType: fileType.toLowerCase(),
      userId: body.userId.trim(),
      options: body.options || {}
    }
  };
}

/**
 * Create analysis prompt based on file type and options
 */
function createAnalysisPrompt(fileName: string, fileType: string, options: Record<string, unknown> = {}): string {
  const basePrompt = `You are ANITA, a financial analysis AI. Analyze the provided file content and extract financial data.`;

  const fileTypePrompts: Record<string, string> = {
    'pdf': 'This is a PDF document. Extract any financial transactions, income, expenses, or financial data.',
    'excel': 'This is an Excel/spreadsheet file. Extract financial data from tables, rows, and columns.',
    'csv': 'This is a CSV file. Parse the data and extract financial transactions.',
    'text': 'This is a text file. Look for financial information, transactions, or monetary values.',
    'image': 'This appears to be image content (possibly OCR text). Extract any visible financial data.'
  };

  const filePrompt = fileTypePrompts[fileType] || 'Extract any financial data from this file.';

  const analysisInstructions = `
Return your analysis as a JSON object with this structure:
{
  "summary": "Brief summary of the file content",
  "transactions": [
    {
      "date": "YYYY-MM-DD",
      "description": "Transaction description",
      "amount": number,
      "type": "income" or "expense",
      "category": "Category name"
    }
  ],
  "totalIncome": number,
  "totalExpenses": number,
  "confidence": number (0-1)
}

If no financial data is found, return:
{
  "summary": "No financial data found in this file",
  "transactions": [],
  "totalIncome": 0,
  "totalExpenses": 0,
  "confidence": 0
}`;

  return `${basePrompt}\n\n${filePrompt}\n\n${analysisInstructions}`;
}

export async function handleAnalyzeFile(req: Request, res: Response): Promise<void> {
  // Apply security headers
  applySecurityHeaders(res);

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const requestId = req.requestId || 'unknown';
    
    // Validate API keys
    if (!openaiApiKey) {
      logger.error('OpenAI API key not configured', { requestId });
      res.status(500).json({ error: 'OpenAI API key not configured', requestId });
      return;
    }

    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({ error: 'Supabase not configured', requestId });
      return;
    }

    // Parse body if it's a string
    let body = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch (e) {
        res.status(400).json({ error: 'Invalid JSON in request body' });
        return;
      }
    }

    // Sanitize input first
    if (body && typeof body === 'object') {
      if (body.textContent && typeof body.textContent === 'string') {
        body.textContent = sanitizeFileContent(body.textContent);
      }
      if (body.fileName && typeof body.fileName === 'string') {
        body.fileName = sanitizeTitle(body.fileName);
      }
    }

    // Apply rate limiting
    const rateLimitResult = rateLimitMiddleware(req, RATE_LIMITS.FILE_ANALYSIS, 'analyze-file');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', { endpoint: 'analyze-file', requestId });
      res.status(rateLimitResult.response!.status).json({
        ...rateLimitResult.response!.body,
        requestId
      });
      return;
    }

    // Validate input
    const validation = validateAnalyzeFileRequest(body);
    if (!validation.valid) {
      logger.warn('Validation error', { error: validation.error, requestId });
      res.status(400).json({ error: validation.error, requestId });
      return;
    }

    const { textContent, fileName, fileType, userId, options } = validation.data!;

    // Inputs already sanitized above
    const sanitizedTextContent = textContent;
    const sanitizedFileName = fileName;

    // Create analysis prompt based on file type
    const systemPrompt = createAnalysisPrompt(sanitizedFileName, fileType, options);

    // Analyze with OpenAI GPT (with timeout)
    logger.info('Calling GPT for file analysis', { requestId, fileName: sanitizedFileName });
    const gptResponse = await fetchWithTimeout(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: openaiModel,
          messages: [
            {
              role: 'system',
              content: systemPrompt
            },
            {
              role: 'user',
              content: `Please analyze this file content and extract financial data:\n\n${sanitizedTextContent}`
            }
          ],
          max_tokens: 2000,
          temperature: 0.3,
        }),
      },
      TIMEOUTS.FILE_ANALYSIS
    );

    if (!gptResponse.ok) {
      const errorData = await gptResponse.json().catch(() => ({ error: { message: 'Unknown error' } }));
      logger.error('OpenAI API error', { 
        status: gptResponse.status, 
        error: errorData.error?.message,
        requestId 
      });
      throw new Error(`GPT API error: ${errorData.error?.message || 'Unknown error'}`);
    }

    const gptData = await gptResponse.json();
    const analysisResult = gptData.choices[0].message.content;

    // Parse the AI response to extract structured data
    let extractedData;
    try {
      // Try to parse as JSON first
      extractedData = JSON.parse(analysisResult);
    } catch {
      // If not JSON, create a structured response
      extractedData = {
        summary: analysisResult,
        transactions: [],
        confidence: 0.7
      };
    }

    // Save analysis result to database
    const { data: savedData, error: saveError } = await supabase
      .from('anita_data')
      .insert({
        account_id: userId,
        data_type: 'file_analysis',
        file_name: sanitizedFileName,
        file_type: fileType,
        analysis_result: extractedData,
        raw_text: sanitizedTextContent,
        created_at: new Date().toISOString()
      })
      .select()
      .single();

    if (saveError) {
      logger.error('Failed to save analysis result', { error: saveError.message });
      throw new Error(`Failed to save analysis result: ${saveError.message}`);
    }

    logger.info('File analysis successful', { fileName: sanitizedFileName, requestId });
    res.status(200).json({
      success: true,
      data: extractedData,
      analysisId: savedData.id,
      confidence: extractedData.confidence || 0.7,
      requestId
    });

  } catch (error) {
    const requestId = req.requestId || 'unknown';
    const errorMessage = error instanceof Error ? error.message : 'Unknown';
    
    // Check if it's a timeout error
    if (errorMessage.includes('timeout')) {
      logger.error('Request timeout in file analysis', { error: errorMessage, requestId });
      res.status(504).json({
        success: false,
        error: 'Request timeout',
        message: 'The file analysis request took too long. Please try again.',
        requestId
      });
      return;
    }
    
    logger.error('Unexpected error in file analysis', { error: errorMessage, requestId });
    res.status(500).json({
      success: false,
      error: errorMessage,
      requestId
    });
  }
}

