import React, { useEffect, useMemo, useState } from 'react';
import { startOfMonth, format } from 'date-fns';
import { Plus, Send, Pencil, Trash2, ClipboardList, Target, Sparkles, Clock3, ExternalLink } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useHrSettings, cleanDbMessage, friendlyError } from '../../lib/hr';
import { fetchPlans, fetchAssignments, workingDaysInfo, taskPointsToday } from '../../lib/incentives';
import IncentiveTracker from '../../components/IncentiveTracker';
import { fetchCategories, summarize, taskPoints } from '../../lib/tasks';
import { monthRange, prettyDate, ymd } from '../../lib/format';
import {
  PageHeader, Card, Button, Badge, StatusBadge, Field, EmptyState, Alert, Loading, Modal, MonthPicker, Progress, useToast, useConfirm,
} from '../../components/ui';

export default function MyTasks() {
  const { profile } = useAuth();
  const { settings } = useHrSettings();
  const toast = useToast();
  const confirm = useConfirm();
  const [month, setMonth] = useState(startOfMonth(new Date()));
  const [categories, setCategories] = useState([]);
  const [kpis, setKpis] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [plan, setPlan] = useState(null);
  const [holidays, setHolidays] = useState(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null); // null | {} (new) | task
  const [submitting, setSubmitting] = useState(false);

  const catMap = useMemo(() => Object.fromEntries(categories.map((c) => [c.id, c])), [categories]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const { startStr, endStr } = monthRange(month);
      const [cats, k, t, plans, assigned, hol] = await Promise.all([
        fetchCategories({ activeOnly: false }),
        supabase.from('employee_kpis').select('*').eq('employee_id', profile.id),
        supabase
          .from('daily_tasks')
          .select('*')
          .eq('employee_id', profile.id)
          .gte('task_date', startStr)
          .lte('task_date', endStr)
          .order('task_date', { ascending: false })
          .order('created_at', { ascending: false }),
        fetchPlans().catch(() => []),
        fetchAssignments().catch(() => ({})),
        supabase.from('holidays').select('date').gte('date', startStr).lte('date', endStr),
      ]);
      if (k.error) throw k.error;
      setPlan(plans.find((p) => p.id === assigned[profile.id]) || null);
      setHolidays(new Set((hol.data || []).map((h) => h.date)));
      if (t.error) throw t.error;
      setCategories(cats);
      setKpis(k.data || []);
      setTasks(t.data || []);
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (profile) load();
  }, [profile, month]);

  const sum = summarize(tasks, catMap);
  const days = workingDaysInfo(month, Number(settings.working_days_per_week) || 6, holidays);
  const todayPts = taskPointsToday(tasks, catMap);
  const drafts = tasks.filter((t) => t.status === 'draft' || t.status === 'rejected');

  const submitDrafts = async () => {
    if (!drafts.length) return;
    setSubmitting(true);
    const { error: err } = await supabase.from('daily_tasks').update({ status: 'pending' }).in('id', drafts.map((d) => d.id));
    setSubmitting(false);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast(`${drafts.length} task${drafts.length > 1 ? 's' : ''} sent for approval`);
    load();
  };

  const submitOne = async (task) => {
    const { error: err } = await supabase.from('daily_tasks').update({ status: 'pending' }).eq('id', task.id);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast('Sent for approval');
    load();
  };

  const remove = async (task) => {
    const ok = await confirm({
      title: task.status === 'pending' ? 'Withdraw this task?' : 'Delete this task?',
      message: `"${task.title}" will be removed.`,
      confirmLabel: task.status === 'pending' ? 'Withdraw' : 'Delete',
      danger: true,
    });
    if (!ok) return;
    const { error: err } = await supabase.from('daily_tasks').delete().eq('id', task.id);
    if (err) return toast(cleanDbMessage(err), 'error');
    load();
  };

  // Group by date
  const groups = useMemo(() => {
    const g = {};
    for (const t of tasks) (g[t.task_date] ||= []).push(t);
    return Object.entries(g);
  }, [tasks]);

  const kpiRows = kpis
    .filter((k) => k.monthly_target > 0 && catMap[k.category_id])
    .map((k) => ({ ...k, cat: catMap[k.category_id], done: sum.byCategory[k.category_id]?.approved || 0, pending: sum.byCategory[k.category_id]?.pending || 0 }));

  const isCurrentMonth = format(month, 'yyyy-MM') === format(new Date(), 'yyyy-MM');

  return (
    <div className="stack">
      <PageHeader
        title="Daily Tasks"
        subtitle="Log your work every day and submit it for project manager approval."
        actions={
          <>
            <MonthPicker value={month} onChange={setMonth} />
            <Button variant="primary" icon={Plus} onClick={() => setEditing({})}>Add task</Button>
          </>
        }
      />

      {error && <Alert>{error}</Alert>}

      {/* Incentive tracker */}
      {!loading && (
        <IncentiveTracker
          plan={plan}
          points={sum.points}
          pending={sum.pendingPoints}
          today={isCurrentMonth ? todayPts : 0}
          days={days}
          currency={settings.currency}
        />
      )}

      <div className="grid-2">
        <Card title="Monthly KPI" subtitle="Minimum target per category" pad={kpiRows.length > 0}>
          {kpiRows.length === 0 ? (
            <EmptyState icon={Target} title="No KPI set yet" text="Your project manager will set your monthly targets." />
          ) : (
            <div className="stack-sm">
              {kpiRows.map((k) => {
                const hit = k.done >= k.monthly_target;
                return (
                  <div key={k.id}>
                    <div className="row-between small" style={{ marginBottom: 6 }}>
                      <span className="strong">{k.cat.name}</span>
                      <span className={hit ? 'text-green strong' : 'muted'}>
                        {k.done} / {k.monthly_target}
                        {k.pending > 0 && <span className="muted"> (+{k.pending} pending)</span>}
                      </span>
                    </div>
                    <Progress value={k.done} max={k.monthly_target} tone={hit ? '' : 'amber'} />
                  </div>
                );
              })}
            </div>
          )}
        </Card>

        <Card title="Points guide" subtitle="Approved tasks earn points">
          <div className="stack-sm">
            {categories
              .filter((c) => c.is_active)
              .map((c) => (
                <div className="row-between small" key={c.id}>
                  <span>{c.name}</span>
                  <Badge tone={c.is_minor ? 'gray' : 'green'}>{c.points} pts</Badge>
                </div>
              ))}
            {plan?.slabs?.length > 0 && (
              <div className="xs muted" style={{ marginTop: 4 }}>
                {plan.slabs.map((sl) => `${sl.level} ${sl.min_points}+`).join(' · ')}
                {plan.daily_points ? ` · Daily KPI ${plan.daily_points} pts` : ''}
              </div>
            )}
          </div>
        </Card>
      </div>

      <Card
        title="My tasks"
        subtitle={format(month, 'MMMM yyyy')}
        pad={false}
        actions={
          drafts.length > 0 && (
            <Button size="sm" variant="dark" icon={Send} loading={submitting} onClick={submitDrafts}>
              Submit {drafts.length} for approval
            </Button>
          )
        }
      >
        {loading ? (
          <Loading />
        ) : tasks.length === 0 ? (
          <EmptyState
            icon={ClipboardList}
            title="No tasks logged"
            text="Add what you worked on — posters, videos, shoots, logos or small fixes."
            action={<Button variant="primary" icon={Plus} onClick={() => setEditing({})}>Add task</Button>}
          />
        ) : (
          groups.map(([date, list]) => (
            <div key={date}>
              <div className="row-between" style={{ padding: '10px 20px', background: 'var(--surface-2)', borderBottom: '1px solid var(--border)' }}>
                <span className="xs strong muted" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  {prettyDate(date, 'EEEE, dd MMM')}
                </span>
                <span className="xs muted">{list.length} task{list.length > 1 ? 's' : ''}</span>
              </div>
              <div className="list">
                {list.map((t) => (
                  <TaskRow
                    key={t.id}
                    task={t}
                    cat={catMap[t.category_id]}
                    points={taskPoints(t, catMap)}
                    onEdit={() => setEditing(t)}
                    onDelete={() => remove(t)}
                    onSubmit={() => submitOne(t)}
                  />
                ))}
              </div>
            </div>
          ))
        )}
      </Card>

      <TaskModal
        task={editing}
        categories={categories.filter((c) => c.is_active || c.id === editing?.category_id)}
        onClose={() => setEditing(null)}
        onSaved={(msg) => {
          setEditing(null);
          toast(msg);
          load();
        }}
      />
    </div>
  );
}

