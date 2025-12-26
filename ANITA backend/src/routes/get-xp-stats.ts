/**
 * Get XP Stats API Route
 * Fetches user XP statistics from Supabase
 */

import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';
import { applySecurityHeaders } from '../utils/securityHeaders';
import * as logger from '../utils/logger';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  logger.error('Supabase configuration missing');
}

const supabase = supabaseUrl && supabaseServiceKey 
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

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

    if (!supabase) {
      logger.error('Supabase not configured', { requestId });
      res.status(500).json({
        error: 'Database not configured',
        message: 'Supabase is not properly configured',
        requestId
      });
      return;
    }

    // Try to get cached stats first
    const { data: statsData, error: statsError } = await supabase
      .from('user_xp_stats')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (statsError && statsError.code !== 'PGRST116') { // PGRST116 = not found
      logger.error('Error fetching XP stats', { error: statsError.message, requestId, userId });
    }

    // If we have cached stats, get level details
    if (statsData) {
      const { data: levelData } = await supabase
        .from('xp_levels')
        .select('*')
        .eq('level', statsData.current_level)
        .single();

      res.status(200).json({
        success: true,
        xpStats: {
          total_xp: statsData.total_xp || 0,
          current_level: statsData.current_level || 1,
          xp_to_next_level: statsData.xp_to_next_level || 100,
          level_progress_percentage: statsData.level_progress_percentage || 0,
          level_title: levelData?.title || 'Newcomer',
          level_description: levelData?.description || 'Just getting started',
          level_emoji: levelData?.emoji || '🌱'
        },
        requestId
      });
      return;
    }

    // If no cached stats, calculate from events
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

    const levelProgressPercentage = xpToNextLevel > 0 && levels && levels.length > 0
      ? Math.round(((totalXP - (levels.find(l => l.level === currentLevel)?.total_xp_needed || 0)) / 
                    (levels.find(l => l.level === currentLevel + 1)?.total_xp_needed || totalXP + 1) - 
                    (levels.find(l => l.level === currentLevel)?.total_xp_needed || 0)) * 100)
      : 0;

    res.status(200).json({
      success: true,
      xpStats: {
        total_xp: totalXP,
        current_level: currentLevel,
        xp_to_next_level: xpToNextLevel,
        level_progress_percentage: levelProgressPercentage,
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

