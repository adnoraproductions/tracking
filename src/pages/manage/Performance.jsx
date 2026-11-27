import React, { useEffect, useMemo, useState } from 'react';
import { startOfMonth, format } from 'date-fns';
import { Trophy, Target, Settings2, Gift, Users, Sparkles, Layers, Plus, Trash2, EyeOff, AlertTriangle } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useHrSettings, cleanDbMessage, friendlyError, loadHrSettings } from '../../lib/hr';
import { fetchCategories, summarize } from '../../lib/tasks';
import { fetchPlans, fetchAssignments, fetchBonuses, incentivePayout, workingDaysInfo, projectPoints } from '../../lib/incentives';
import { monthRange, money } from '../../lib/format';
import {
  PageHeader, Card, Stat, Button, Badge, TierBadge, Field, Segmented, EmptyState, Alert, Loading, Modal, MonthPicker, Avatar, useToast,
} from '../../components/ui';

export default function Performance() {
  const { isAdmin } = useAuth();
  const { settings, refresh } = useHrSettings();
  const toast = useToast();
  const [tab, setTab] = useState('board');
  const [month, setMonth] = useState(startOfMonth(new Date()));
  const [people, setPeople] = useState([]);
  const [categories, setCategories] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [kpis, setKpis] = useState([]);
  const [plans, setPlans] = useState([]);
  const [assigned, setAssigned] = useState({});
  const [bonuses, setBonuses] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [kpiFor, setKpiFor] = useState(null);

  const catMap = useMemo(() => Object.fromEntries(categories.map((c) => [c.id, c])), [categories]);
  const planMap = useMemo(() => Object.fromEntries(plans.map((p) => [p.id, p])), [plans]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const { startStr, endStr } = monthRange(month);
      const [p, cats, t, k, pl, asg, bon] = await Promise.all([
        supabase.from('profiles').select('id, full_name, employee_code, designation, role, status').order('full_name'),
        fetchCategories({ activeOnly: false }),
        supabase.from('daily_tasks').select('employee_id, category_id, quantity, status, points_awarded').gte('task_date', startStr).lte('task_date', endStr),
        supabase.from('employee_kpis').select('*'),
        fetchPlans(),
        fetchAssignments(),
        isAdmin ? fetchBonuses() : Promise.resolve({}),
      ]);
      for (const r of [p, t, k]) if (r.error) throw r.error;
      setPeople(p.data || []);
      setCategories(cats);
      setTasks(t.data || []);
      setKpis(k.data || []);
      setPlans(pl);
      setAssigned(asg);
      setBonuses(bon);
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [month]);

  const days = workingDaysInfo(month, Number(settings.working_days_per_week) || 6);

  const rows = useMemo(() => {
    const withTasks = new Set(tasks.map((t) => t.employee_id));
    return people
      .filter((p) => p.role !== 'admin' && (p.status !== 'inactive' || withTasks.has(p.id)))
      .map((p) => {
        const mine = tasks.filter((t) => t.employee_id === p.id);
        const sum = summarize(mine, catMap);
        const plan = planMap[assigned[p.id]] || null;
        const pay = incentivePayout(sum.points, plan, plan ? bonuses[plan.id] : null);
        const myKpis = kpis.filter((k) => k.employee_id === p.id && k.monthly_target > 0 && catMap[k.category_id]);
        const kpiMet = myKpis.filter((k) => (sum.byCategory[k.category_id]?.approved || 0) >= k.monthly_target).length;
        return { ...p, sum, plan, pay, lv: pay.level, kpiTotal: myKpis.length, kpiMet, projected: projectPoints(sum.points + sum.pendingPoints, days) };
      })
      .sort((a, b) => b.lv.level - a.lv.level || b.sum.points - a.sum.points);
  }, [people, tasks, kpis, catMap, planMap, assigned, bonuses]);

  const onPlan = rows.filter((r) => r.lv.hasPlan);
  const atTop = onPlan.filter((r) => r.lv.inBonus).length;
  const earning = onPlan.filter((r) => r.pay.total > 0).length;
  const belowTarget = onPlan.filter((r) => r.lv.level === 0).length;
  const payout = rows.reduce((s, r) => s + r.pay.total, 0);
  const teamPoints = rows.reduce((s, r) => s + r.sum.points, 0);

  return (
    <div className="stack">
      <PageHeader
        title="Performance"
        subtitle="Approved task points decide each person's level on their role's incentive plan."
        actions={<MonthPicker value={month} onChange={setMonth} />}
      />

      <Segmented
        value={tab}
        onChange={setTab}
        options={[
          { value: 'board', label: 'Leaderboard', icon: Trophy },
          { value: 'plans', label: 'Incentive plans', icon: Layers },
          { value: 'kpi', label: 'KPI targets', icon: Target },
          ...(isAdmin ? [{ value: 'settings', label: 'Points & rules', icon: Settings2 }] : []),
        ]}
      />

      {error && <Alert>{error}</Alert>}

      {loading ? (
        <Loading />
      ) : tab === 'board' ? (
        <>
          <div className="grid-stats">
            <Stat label="Team points" value={teamPoints} sub={format(month, 'MMMM yyyy')} icon={Sparkles} tone="green" />
            <Stat label="Earning incentive" value={earning} sub={`${atTop} at the top level`} icon={Trophy} tone="amber" />
            <Stat label="Below P1 target" value={belowTarget} sub="Need a push this month" icon={AlertTriangle} tone="red" />
            {isAdmin ? (
              <Stat label="Incentive payout" value={money(payout, settings.currency)} sub="Including bonus beyond top level" icon={Gift} tone="blue" />
            ) : (
              <Stat label="On a plan" value={`${onPlan.length}/${rows.length}`} sub="Employees with slabs" icon={Users} tone="blue" />
            )}
          </div>

          <Card title="Leaderboard" pad={false}>
            {rows.length === 0 ? (
              <EmptyState icon={Trophy} title="No employees yet" />
            ) : (
              <div className="table-wrap">
                <table className="table responsive">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>Employee</th>
                      <th>Level</th>
                      <th className="num">Points</th>
                      <th style={{ minWidth: 180 }}>Next level</th>
                      <th className="num">Forecast</th>
                      {isAdmin && <th className="num">Incentive</th>}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r, i) => {
                      const next = r.lv.next;
                      const from = r.lv.current?.min_points || 0;
                      const progress = next ? Math.max(0, Math.min(100, ((r.sum.points - from) / (next.min_points - from)) * 100)) : 100;
                      return (
                        <tr key={r.id}>
                          <td data-label="Rank" className="muted strong">{i + 1}</td>
                          <td data-label="">
                            <div className="row">
                              <Avatar name={r.full_name} size="sm" />
                              <div style={{ textAlign: 'left' }}>
                                <div className="strong">{r.full_name}</div>
                                <div className="xs muted">{r.plan ? r.plan.name : 'No plan assigned'}</div>
                              </div>
                            </div>
                          </td>
                          <td data-label="Level">{r.lv.hasPlan ? <TierBadge tier={{ level: r.lv.level, name: r.lv.name }} /> : <span className="xs muted">—</span>}</td>
                          <td data-label="Points" className="num">
                            <span className="strong">{r.sum.points}</span>
                            {r.sum.pendingPoints > 0 && <div className="xs muted">+{r.sum.pendingPoints} pending</div>}
                          </td>
                          <td data-label="Next level">
                            {!r.lv.hasPlan ? (
                              <span className="xs muted">—</span>
                            ) : next ? (
                              <div style={{ minWidth: 140 }}>
                                <div className="progress" style={{ height: 6 }}>
                                  <span style={{ width: `${progress}%`, background: 'var(--brand-lime)' }} />
                                </div>
                                <div className="xs muted" style={{ marginTop: 4 }}>
                                  {next.min_points - r.sum.points} pts to {next.level}
                                  {next.incentive > 0 ? ` · ${money(next.incentive, settings.currency)}` : ''}
                                </div>
                              </div>
                            ) : (
                              <Badge tone="gold">Bonus zone</Badge>
                            )}
                          </td>
                          <td data-label="Forecast" className="num muted">{r.lv.hasPlan && !days.isPast ? `~${r.projected}` : '—'}</td>
                          {isAdmin && (
                            <td data-label="Incentive" className="num">
                              {r.pay.total > 0 ? (
                                <>
                                  <span className="strong">{money(r.pay.total, settings.currency)}</span>
                                  {r.pay.bonus > 0 && <div className="xs muted">incl. {money(r.pay.bonus, settings.currency)} bonus</div>}
                                </>
                              ) : (
                                <span className="muted">—</span>
                              )}
                            </td>
                          )}
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </>
      ) : tab === 'plans' ? (
        <PlansTab
          isAdmin={isAdmin}
          plans={plans}
          bonuses={bonuses}
          people={rows}
          assigned={assigned}
          currency={settings.currency}
          onSaved={(msg) => {
            toast(msg);
            load();
          }}
          onError={(msg) => toast(msg, 'error')}
        />
      ) : tab === 'kpi' ? (
        <Card title="Monthly KPI targets" subtitle="Optional minimum number of tasks per category, every month." pad={false}>
          <div className="list">
            {rows.map((r) => {
              const mine = kpis.filter((k) => k.employee_id === r.id && k.monthly_target > 0 && catMap[k.category_id]);
              return (
                <div className="list-row" key={r.id}>
                  <Avatar name={r.full_name} />
                  <div className="list-main">
                    <div className="list-title">{r.full_name}</div>
                    <div className="list-sub">
                      {mine.length === 0
                        ? 'No targets set'
                        : mine.map((k) => {
                            const done = r.sum.byCategory[k.category_id]?.approved || 0;
                            return (
                              <span key={k.id} style={{ marginRight: 10, whiteSpace: 'nowrap', color: done >= k.monthly_target ? 'var(--brand-600)' : undefined }}>
                                {catMap[k.category_id].name} {done}/{k.monthly_target}
                              </span>
                            );
                          })}
                    </div>
                  </div>
                  <div className="list-end">
                    <Button size="sm" icon={Target} onClick={() => setKpiFor(r)}>Set targets</Button>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      ) : (
        <RulesSettings
          categories={categories}
          settings={settings}
          onSaved={async (msg) => {
            await loadHrSettings(true);
            await refresh();
            toast(msg);
            load();
          }}
        />
      )}

      <KpiModal
        person={kpiFor}
        categories={categories.filter((c) => c.is_active)}
        kpis={kpis}
        onClose={() => setKpiFor(null)}
        onSaved={() => {
          setKpiFor(null);
          toast('KPI targets saved');
          load();
        }}
      />
    </div>
  );
}

/* ---------------- Incentive plans ---------------- */

function PlansTab({ isAdmin, plans, bonuses, people, assigned, currency, onSaved, onError }) {
  const [editing, setEditing] = useState(null);

  const assign = async (employeeId, planId) => {
    const { error } = planId
      ? await supabase.from('employee_incentive_plans').upsert({ employee_id: employeeId, plan_id: planId }, { onConflict: 'employee_id' })
      : await supabase.from('employee_incentive_plans').delete().eq('employee_id', employeeId);
    if (error) return onError(cleanDbMessage(error));
    onSaved('Plan updated');
  };

  if (!plans.length) {
    return (
      <Card>
        <EmptyState icon={Layers} title="Incentive plans are not set up" text="Run migrations/005_incentive_plans.sql in the Supabase SQL editor." />
      </Card>
    );
  }

  return (
    <div className="stack">
      <div className="plan-grid">
        {plans.map((p) => {
          const b = bonuses[p.id];
          const count = people.filter((r) => assigned[r.id] === p.id).length;
          return (
            <Card
              key={p.id}
              title={p.name}
              subtitle={`${count} employee${count === 1 ? '' : 's'}${p.daily_points ? ` · daily KPI ${p.daily_points} pts` : ''}`}
              actions={isAdmin && <Button size="sm" onClick={() => setEditing(p)}>Edit</Button>}
            >
              {p.slabs.length === 0 ? (
                <div className="small muted">Slabs not decided yet. Employees on this plan still log tasks and earn points.</div>
              ) : (
                <div className="slab-list">
                  {p.slabs.map((sl) => (
                    <div className="slab" key={sl.level}>
                      <span className="slab-level">{sl.level}</span>
                      <span className="slab-pts">{sl.min_points}+ pts</span>
                      <span className="slab-amt">{sl.incentive > 0 ? money(sl.incentive, currency) : 'Target'}</span>
                    </div>
                  ))}
                  {isAdmin && b && b.amount > 0 && (
                    <div className="slab bonus">
                      <span className="slab-level"><EyeOff size={13} /></span>
                      <span className="slab-pts">After {p.slabs[p.slabs.length - 1].level}</span>
                      <span className="slab-amt">+{money(b.amount, currency)} / {b.per_points} pts</span>
                    </div>
                  )}
                </div>
              )}
              {isAdmin && b && b.amount > 0 && <div className="xs muted" style={{ marginTop: 8 }}>Bonus rate is hidden from employees.</div>}
            </Card>
          );
        })}
      </div>

      <Card title="Who is on which plan" subtitle="Each person's targets and incentives follow their plan." pad={false}>
        <div className="list">
          {people.map((r) => (
            <div className="list-row" key={r.id}>
              <Avatar name={r.full_name} />
              <div className="list-main">
                <div className="list-title">{r.full_name}</div>
                <div className="list-sub">{r.designation || r.employee_code || ''}</div>
              </div>
              <div className="list-end">
                <select className="select" style={{ width: 220, height: 38 }} value={assigned[r.id] || ''} onChange={(e) => assign(r.id, e.target.value)}>
                  <option value="">— No plan —</option>
                  {plans.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
              </div>
            </div>
          ))}
        </div>
      </Card>

      <PlanModal plan={editing} bonus={editing ? bonuses[editing.id] : null} currency={currency} onClose={() => setEditing(null)} onSaved={(m) => { setEditing(null); onSaved(m); }} />
    </div>
  );
}

function PlanModal({ plan, bonus, currency, onClose, onSaved }) {
  const [f, setF] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!plan) return;
    setError(null);
    setF({
      name: plan.name,
      unit_label: plan.unit_label,
      unit_points: plan.unit_points,
      daily_points: plan.daily_points ?? '',
      slabs: plan.slabs.map((s) => ({ ...s })),
      bonus_amount: bonus?.amount ?? '',
      bonus_per: bonus?.per_points ?? 10,
    });
  }, [plan]);

  if (!plan || !f) return null;
  const set = (p) => setF((x) => ({ ...x, ...p }));
  const setSlab = (i, p) => set({ slabs: f.slabs.map((s, j) => (j === i ? { ...s, ...p } : s)) });

  const save = async () => {
    setError(null);
    const slabs = f.slabs
      .map((s) => ({ level: String(s.level || '').trim(), min_points: Number(s.min_points) || 0, incentive: Number(s.incentive) || 0 }))
      .filter((s) => s.level);
    for (let i = 1; i < slabs.length; i++) {
      if (slabs[i].min_points <= slabs[i - 1].min_points) return setError('Each level needs more points than the one before it.');
    }
    setSaving(true);
    try {
      const { error: e1 } = await supabase
        .from('incentive_plans')
        .update({
          name: f.name.trim() || plan.name,
          unit_label: f.unit_label.trim() || 'tasks',
          unit_points: Number(f.unit_points) || 10,
          daily_points: f.daily_points === '' ? null : Number(f.daily_points) || null,
          slabs,
        })
        .eq('id', plan.id);
      if (e1) throw e1;
      const amount = Number(f.bonus_amount) || 0;
      const { error: e2 } = amount > 0
        ? await supabase.from('incentive_plan_bonus').upsert({ plan_id: plan.id, amount, per_points: Number(f.bonus_per) || 10 }, { onConflict: 'plan_id' })
        : await supabase.from('incentive_plan_bonus').delete().eq('plan_id', plan.id);
      if (e2) throw e2;
      onSaved('Plan saved');
    } catch (e) {
      setError(cleanDbMessage(e));
    } finally {
      setSaving(false);
    }
  };

  const top = f.slabs[f.slabs.length - 1];

  return (
    <Modal
      open
      wide
      onClose={onClose}
      title={`Edit plan — ${plan.name}`}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save plan</Button>
        </>
      }
    >
      <div className="stack">
        <div className="form-grid">
          <Field label="Plan name"><input className="input" value={f.name} onChange={(e) => set({ name: e.target.value })} /></Field>
          <Field label="Daily KPI (points)" hint="Leave empty if there is no daily target">
            <input className="input" type="number" min={0} value={f.daily_points} onChange={(e) => set({ daily_points: e.target.value })} />
          </Field>
          <Field label="Task word shown to employees" hint='e.g. "posters" → "6 more posters"'>
            <input className="input" value={f.unit_label} onChange={(e) => set({ unit_label: e.target.value })} />
          </Field>
          <Field label="Points per task"><input className="input" type="number" min={1} value={f.unit_points} onChange={(e) => set({ unit_points: e.target.value })} /></Field>
        </div>

        <div>
          <div className="field-label" style={{ marginBottom: 8 }}>Levels (monthly points)</div>
          <div className="stack-sm">
            {f.slabs.map((sl, i) => (
              <div className="slab-edit" key={i}>
                <input className="input" value={sl.level} onChange={(e) => setSlab(i, { level: e.target.value })} placeholder="P1" />
                <input className="input" type="number" min={0} value={sl.min_points} onChange={(e) => setSlab(i, { min_points: e.target.value })} placeholder="Points" />
                <input className="input" type="number" min={0} value={sl.incentive} onChange={(e) => setSlab(i, { incentive: e.target.value })} placeholder={`Incentive (${currency})`} />
                <button type="button" className="icon-btn" onClick={() => set({ slabs: f.slabs.filter((_, j) => j !== i) })} aria-label="Remove level"><Trash2 size={15} /></button>
              </div>
            ))}
            <div className="row">
              <Button size="sm" icon={Plus} onClick={() => set({ slabs: [...f.slabs, { level: `P${f.slabs.length + 1}`, min_points: '', incentive: 0 }] })}>Add level</Button>
              <span className="xs muted">Columns: level name · points needed · incentive amount (0 = target only)</span>
            </div>
          </div>
        </div>

        <div className="card card-pad" style={{ background: 'var(--surface-2)', boxShadow: 'none' }}>
          <div className="row" style={{ marginBottom: 10 }}>
            <EyeOff size={16} />
            <span className="strong small">Bonus after {top?.level || 'the top level'} — hidden from employees</span>
          </div>
          <div className="row wrap small">
            <span>Pay</span>
            <input className="input" style={{ width: 110 }} type="number" min={0} value={f.bonus_amount} onChange={(e) => set({ bonus_amount: e.target.value })} placeholder="0" />
            <span>for every</span>
            <input className="input" style={{ width: 80 }} type="number" min={1} value={f.bonus_per} onChange={(e) => set({ bonus_per: e.target.value })} />
            <span>points above {top ? `${top.min_points}` : 'the top level'}</span>
          </div>
          <div className="xs muted" style={{ marginTop: 8 }}>Employees only see “bonus zone”, never this amount. Leave 0 for no bonus.</div>
        </div>

        {error && <Alert>{error}</Alert>}
      </div>
    </Modal>
  );
}

function KpiModal({ person, categories, kpis, onClose, onSaved }) {
  const [values, setValues] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!person) return;
    setError(null);
    setValues(Object.fromEntries(categories.map((c) => [c.id, kpis.find((k) => k.employee_id === person.id && k.category_id === c.id)?.monthly_target ?? 0])));
  }, [person]);

  const save = async () => {
    setSaving(true);
    const rows = Object.entries(values).map(([category_id, v]) => ({
      employee_id: person.id,
      category_id,
      monthly_target: Math.max(0, parseInt(v, 10) || 0),
    }));
    const { error: err } = await supabase.from('employee_kpis').upsert(rows, { onConflict: 'employee_id,category_id' });
    setSaving(false);
    if (err) return setError(cleanDbMessage(err));
    onSaved();
  };

  return (
    <Modal
      open={!!person}
      onClose={onClose}
      title={`KPI targets — ${person?.full_name || ''}`}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save targets</Button>
        </>
      }
    >
      <div className="stack-sm">
        <p className="small muted" style={{ margin: '0 0 4px' }}>Minimum tasks per month. Leave 0 for no target.</p>
        {categories.map((c) => (
          <div className="row-between" key={c.id}>
            <span className="small strong">{c.name}</span>
            <input
              className="input"
              style={{ width: 96, textAlign: 'right' }}
              type="number"
              min={0}
              inputMode="numeric"
              value={values[c.id] ?? 0}
              onChange={(e) => setValues((v) => ({ ...v, [c.id]: e.target.value }))}
            />
          </div>
        ))}
        {error && <Alert>{error}</Alert>}
      </div>
    </Modal>
  );
}

