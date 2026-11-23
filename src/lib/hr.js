import { useEffect, useState } from 'react';
import { supabase } from './supabase/client';

export const DEFAULT_HR_SETTINGS = {
  paid_casual_per_month: 1,
  paid_emergency_per_month: 1,
  casual_notice_days: 1,
  tier1_name: 'Rising',
  tier2_name: 'Achiever',
  tier3_name: 'Champion',
  tier2_min_points: 100,
  tier3_min_points: 200,
  incentive_amount: 0,
  working_days_per_week: 6,
  currency: 'INR',
};

let cache = null;

export async function loadHrSettings(force = false) {
  if (cache && !force) return cache;
  const { data, error } = await supabase.from('hr_settings').select('*').eq('id', 1).maybeSingle();
  if (error) throw error;
  cache = { ...DEFAULT_HR_SETTINGS, ...(data || {}) };
  return cache;
}

export function useHrSettings() {
  const [settings, setSettings] = useState(cache || DEFAULT_HR_SETTINGS);
  const [error, setError] = useState(null);
  useEffect(() => {
    let alive = true;
    loadHrSettings()
      .then((s) => alive && setSettings(s))
      .catch((e) => alive && setError(e));
    return () => {
      alive = false;
    };
  }, []);
  const refresh = async () => setSettings(await loadHrSettings(true));
  return { settings, error, refresh };
}

/** Performance tier for a month's approved points. Level 3 earns the incentive. */
export function tierFor(points, s = DEFAULT_HR_SETTINGS) {
  if (points >= s.tier3_min_points) return { level: 3, name: s.tier3_name, next: null };
  if (points >= s.tier2_min_points) return { level: 2, name: s.tier2_name, next: s.tier3_min_points };
  return { level: 1, name: s.tier1_name, next: s.tier2_min_points };
}

export const LEAVE_TYPES = {
  casual: { label: 'Casual', tone: 'blue' },
  emergency: { label: 'Emergency', tone: 'amber' },
  unpaid: { label: 'Unpaid', tone: 'gray' },
};

export const STATUS_TONE = {
  draft: 'gray',
  pending: 'amber',
  approved: 'green',
  rejected: 'red',
  cancelled: 'gray',
  paid: 'green',
};

/** Friendly message when the v2 tables are not created yet. */
export function friendlyError(err) {
  const msg = err?.message || String(err || 'Something went wrong');
  if (/relation .* does not exist|Could not find the table|schema cache/i.test(msg)) {
    return 'This module is not set up in the database yet. Run migrations/001_tasks_leaves_finance.sql in the Supabase SQL editor.';
  }
  return msg;
}

/** Turn a DB error raised by our triggers into a clean sentence. */
export function cleanDbMessage(err) {
  return friendlyError(err).replace(/^.*?EXCEPTION:\s*/i, '');
}
