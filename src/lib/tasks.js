import { supabase } from './supabase/client';

export async function fetchCategories({ activeOnly = true } = {}) {
  let q = supabase.from('task_categories').select('*').order('sort_order').order('name');
  if (activeOnly) q = q.eq('is_active', true);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

/** Points a task is worth (approved tasks use the stored, locked-in value). */
export function taskPoints(task, catMap) {
  if (task.status === 'approved') return Number(task.points_awarded) || 0;
  const cat = catMap[task.category_id];
  return (cat?.points || 0) * (task.quantity || 1);
}

/** Summarise a list of tasks: approved points, pending points, count per category. */
export function summarize(tasks, catMap) {
  const out = { points: 0, pendingPoints: 0, approvedCount: 0, pendingCount: 0, draftCount: 0, byCategory: {} };
  for (const t of tasks) {
    const c = (out.byCategory[t.category_id] ||= { approved: 0, pending: 0 });
    if (t.status === 'approved') {
      out.points += Number(t.points_awarded) || 0;
      out.approvedCount += 1;
      c.approved += t.quantity || 1;
    } else if (t.status === 'pending') {
      out.pendingPoints += taskPoints(t, catMap);
      out.pendingCount += 1;
      c.pending += t.quantity || 1;
    } else if (t.status === 'draft') {
      out.draftCount += 1;
    }
  }
  return out;
}
