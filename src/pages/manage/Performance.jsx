import React, { useEffect, useMemo, useState } from 'react';
import { startOfMonth, format } from 'date-fns';
import { Trophy, Target, Settings2, Gift, Users, Sparkles } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useHrSettings, tierFor, cleanDbMessage, friendlyError, loadHrSettings } from '../../lib/hr';
import { fetchCategories, summarize } from '../../lib/tasks';
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
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [kpiFor, setKpiFor] = useState(null);

  const catMap = useMemo(() => Object.fromEntries(categories.map((c) => [c.id, c])), [categories]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const { startStr, endStr } = monthRange(month);
      const [p, cats, t, k] = await Promise.all([
        supabase.from('profiles').select('id, full_name, employee_code, designation, role, status').order('full_name'),
        fetchCategories({ activeOnly: false }),
        supabase.from('daily_tasks').select('employee_id, category_id, quantity, status, points_awarded').gte('task_date', startStr).lte('task_date', endStr),
        supabase.from('employee_kpis').select('*'),
      ]);
      for (const r of [p, t, k]) if (r.error) throw r.error;
      setPeople(p.data || []);
      setCategories(cats);
      setTasks(t.data || []);
      setKpis(k.data || []);
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [month]);

  const rows = useMemo(() => {
    const withTasks = new Set(tasks.map((t) => t.employee_id));
    return people
      .filter((p) => (p.status !== 'inactive' && p.role !== 'admin') || withTasks.has(p.id))
      .map((p) => {
        const mine = tasks.filter((t) => t.employee_id === p.id);
        const sum = summarize(mine, catMap);
        const myKpis = kpis.filter((k) => k.employee_id === p.id && k.monthly_target > 0 && catMap[k.category_id]);
        const kpiMet = myKpis.filter((k) => (sum.byCategory[k.category_id]?.approved || 0) >= k.monthly_target).length;
        return { ...p, sum, tier: tierFor(sum.points, settings), kpiTotal: myKpis.length, kpiMet };
      })
      .sort((a, b) => b.sum.points - a.sum.points);
  }, [people, tasks, kpis, catMap, settings]);

  const champions = rows.filter((r) => r.tier.level === 3);
  const teamPoints = rows.reduce((s, r) => s + r.sum.points, 0);

  return (
    <div className="stack">
      <PageHeader
        title="Performance"
        subtitle="Points from approved tasks decide each person's tier. Top tier earns the incentive."
        actions={<MonthPicker value={month} onChange={setMonth} />}
      />

      <Segmented
        value={tab}
        onChange={setTab}
        options={[
          { value: 'board', label: 'Leaderboard', icon: Trophy },
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
            <Stat label={settings.tier3_name} value={champions.length} sub={`${settings.tier3_min_points}+ pts`} icon={Trophy} tone="amber" />
            <Stat label={settings.tier2_name} value={rows.filter((r) => r.tier.level === 2).length} sub={`${settings.tier2_min_points}+ pts`} icon={Users} tone="violet" />
            <Stat
              label="Incentive payout"
              value={money(champions.length * Number(settings.incentive_amount || 0), settings.currency)}
              sub={`${money(settings.incentive_amount, settings.currency)} × ${champions.length}`}
              icon={Gift}
              tone="blue"
            />
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
                      <th className="num">Approved</th>
                      <th className="num">Points</th>
                      <th className="num">Pending</th>
                      <th>KPI</th>
                      <th>Tier</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r, i) => (
                      <tr key={r.id}>
                        <td data-label="Rank" className="muted strong">{i + 1}</td>
                        <td data-label="">
                          <div className="row">
                            <Avatar name={r.full_name} size="sm" />
                            <div style={{ textAlign: 'left' }}>
                              <div className="strong">{r.full_name}</div>
                              <div className="xs muted">{r.designation || r.employee_code || ''}</div>
                            </div>
                          </div>
                        </td>
                        <td data-label="Approved tasks" className="num">{r.sum.approvedCount}</td>
                        <td data-label="Points" className="num strong">{r.sum.points}</td>
                        <td data-label="Pending pts" className="num muted">{r.sum.pendingPoints || '—'}</td>
                        <td data-label="KPI">
                          {r.kpiTotal === 0 ? (
                            <span className="muted xs">Not set</span>
                          ) : (
                            <Badge tone={r.kpiMet === r.kpiTotal ? 'green' : 'amber'}>
                              {r.kpiMet}/{r.kpiTotal} met
                            </Badge>
                          )}
                        </td>
                        <td data-label="Tier">
                          <TierBadge tier={r.tier} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </>
      ) : tab === 'kpi' ? (
        <Card title="Monthly KPI targets" subtitle="Minimum number of tasks each person should complete per category, every month." pad={false}>
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
    if (num(s.tier3_min_points) <= num(s.tier2_min_points)) return setError(`${s.tier3_name} points must be higher than ${s.tier2_name} points.`);
    setSaving(true);
    try {
      const { error: e1 } = await supabase
        .from('hr_settings')
        .update({
          tier1_name: s.tier1_name.trim() || 'Rising',
          tier2_name: s.tier2_name.trim() || 'Achiever',
          tier3_name: s.tier3_name.trim() || 'Champion',
          tier2_min_points: num(s.tier2_min_points),
          tier3_min_points: num(s.tier3_min_points),
          incentive_amount: num(s.incentive_amount),
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
                  <td data-label="Small work"><input type="checkbox" checked={c.is_minor} onChange={(e) => setCat(c.id, { is_minor: e.target.checked })} style={{ width: 18, height: 18, accentColor: 'var(--brand)' }} /></td>
                  <td data-label="Active"><input type="checkbox" checked={c.is_active} onChange={(e) => setCat(c.id, { is_active: e.target.checked })} style={{ width: 18, height: 18, accentColor: 'var(--brand)' }} /></td>
                </tr>
              ))}
              <tr>
                <td data-label="New category"><input className="input" placeholder="+ New category" value={newCat.name} onChange={(e) => setNewCat({ ...newCat, name: e.target.value })} /></td>
                <td data-label="Points"><input className="input" style={{ width: 90 }} type="number" min={0} value={newCat.points} onChange={(e) => setNewCat({ ...newCat, points: e.target.value })} /></td>
                <td data-label="Small work"><input type="checkbox" checked={newCat.is_minor} onChange={(e) => setNewCat({ ...newCat, is_minor: e.target.checked })} style={{ width: 18, height: 18, accentColor: 'var(--brand)' }} /></td>
                <td data-label="" />
              </tr>
            </tbody>
          </table>
        </div>
      </Card>

      <div className="grid-2">
        <Card title="Performance tiers" subtitle="Monthly points needed for each tier">
          <div className="form-grid">
            <Field label="Tier 1 name"><input className="input" value={s.tier1_name} onChange={(e) => setS({ ...s, tier1_name: e.target.value })} /></Field>
            <Field label="Starts at"><input className="input" value="0 points" disabled /></Field>
            <Field label="Tier 2 name"><input className="input" value={s.tier2_name} onChange={(e) => setS({ ...s, tier2_name: e.target.value })} /></Field>
            <Field label="Min points"><input className="input" type="number" min={1} value={s.tier2_min_points} onChange={(e) => setS({ ...s, tier2_min_points: e.target.value })} /></Field>
            <Field label="Tier 3 name (gets incentive)"><input className="input" value={s.tier3_name} onChange={(e) => setS({ ...s, tier3_name: e.target.value })} /></Field>
            <Field label="Min points"><input className="input" type="number" min={1} value={s.tier3_min_points} onChange={(e) => setS({ ...s, tier3_min_points: e.target.value })} /></Field>
            <Field label={`Monthly incentive (${s.currency})`} className="span-2" hint="Added to payroll automatically for the top tier.">
              <input className="input" type="number" min={0} value={s.incentive_amount} onChange={(e) => setS({ ...s, incentive_amount: e.target.value })} />
            </Field>
          </div>
        </Card>

        <Card title="Leave & attendance rules">
          <div className="form-grid">
            <Field label="Paid casual / month"><input className="input" type="number" min={0} step={0.5} value={s.paid_casual_per_month} onChange={(e) => setS({ ...s, paid_casual_per_month: e.target.value })} /></Field>
            <Field label="Paid emergency / month"><input className="input" type="number" min={0} step={0.5} value={s.paid_emergency_per_month} onChange={(e) => setS({ ...s, paid_emergency_per_month: e.target.value })} /></Field>
            <Field label="Casual notice (days)" hint="How many days before casual leave must be applied">
              <input className="input" type="number" min={0} value={s.casual_notice_days} onChange={(e) => setS({ ...s, casual_notice_days: e.target.value })} />
            </Field>
            <Field label="Working days / week" hint="Used for leave and salary calculation">
              <select className="select" value={s.working_days_per_week} onChange={(e) => setS({ ...s, working_days_per_week: Number(e.target.value) })}>
                <option value={5}>5 (Mon–Fri)</option>
                <option value={6}>6 (Mon–Sat)</option>
                <option value={7}>7 (every day)</option>
              </select>
            </Field>
          </div>
        </Card>
      </div>

      {error && <Alert>{error}</Alert>}
      <div className="row" style={{ justifyContent: 'flex-end' }}>
        <Button variant="primary" size="lg" loading={saving} onClick={save}>Save changes</Button>
      </div>
    </div>
  );
}