function RulesSettings({ categories, settings, onSaved }) {
  const [cats, setCats] = useState(categories);
  const [s, setS] = useState(settings);
  const [newCat, setNewCat] = useState({ name: '', points: 10, is_minor: false });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => setCats(categories), [categories]);
  useEffect(() => setS(settings), [settings]);

  const setCat = (id, patch) => setCats((list) => list.map((c) => (c.id === id ? { ...c, ...patch } : c)));
  const num = (v) => Number(v) || 0;

  const save = async () => {
    setError(null);
    setSaving(true);
    try {
      const { error: e1 } = await supabase
        .from('hr_settings')
        .update({
          paid_casual_per_month: num(s.paid_casual_per_month),
          paid_emergency_per_month: num(s.paid_emergency_per_month),
          casual_notice_days: num(s.casual_notice_days),
          working_days_per_week: num(s.working_days_per_week),
          updated_at: new Date().toISOString(),
        })
        .eq('id', 1);
      if (e1) throw e1;
      for (const c of cats) {
        const orig = categories.find((o) => o.id === c.id);
        if (orig && (orig.name !== c.name || orig.points !== num(c.points) || orig.is_minor !== c.is_minor || orig.is_active !== c.is_active)) {
          const { error: e2 } = await supabase
            .from('task_categories')
            .update({ name: c.name.trim(), points: num(c.points), is_minor: c.is_minor, is_active: c.is_active })
            .eq('id', c.id);
          if (e2) throw e2;
        }
      }
      if (newCat.name.trim()) {
        const { error: e3 } = await supabase.from('task_categories').insert({
          name: newCat.name.trim(),
          points: num(newCat.points),
          is_minor: newCat.is_minor,
          sort_order: cats.length + 1,
        });
        if (e3) throw e3;
        setNewCat({ name: '', points: 10, is_minor: false });
      }
      await onSaved('Settings saved');
    } catch (e) {
      setError(cleanDbMessage(e));
    } finally {
      setSaving(false);
    }
  };

  const chk = { width: 18, height: 18, accentColor: 'var(--brand)' };

  return (
    <div className="stack">
      <Card title="Task categories & points" subtitle="Changes apply to tasks approved from now on." pad={false}>
        <div className="table-wrap">
          <table className="table responsive">
            <thead>
              <tr>
                <th>Category</th>
                <th>Points</th>
                <th>Small work</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {cats.map((c) => (
                <tr key={c.id}>
                  <td data-label="Category"><input className="input" value={c.name} onChange={(e) => setCat(c.id, { name: e.target.value })} /></td>
                  <td data-label="Points"><input className="input" style={{ width: 90 }} type="number" min={0} value={c.points} onChange={(e) => setCat(c.id, { points: e.target.value })} /></td>
                  <td data-label="Small work"><input type="checkbox" checked={c.is_minor} onChange={(e) => setCat(c.id, { is_minor: e.target.checked })} style={chk} /></td>
                  <td data-label="Active"><input type="checkbox" checked={c.is_active} onChange={(e) => setCat(c.id, { is_active: e.target.checked })} style={chk} /></td>
                </tr>
              ))}
              <tr>
                <td data-label="New category"><input className="input" placeholder="+ New category" value={newCat.name} onChange={(e) => setNewCat({ ...newCat, name: e.target.value })} /></td>
                <td data-label="Points"><input className="input" style={{ width: 90 }} type="number" min={0} value={newCat.points} onChange={(e) => setNewCat({ ...newCat, points: e.target.value })} /></td>
                <td data-label="Small work"><input type="checkbox" checked={newCat.is_minor} onChange={(e) => setNewCat({ ...newCat, is_minor: e.target.checked })} style={chk} /></td>
                <td data-label="" />
              </tr>
            </tbody>
          </table>
        </div>
      </Card>

      <Card title="Leave & attendance rules">
        <div className="form-grid">
          <Field label="Paid casual / month"><input className="input" type="number" min={0} step={0.5} value={s.paid_casual_per_month} onChange={(e) => setS({ ...s, paid_casual_per_month: e.target.value })} /></Field>
          <Field label="Paid emergency / month"><input className="input" type="number" min={0} step={0.5} value={s.paid_emergency_per_month} onChange={(e) => setS({ ...s, paid_emergency_per_month: e.target.value })} /></Field>
          <Field label="Casual notice (days)" hint="How many days before casual leave must be applied">
            <input className="input" type="number" min={0} value={s.casual_notice_days} onChange={(e) => setS({ ...s, casual_notice_days: e.target.value })} />
          </Field>
          <Field label="Working days / week" hint="Used for leave, pace forecasts and salary">
            <select className="select" value={s.working_days_per_week} onChange={(e) => setS({ ...s, working_days_per_week: Number(e.target.value) })}>
              <option value={5}>5 (Mon–Fri)</option>
              <option value={6}>6 (Mon–Sat)</option>
              <option value={7}>7 (every day)</option>
            </select>
          </Field>
        </div>
      </Card>

      {error && <Alert>{error}</Alert>}
      <div className="row" style={{ justifyContent: 'flex-end' }}>
        <Button variant="primary" size="lg" loading={saving} onClick={save}>Save changes</Button>
      </div>
    </div>
  );
}
