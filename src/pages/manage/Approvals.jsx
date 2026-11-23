import React, { useEffect, useMemo, useState } from 'react';
import { CheckCheck, Check, X, ClipboardList, CalendarDays } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { LEAVE_TYPES, cleanDbMessage, friendlyError } from '../../lib/hr';
import { fetchCategories, taskPoints } from '../../lib/tasks';
import { round1 } from '../../lib/format';
import { TaskRow } from '../tasks/MyTasks';
import { leaveRangeText, LeavePayBadge } from '../leaves/MyLeaves';
import {
  PageHeader, Card, Button, Badge, StatusBadge, Segmented, EmptyState, Alert, Loading, Modal, Field, Avatar, useToast, useConfirm,
} from '../../components/ui';

export default function Approvals() {
  const toast = useToast();
  const confirm = useConfirm();
  const [tab, setTab] = useState('tasks');
  const [view, setView] = useState('pending');
  const [people, setPeople] = useState({});
  const [categories, setCategories] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [leaves, setLeaves] = useState([]);
  const [counts, setCounts] = useState({ tasks: 0, leaves: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [employee, setEmployee] = useState('all');
  const [selected, setSelected] = useState(new Set());
  const [busy, setBusy] = useState(false);
  const [rejecting, setRejecting] = useState(null); // { kind, ids }

  const catMap = useMemo(() => Object.fromEntries(categories.map((c) => [c.id, c])), [categories]);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const pending = view === 'pending';
      const taskQ = supabase.from('daily_tasks').select('*').order('task_date', { ascending: false }).order('created_at', { ascending: false });
      const leaveQ = supabase.from('leave_requests').select('*').order('start_date', { ascending: !pending });
      const [p, cats, t, l, tc, lc] = await Promise.all([
        supabase.from('profiles').select('id, full_name, employee_code, designation'),
        fetchCategories({ activeOnly: false }),
        pending ? taskQ.eq('status', 'pending') : taskQ.in('status', ['approved', 'rejected']).limit(100),
        pending ? leaveQ.eq('status', 'pending') : leaveQ.in('status', ['approved', 'rejected']).limit(100),
        supabase.from('daily_tasks').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
        supabase.from('leave_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
      ]);
      for (const r of [p, t, l]) if (r.error) throw r.error;
      setPeople(Object.fromEntries((p.data || []).map((x) => [x.id, x])));
      setCategories(cats);
      setTasks(t.data || []);
      setLeaves(l.data || []);
      setCounts({ tasks: tc.count || 0, leaves: lc.count || 0 });
      setSelected(new Set());
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [view]);

  const visibleTasks = employee === 'all' ? tasks : tasks.filter((t) => t.employee_id === employee);
  const visibleLeaves = employee === 'all' ? leaves : leaves.filter((l) => l.employee_id === employee);
  const employeesInList = [...new Set((tab === 'tasks' ? tasks : leaves).map((x) => x.employee_id))];

  const nameOf = (id) => people[id]?.full_name || 'Employee';

  const updateTasks = async (ids, status, note = null) => {
    if (!ids.length) return;
    setBusy(true);
    const { error: err } = await supabase.from('daily_tasks').update({ status, review_note: note }).in('id', ids);
    setBusy(false);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast(`${ids.length} task${ids.length > 1 ? 's' : ''} ${status}`);
    load();
  };

  const updateLeave = async (ids, status, note = null) => {
    setBusy(true);
    for (const id of ids) {
      const { error: err } = await supabase.from('leave_requests').update({ status, review_note: note }).eq('id', id);
      if (err) {
        setBusy(false);
        return toast(cleanDbMessage(err), 'error');
      }
    }
    setBusy(false);
    toast(`Leave ${status}`);
    load();
  };

  const toggle = (id) =>
    setSelected((s) => {
      const n = new Set(s);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });

  // Group tasks by employee
  const taskGroups = useMemo(() => {
    const g = {};
    for (const t of visibleTasks) (g[t.employee_id] ||= []).push(t);
    return Object.entries(g);
  }, [visibleTasks]);

  const selectedIds = [...selected].filter((id) => visibleTasks.some((t) => t.id === id));
  const allIds = visibleTasks.map((t) => t.id);

  return (
    <div className="stack">
      <PageHeader title="Approvals" subtitle="Review daily tasks and leave requests from your team." />

      <div className="row-between wrap">
        <Segmented
          value={tab}
          onChange={(v) => {
            setTab(v);
            setEmployee('all');
          }}
          options={[
            { value: 'tasks', label: 'Tasks', icon: ClipboardList, count: counts.tasks },
            { value: 'leaves', label: 'Leaves', icon: CalendarDays, count: counts.leaves },
          ]}
        />
        <div className="row wrap">
          <select className="select" style={{ width: 'auto', minWidth: 170, height: 38 }} value={employee} onChange={(e) => setEmployee(e.target.value)}>
            <option value="all">All employees</option>
            {employeesInList.map((id) => (
              <option key={id} value={id}>{nameOf(id)}</option>
            ))}
          </select>
          <Segmented
            value={view}
            onChange={setView}
            options={[
              { value: 'pending', label: 'Pending' },
              { value: 'history', label: 'History' },
            ]}
          />
        </div>
      </div>

      {error && <Alert>{error}</Alert>}

      {loading ? (
        <Loading />
      ) : tab === 'tasks' ? (
        <>
          {view === 'pending' && visibleTasks.length > 0 && (
            <Card pad>
              <div className="row-between wrap">
                <div className="small">
                  <span className="strong">{visibleTasks.length}</span> task{visibleTasks.length > 1 ? 's' : ''} waiting ·{' '}
                  <span className="strong">{visibleTasks.reduce((s, t) => s + taskPoints(t, catMap), 0)}</span> pts
                  {selectedIds.length > 0 && <span className="muted"> · {selectedIds.length} selected</span>}
                </div>
                <div className="row wrap">
                  {selectedIds.length > 0 ? (
                    <>
                      <Button size="sm" variant="danger" icon={X} disabled={busy} onClick={() => setRejecting({ kind: 'task', ids: selectedIds })}>
                        Reject selected
                      </Button>
                      <Button size="sm" variant="primary" icon={Check} loading={busy} onClick={() => updateTasks(selectedIds, 'approved')}>
                        Approve selected
                      </Button>
                    </>
                  ) : (
                    <Button size="sm" variant="primary" icon={CheckCheck} loading={busy} onClick={async () => (await confirm({ title: `Approve all ${allIds.length} tasks?`, message: 'Points will be added to each employee for this month.', confirmLabel: 'Approve all' })) && updateTasks(allIds, 'approved')}>
                      Approve all
                    </Button>
                  )}
                </div>
              </div>
            </Card>
          )}

          {taskGroups.length === 0 ? (
            <Card>
              <EmptyState icon={CheckCheck} title={view === 'pending' ? 'All caught up' : 'Nothing reviewed yet'} text={view === 'pending' ? 'No tasks are waiting for approval.' : ''} />
            </Card>
          ) : (
            taskGroups.map(([empId, list]) => {
              const groupIds = list.map((t) => t.id);
              const allChecked = groupIds.every((id) => selected.has(id));
              return (
                <Card
                  key={empId}
                  pad={false}
                  title={
                    <span className="row">
                      <Avatar name={nameOf(empId)} size="sm" />
                      {nameOf(empId)}
                    </span>
                  }
                  subtitle={`${list.length} task${list.length > 1 ? 's' : ''} · ${list.reduce((s, t) => s + taskPoints(t, catMap), 0)} pts`}
                  actions={
                    view === 'pending' && (
                      <>
                        <label className="check xs" style={{ marginRight: 4 }}>
                          <input
                            type="checkbox"
                            checked={allChecked}
                            onChange={() =>
                              setSelected((s) => {
                                const n = new Set(s);
                                groupIds.forEach((id) => (allChecked ? n.delete(id) : n.add(id)));
                                return n;
                              })
                            }
                          />
                          Select
                        </label>
                        <Button size="sm" variant="primary" icon={CheckCheck} disabled={busy} onClick={() => updateTasks(groupIds, 'approved')}>
                          Approve all
                        </Button>
                      </>
                    )
                  }
                >
                  <div className="list">
                    {list.map((t) => (
                      <TaskRow key={t.id} task={t} cat={catMap[t.category_id]} points={taskPoints(t, catMap)} showEmployee={null}>
                        {view === 'pending' ? (
                          <>
                            <input type="checkbox" style={{ width: 18, height: 18, accentColor: 'var(--brand)' }} checked={selected.has(t.id)} onChange={() => toggle(t.id)} aria-label="Select task" />
                            <button className="icon-btn" title="Reject" disabled={busy} onClick={() => setRejecting({ kind: 'task', ids: [t.id] })}>
                              <X size={16} color="var(--red)" />
                            </button>
                            <button className="icon-btn" title="Approve" disabled={busy} onClick={() => updateTasks([t.id], 'approved')}>
                              <Check size={16} color="var(--brand)" />
                            </button>
                          </>
                        ) : (
                          <span className="xs muted">{t.task_date}</span>
                        )}
                      </TaskRow>
                    ))}
                  </div>
                </Card>
              );
            })
          )}
        </>
      ) : visibleLeaves.length === 0 ? (
        <Card>
          <EmptyState icon={CalendarDays} title={view === 'pending' ? 'No pending leave requests' : 'No reviewed leaves yet'} />
        </Card>
      ) : (
        <Card pad={false}>
          <div className="list">
            {visibleLeaves.map((l) => (
              <div className="list-row" key={l.id}>
                <Avatar name={nameOf(l.employee_id)} />
                <div className="list-main">
                  <div className="row wrap" style={{ gap: 8 }}>
                    <span className="list-title">{nameOf(l.employee_id)}</span>
                    <Badge tone={LEAVE_TYPES[l.leave_type]?.tone}>{LEAVE_TYPES[l.leave_type]?.label}</Badge>
                    <LeavePayBadge leave={l} />
                  </div>
                  <div className="list-sub">
                    {leaveRangeText(l)} · {round1(l.days)} day{Number(l.days) === 1 ? '' : 's'}
                  </div>
                  <div className="list-sub">“{l.reason}”</div>
                  {l.review_note && <div className="list-sub">Note: {l.review_note}</div>}
                </div>
                <div className="list-end wrap-mobile">
                  {view === 'pending' ? (
                    <>
                      <Button size="sm" variant="danger" disabled={busy} onClick={() => setRejecting({ kind: 'leave', ids: [l.id] })}>Reject</Button>
                      <Button size="sm" variant="primary" disabled={busy} onClick={() => updateLeave([l.id], 'approved')}>Approve</Button>
                    </>
                  ) : (
                    <StatusBadge status={l.status} />
                  )}
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      <RejectModal
        target={rejecting}
        busy={busy}
        onClose={() => setRejecting(null)}
        onConfirm={async (note) => {
          const r = rejecting;
          setRejecting(null);
          if (r.kind === 'task') await updateTasks(r.ids, 'rejected', note);
          else await updateLeave(r.ids, 'rejected', note);
        }}
      />
    </div>
  );
}

function RejectModal({ target, onClose, onConfirm, busy }) {
  const [note, setNote] = useState('');
  useEffect(() => setNote(''), [target]);
  return (
    <Modal
      open={!!target}
      onClose={onClose}
      title={target?.kind === 'leave' ? 'Reject leave request' : `Reject ${target?.ids.length > 1 ? `${target.ids.length} tasks` : 'task'}`}
      footer={
        <>
          <Button onClick={onClose}>Back</Button>
          <Button variant="danger" loading={busy} onClick={() => onConfirm(note.trim() || null)}>Reject</Button>
        </>
      }
    >
      <Field label="Reason (shown to the employee)">
        <textarea className="textarea" value={note} onChange={(e) => setNote(e.target.value)} placeholder="e.g. Please add the final file link" autoFocus />
      </Field>
    </Modal>
  );
}
