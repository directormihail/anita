/**
 * Get XP Stats API Route
 * Fetches user XP statistics from Supabase
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

export async function handleGetXPStats(req: Request, res: Response): Promise<void> {
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

    // Always use user_xp_events as source of truth: compute stats, then persist to user_xp_stats
    const { data: events, error: eventsError } = await supabase
      .from('user_xp_events')
      .select('xp_amount')
      .eq('user_id', userId);

    if (eventsError) {
      logger.error('Error fetching XP events', { error: eventsError.message, requestId, userId });
      res.status(500).json({
        error: 'Database error',
        message: 'Failed to fetch XP events',
        requestId
      });
      return;
    }

    // Calculate total XP
    const totalXP = (events || []).reduce((sum, event) => sum + (event.xp_amount || 0), 0);

    // Find current level based on total XP
    const { data: levels } = await supabase
      .from('xp_levels')
      .select('*')
      .order('level', { ascending: false });

    let currentLevel = 1;
    let xpToNextLevel = 100;
    let levelTitle = 'Newcomer';
    let levelDescription = 'Just getting started';
    let levelEmoji = '🌱';

    if (levels && levels.length > 0) {
      for (const level of levels) {
        if (totalXP >= level.total_xp_needed) {
          currentLevel = level.level;
          levelTitle = level.title;
          levelDescription = level.description;
          levelEmoji = level.emoji;
          
          // Find next level
          const nextLevel = levels.find(l => l.level === currentLevel + 1);
          if (nextLevel) {
            xpToNextLevel = nextLevel.total_xp_needed - totalXP;
          } else {
            xpToNextLevel = 0; // Max level
          }
          break;
        }
      }
    }

    const currentLevelData = levels?.find(l => l.level === currentLevel);
    const nextLevelData = levels?.find(l => l.level === currentLevel + 1);
    const currentThreshold = currentLevelData?.total_xp_needed ?? 0;
    const nextThreshold = nextLevelData?.total_xp_needed ?? currentThreshold + 1;
    const range = nextThreshold - currentThreshold;
    const levelProgressPercentage = xpToNextLevel > 0 && range > 0
      ? Math.round(((totalXP - currentThreshold) / range) * 100)
      : xpToNextLevel === 0 ? 100 : 0;
    const clampedLevelProgress = Math.max(0, Math.min(100, levelProgressPercentage));

    // Persist computed stats to Supabase so they are always saved (source of truth is events)
    const { error: upsertError } = await supabase
      .from('user_xp_stats')
      .upsert(
        {
          user_id: userId,
          total_xp: totalXP,
          current_level: currentLevel,
          xp_to_next_level: xpToNextLevel,
          level_progress_percentage: clampedLevelProgress,
          last_updated: new Date().toISOString()
        },
        { onConflict: 'user_id' }
      );

    if (upsertError) {
      logger.error('Error upserting XP stats to Supabase', { error: upsertError.message, requestId, userId });
      // Still return the computed stats; persistence will be retried on next fetch
    }

    res.status(200).json({
      success: true,
      xpStats: {
        total_xp: totalXP,
        current_level: currentLevel,
        xp_to_next_level: xpToNextLevel,
        level_progress_percentage: clampedLevelProgress,
        level_title: levelTitle,
        level_description: levelDescription,
        level_emoji: levelEmoji
      },
      requestId
    });
  } catch (error) {
    const requestId = req.requestId || 'unknown';
    logger.error('Unexpected error in get-xp-stats', { 
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

