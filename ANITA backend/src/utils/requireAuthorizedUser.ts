import { Request, Response } from 'express';
import { createClient } from '@supabase/supabase-js';

function getSupabaseAuthClient() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
  if (supabaseUrl && supabaseAnonKey) {
    return createClient(supabaseUrl, supabaseAnonKey, { auth: { persistSession: false } });
  }
  return null;
}

export async function requireAuthorizedUserId(
  req: Request,
  res: Response,
  requestedUserId: string,
  requestId: string
): Promise<boolean> {
  const authHeader = req.headers.authorization;
  const value = Array.isArray(authHeader) ? authHeader[0] : authHeader;
  const token = typeof value === 'string' && value.startsWith('Bearer ') ? value.slice(7).trim() : '';

  if (!token) {
    res.status(401).json({ error: 'Missing Authorization token', requestId });
    return false;
  }

  const supabase = getSupabaseAuthClient();
  if (!supabase) {
    res.status(500).json({ error: 'Auth not configured', requestId });
    return false;
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user?.id) {
    res.status(401).json({ error: 'Invalid or expired token', requestId });
    return false;
  }

  if (data.user.id !== requestedUserId) {
    res.status(403).json({ error: 'Forbidden user access', requestId });
    return false;
  }

  return true;
}
