import React, { useEffect, useMemo, useState } from 'react';
import { startOfMonth } from 'date-fns';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase/client';
import { useHrSettings } from '../lib/hr';
import { fetchCategories, summarize } from '../lib/tasks';
import { fetchPlans, fetchAssignments, workingDaysInfo, taskPointsToday } from '../lib/incentives';
import { monthRange } from '../lib/format';
import IncentiveTracker from './IncentiveTracker';

/** Compact incentive tracker for the employee home screen. Loads its own data. */
export default function MyIncentiveWidget() {
  const { profile } = useAuth();
  const { settings } = useHrSettings();
  const [state, setState] = useState(null);

  useEffect(() => {
    if (!profile) return;
    let alive = true;
    (async () => {
      try {
        const month = startOfMonth(new Date());
        const { startStr, endStr } = monthRange(month);
        const [cats, t, plans, assigned] = await Promise.all([
          fetchCategories({ activeOnly: false }),
          supabase.from('daily_tasks').select('*').eq('employee_id', profile.id).gte('task_date', startStr).lte('task_date', endStr),
          fetchPlans(),
          fetchAssignments(),
        ]);
        if (!alive || t.error) return;
        setState({ cats, tasks: t.data || [], plan: plans.find((p) => p.id === assigned[profile.id]) || null });
      } catch {
        /* module not set up yet — show nothing */
      }
    })();
    return () => {
      alive = false;
    };
  }, [profile]);

  const catMap = useMemo(() => Object.fromEntries((state?.cats || []).map((c) => [c.id, c])), [state]);
  if (!state || !state.plan) return null;
  const sum = summarize(state.tasks, catMap);
  return (
    <IncentiveTracker
      compact
      plan={state.plan}
      points={sum.points}
      pending={sum.pendingPoints}
      today={taskPointsToday(state.tasks, catMap)}
      days={workingDaysInfo(startOfMonth(new Date()), Number(settings.working_days_per_week) || 6)}
      currency={settings.currency}
    />
  );
}