export function TaskRow({ task, cat, points, onEdit, onDelete, onSubmit, showEmployee, children }) {
  const editable = task.status !== 'approved' && task.status !== 'pending';
  return (
    <div className="list-row">
      <div className="list-main">
        <div className="row wrap" style={{ gap: 8 }}>
          <span className="list-title">{task.title}</span>
          {task.quantity > 1 && <Badge>×{task.quantity}</Badge>}
        </div>
        <div className="list-sub">
          {showEmployee && <strong style={{ color: 'var(--text-2)' }}>{showEmployee} · </strong>}
          {cat?.name || 'Task'}
          {task.client_name ? ` · ${task.client_name}` : ''}
          {task.link && (
            <>
              {' · '}
              <a href={task.link} target="_blank" rel="noreferrer" style={{ color: 'var(--blue)', display: 'inline-flex', alignItems: 'center', gap: 3 }}>
                Link <ExternalLink size={12} />
              </a>
            </>
          )}
        </div>
        {task.notes && <div className="list-sub">{task.notes}</div>}
        {task.status === 'rejected' && task.review_note && <div className="list-sub text-red">Manager: {task.review_note}</div>}
      </div>
      <div className="list-end wrap-mobile">
        <Badge tone={task.status === 'approved' ? 'green' : 'gray'}>
          {task.status === 'approved' ? <Sparkles size={12} /> : <Clock3 size={12} />}
          {points} pts
        </Badge>
        <StatusBadge status={task.status} />
        {children}
        {!children && editable && (
          <>
            <button className="icon-btn" onClick={onEdit} aria-label="Edit"><Pencil size={15} /></button>
            <button className="icon-btn" onClick={onDelete} aria-label="Delete"><Trash2 size={15} /></button>
            <Button size="sm" onClick={onSubmit}>Submit</Button>
          </>
        )}
        {!children && task.status === 'pending' && (
          <button className="icon-btn" onClick={onDelete} aria-label="Withdraw"><Trash2 size={15} /></button>
        )}
      </div>
    </div>
  );
}

