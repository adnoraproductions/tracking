import { eachDayOfInterval, endOfMonth, format, isAfter, startOfDay, startOfMonth } from 'date-fns';
import { supabase } from './supabase/client';

/* ---------------- Data ---------------- */

export async function fetchPlans() {
  const { data, error } = await supabase.from('incentive_plans').select('*').order('sort_order').order('name');
  if (error) throw error;
  return (data || []).map(normalizePlan);
}

/** Map of employee_id → plan_id (RLS: employees get only their own row). */
export async function fetchAssignments() {
  const { data, error } = await supabase.from('employee_incentive_plans').select('employee_id, plan_id');
  if (error) throw error;
  return Object.fromEntries((data || []).map((a) => [a.employee_id, a.plan_id]));
}

/** Hidden per-task bonus beyond the top slab. Admin only — returns {} for everyone else. */
export async function fetchBonuses() {
  const { data, error } = await supabase.from('incentive_plan_bonus').select('*');
  if (error) return {};
  return Object.fromEntries((data || []).map((b) => [b.plan_id, { per_points: Number(b.per_points), amount: Number(b.amount) }]));
}

export function normalizePlan(p) {
  const slabs = (Array.isArray(p.slabs) ? p.slabs : [])
    .map((s) => ({ level: s.level, min_points: Number(s.min_points) || 0, incentive: Number(s.incentive) || 0 }))
    .sort((a, b) => a.min_points - b.min_points);
  return { ...p, slabs, unit_points: Number(p.unit_points) || 10, daily_points: p.daily_points ? Number(p.daily_points) : null };
}

/* ---------------- Levels & payouts ---------------- */

/**
 * Where a person stands on their plan for a month.
 * level: 0 = below the first slab, 1..n = slab reached. `next` is the next slab to unlock.
 */
export function levelFor(points, plan) {
  if (!plan || !plan.slabs.length) return { hasPlan: false, level: 0, name: 'No plan yet', incentive: 0, next: null, current: null, inBonus: false };
  const slabs = plan.slabs;
  let idx = -1;
  slabs.forEach((s, i) => {
    if (points >= s.min_points) idx = i;
  });
  const current = idx >= 0 ? slabs[idx] : null;
  const next = slabs[idx + 1] || null;
  return {
    hasPlan: true,
    level: idx + 1,
    name: current ? current.level : `Below ${slabs[0].level}`,
    incentive: current?.incentive || 0,
    current,
    next,
    top: slabs[slabs.length - 1],
    inBonus: idx === slabs.length - 1,
  };
}

/** Full incentive for payroll: slab amount + hidden per-task bonus beyond the top slab. */
export function incentivePayout(points, plan, bonus) {
  const lv = levelFor(points, plan);
  if (!lv.hasPlan) return { slab: 0, bonus: 0, total: 0, bonusUnits: 0, level: lv };
  let bonusUnits = 0;
  let bonusAmount = 0;
  if (lv.inBonus && bonus && bonus.per_points > 0 && bonus.amount > 0) {
    bonusUnits = Math.floor((points - lv.top.min_points) / bonus.per_points);
    bonusAmount = bonusUnits * bonus.amount;
  }
  return { slab: lv.incentive, bonus: bonusAmount, total: lv.incentive + bonusAmount, bonusUnits, level: lv };
}

/* ---------------- Calendar & pace ---------------- */

export function workingDaysInfo(month, perWeek = 6, holidays = new Set()) {
  const start = startOfMonth(month);
  const end = endOfMonth(month);
  const today = startOfDay(new Date());
  const isWorking = (d) => {
    const dow = d.getDay();
    if (perWeek === 6 && dow === 0) return false;
    if (perWeek === 5 && (dow === 0 || dow === 6)) return false;
    return !holidays.has(format(d, 'yyyy-MM-dd'));
  };
  const all = eachDayOfInterval({ start, end }).filter(isWorking);
  const isCurrent = format(month, 'yyyy-MM') === format(today, 'yyyy-MM');
  const isPast = isAfter(today, end);
  const elapsed = isPast ? all.length : isCurrent ? all.filter((d) => !isAfter(d, today)).length : 0;
  const remaining = isPast ? 0 : isCurrent ? all.filter((d) => !isAfter(today, d)).length : all.length; // includes today
  return { total: all.length, elapsed, remaining, isCurrent, isPast, todayIsWorking: isCurrent && isWorking(today) };
}

/** Month-end forecast at the current pace. */
export function projectPoints(points, days) {
  if (days.isPast || !days.elapsed) return points;
  return Math.round((points / days.elapsed) * days.total);
}

export const unitsFor = (points, plan) => Math.max(0, Math.ceil(points / (plan?.unit_points || 10)));

/** Points logged today (approved + waiting for approval). */
export function taskPointsToday(tasks, catMap) {
  const today = format(new Date(), 'yyyy-MM-dd');
  return tasks
    .filter((t) => t.task_date === today && (t.status === 'approved' || t.status === 'pending'))
    .reduce((s, t) => s + (t.status === 'approved' ? Number(t.points_awarded) || 0 : (catMap[t.category_id]?.points || 0) * (t.quantity || 1)), 0);
}