function TaskModal({ task, categories, onClose, onSaved }) {
  const isNew = task && !task.id;
  const [form, setForm] = useState({});
  const [saving, setSaving] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!task) return;
    setError(null);
    setForm({
      task_date: task.task_date || ymd(new Date()),
      category_id: task.category_id || categories[0]?.id || '',
      title: task.title || '',
      client_name: task.client_name || '',
      quantity: task.quantity || 1,
      link: task.link || '',
      notes: task.notes || '',
    });
  }, [task]);

  const set = (patch) => setForm((f) => ({ ...f, ...patch }));
  const cat = categories.find((c) => c.id === form.category_id);

  const save = async (status) => {
    setError(null);
    if (!form.title?.trim()) return setError('Add a short title for the task.');
    if (!form.category_id) return setError('Choose a category.');
    setSaving(status);
    const { data: auth } = await supabase.auth.getUser();
    const payload = {
      task_date: form.task_date,
      category_id: form.category_id,
      title: form.title.trim(),
      client_name: form.client_name.trim() || null,
      quantity: Math.max(1, Math.min(100, Number(form.quantity) || 1)),
      link: form.link.trim() || null,
      notes: form.notes.trim() || null,
      status,
    };
    const res = isNew
      ? await supabase.from('daily_tasks').insert({ ...payload, employee_id: auth.user.id })
      : await supabase.from('daily_tasks').update(payload).eq('id', task.id);
    setSaving(null);
    if (res.error) return setError(cleanDbMessage(res.error));
    onSaved(status === 'pending' ? 'Task sent for approval' : 'Task saved as draft');
  };

  return (
    <Modal
      open={!!task}
      onClose={onClose}
      title={isNew ? 'Add task' : 'Edit task'}
      footer={
        <>
          <Button loading={saving === 'draft'} onClick={() => save('draft')}>Save draft</Button>
          <Button variant="primary" icon={Send} loading={saving === 'pending'} onClick={() => save('pending')}>Submit</Button>
        </>
      }
    >
      <form className="stack" onSubmit={(e) => { e.preventDefault(); save('pending'); }}>
        <div className="form-grid">
          <Field label="Category" className="span-2">
            <select className="select" value={form.category_id || ''} onChange={(e) => set({ category_id: e.target.value })}>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name} — {c.points} pts
                </option>
              ))}
            </select>
          </Field>
          <Field label="What did you do?" className="span-2">
            <input className="input" value={form.title || ''} onChange={(e) => set({ title: e.target.value })} placeholder="e.g. Diwali offer poster" autoFocus />
          </Field>
          <Field label="Client / project">
            <input className="input" value={form.client_name || ''} onChange={(e) => set({ client_name: e.target.value })} placeholder="Optional" />
          </Field>
          <Field label="Date">
            <input className="input" type="date" value={form.task_date || ''} max={ymd(new Date())} onChange={(e) => set({ task_date: e.target.value })} />
          </Field>
          <Field label="Quantity" hint={cat ? `${(cat.points || 0) * (Number(form.quantity) || 1)} points if approved` : ''}>
            <input className="input" type="number" min={1} max={100} inputMode="numeric" value={form.quantity || 1} onChange={(e) => set({ quantity: e.target.value })} />
          </Field>
          <Field label="Link (Drive, Figma…)">
            <input className="input" type="url" value={form.link || ''} onChange={(e) => set({ link: e.target.value })} placeholder="https://" />
          </Field>
          <Field label="Notes" className="span-2">
            <textarea className="textarea" value={form.notes || ''} onChange={(e) => set({ notes: e.target.value })} placeholder="Optional" />
          </Field>
        </div>
        {error && <Alert>{error}</Alert>}
      </form>
    </Modal>
  );
}
