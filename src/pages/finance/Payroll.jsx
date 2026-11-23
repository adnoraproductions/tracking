import React, { useEffect, useMemo, useState } from 'react';
import { eachDayOfInterval, endOfMonth, format, isAfter, startOfDay } from 'date-fns';
import { Banknote, Settings2, RefreshCw, Download, CheckCircle2, Info } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { tierFor, friendlyError, cleanDbMessage } from '../../lib/hr';
import { money, monthRange, round1, ymd } from '../../lib/format';
import { Card, Stat, Button, Badge, TierBadge, EmptyState, Alert, Loading, Modal, Field, Avatar } from '../../components/ui';

function workingDates(from, to, perWeek, holidaySet) {
  if (isAfter(from, to)) return [];
  return eachDayOfInterval({ start: from, end: to }).filter((d) => {
    const dow = d.getDay();
    if (perWeek === 6 && dow === 0) return false;
    if (perWeek === 5 && (dow === 0 || dow === 6)) return false;
    return !holidaySet.has(ymd(d));
  });
}

const calcNet = (r) =>
  Math.round(Number(r.base_salary) - Number(r.attendance_deduction) + Number(r.incentive) + Number(r.bonus) - Number(r.other_deduction));

export default function Payroll({ month, currency, toast, settings }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [edit, setEdit] = useState(null);
  const [salaryOpen, setSalaryOpen] = useState(false);
  const { start, startStr, endStr } = monthRange(month);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const [p, sal, att, lv, tk, hol, rec] = await Promise.all([
        supabase.from('profiles').select('id, full_name, employee_code, designation, role, status').order('full_name'),
        supabase.from('employee_salaries').select('*'),
        supabase.from('attendance_days').select('employee_id, date, status').gte('date', startStr).lte('date', endStr),
        supabase.from('leave_requests').select('employee_id, paid_days, unpaid_days, start_date').eq('status', 'approved').gte('start_date', startStr).lte('start_date', endStr),
        supabase.from('daily_tasks').select('employee_id, points_awarded').eq('status', 'approved').gte('task_date', startStr).lte('task_date', endStr),
        supabase.from('holidays').select('date').gte('date', startStr).lte('date', endStr),
        supabase.from('payroll_records').select('*').eq('month', startStr),
      ]);
      for (const r of [p, sal, att, lv, tk, rec]) if (r.error) throw r.error;
      setData({
        people: p.data || [],
        salaries: Object.fromEntries((sal.data || []).map((s) => [s.employee_id, s])),
        attendance: att.data || [],
        leaves: lv.data || [],
        tasks: tk.data || [],
        holidays: new Set((hol.data || []).map((h) => h.date)),
        records: Object.fromEntries((rec.data || []).map((r) => [r.employee_id, r])),
      });
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [startStr]);

  const today = startOfDay(new Date());
  const monthEnd = endOfMonth(month);
  const countUntil = isAfter(monthEnd, today) ? today : monthEnd;
  const perWeek = Number(settings.working_days_per_week) || 6;

  const rows = useMemo(() => {
    if (!data) return [];
    const fullDays = workingDates(start, monthEnd, perWeek, data.holidays).length;
    const elapsedDays = workingDates(start, countUntil, perWeek, data.holidays).length;
    return data.people
      .filter((p) => p.status !== 'inactive' || data.records[p.id])
      .map((p) => {
        const salary = Number(data.salaries[p.id]?.monthly_salary || 0);
        const present = Math.min(
          elapsedDays,
          data.attendance
            .filter((a) => a.employee_id === p.id && a.date <= ymd(countUntil))
            .reduce((s, a) => s + (a.status === 'present' ? 1 : a.status === 'half_day' ? 0.5 : 0), 0),
        );
        const myLeaves = data.leaves.filter((l) => l.employee_id === p.id);
        const paidLeave = myLeaves.reduce((s, l) => s + Number(l.paid_days), 0);
        const unpaid = Math.max(0, round1(elapsedDays - present - paidLeave));
        const perDay = fullDays > 0 ? salary / fullDays : 0;
        const points = data.tasks.filter((t) => t.employee_id === p.id).reduce((s, t) => s + Number(t.points_awarded), 0);
        const tier = tierFor(points, settings);
        const existing = data.records[p.id];
        const computed = {
          employee_id: p.id,
          month: startStr,
          base_salary: salary,
          working_days: fullDays,
          present_days: present,
          paid_leave_days: paidLeave,
          unpaid_days: unpaid,
          attendance_deduction: Math.round(perDay * unpaid),
          points,
          tier: tier.name,
          incentive: tier.level === 3 ? Number(settings.incentive_amount || 0) : 0,
          bonus: Number(existing?.bonus || 0),
          other_deduction: Number(existing?.other_deduction || 0),
          notes: existing?.notes || null,
          status: 'draft',
        };
        computed.net_pay = calcNet(computed);
        const shown = existing || computed;
        return { person: p, salary, tier, computed, record: existing, shown, perDay };
      });
  }, [data, settings, startStr]);

  const payable = rows.filter((r) => r.salary > 0 || r.record);
  const totals = payable.reduce(
    (s, r) => {
      s.net += Number(r.shown.net_pay);
      if (r.record?.status === 'paid') s.paid += Number(r.record.net_pay);
      s.incentive += Number(r.shown.incentive);
      s.deduction += Number(r.shown.attendance_deduction);
      return s;
    },
    { net: 0, paid: 0, incentive: 0, deduction: 0 },
  );

  const generate = async () => {
    const toSave = payable.filter((r) => r.record?.status !== 'paid').map((r) => r.computed);
    if (!toSave.length) return toast('Nothing to generate');
    setBusy(true);
    const { error: err } = await supabase.from('payroll_records').upsert(toSave, { onConflict: 'employee_id,month' });
    setBusy(false);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast(`Payroll calculated for ${toSave.length} employee${toSave.length > 1 ? 's' : ''}`);
    load();
  };

  const exportCsv = () => {
    const header = ['Employee', 'Code', 'Base salary', 'Working days', 'Present', 'Paid leave', 'Unpaid days', 'Attendance deduction', 'Points', 'Tier', 'Incentive', 'Bonus', 'Other deduction', 'Net pay', 'Status', 'Paid on'];
    const lines = payable.map((r) => {
      const s = r.shown;
      return [r.person.full_name, r.person.employee_code || '', s.base_salary, s.working_days, s.present_days, s.paid_leave_days, s.unpaid_days, s.attendance_deduction, s.points, s.tier, s.incentive, s.bonus, s.other_deduction, s.net_pay, r.record?.status || 'preview', r.record?.paid_on || '']
        .map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`)
        .join(',');
    });
    const blob = new Blob([[header.join(','), ...lines].join('\n')], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `payroll-${format(month, 'yyyy-MM')}.csv`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  if (loading) return <Loading />;
  if (error) return <Alert>{error}</Alert>;

  const isCurrent = format(month, 'yyyy-MM') === format(new Date(), 'yyyy-MM');
  const missingSalary = rows.filter((r) => r.salary === 0 && !r.record && r.person.role !== 'admin');

  return (
    <div className="stack">
      <div className="grid-stats">
        <Stat label="Total payroll" value={money(totals.net, currency)} sub={`${payable.length} employees`} icon={Banknote} tone="green" />
        <Stat label="Already paid" value={money(totals.paid, currency)} sub={`${money(totals.net - totals.paid, currency)} remaining`} icon={CheckCircle2} tone="blue" />
        <Stat label="Incentives" value={money(totals.incentive, currency)} sub={`${settings.tier3_name} tier`} icon={Banknote} tone="amber" />
        <Stat label="Attendance deductions" value={money(totals.deduction, currency)} sub="Unpaid / absent days" icon={Banknote} tone="red" />
      </div>

      {isCurrent && (
        <Alert tone="blue" icon={Info}>
          {format(month, 'MMMM')} is still running — absences are counted only up to today. Generate the final payroll after the month ends.
        </Alert>
      )}
      {missingSalary.length > 0 && (
        <Alert tone="amber" icon={Info}>
          No salary set for {missingSalary.map((r) => r.person.full_name).join(', ')}. Use “Salaries” to add them.
        </Alert>
      )}

      <Card
        title={`Payroll · ${format(month, 'MMMM yyyy')}`}
        subtitle="Salary − (per-day rate × unpaid days) + incentive + bonus − other deductions"
        pad={false}
        actions={
          <>
            <Button size="sm" icon={Settings2} onClick={() => setSalaryOpen(true)}>Salaries</Button>
            <Button size="sm" icon={Download} onClick={exportCsv} disabled={!payable.length}>CSV</Button>
            <Button size="sm" variant="primary" icon={RefreshCw} loading={busy} onClick={generate}>Calculate</Button>
          </>
        }
      >
        {payable.length === 0 ? (
          <EmptyState icon={Banknote} title="No salaries set up" text="Add monthly salaries for your team to start running payroll." action={<Button variant="primary" onClick={() => setSalaryOpen(true)}>Set salaries</Button>} />
        ) : (
          <div className="table-wrap">
            <table className="table responsive">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th className="num">Salary</th>
                  <th className="num">Present</th>
                  <th className="num">Paid leave</th>
                  <th className="num">Unpaid</th>
                  <th className="num">Deduction</th>
                  <th>Tier</th>
                  <th className="num">Incentive</th>
                  <th className="num">Net pay</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {payable.map((r) => {
                  const s = r.shown;
                  return (
                    <tr key={r.person.id} onClick={() => setEdit(r)} style={{ cursor: 'pointer' }}>
                      <td data-label="">
                        <div className="row">
                          <Avatar name={r.person.full_name} size="sm" />
                          <span className="strong">{r.person.full_name}</span>
                        </div>
                      </td>
                      <td data-label="Salary" className="num">{money(s.base_salary, currency)}</td>
                      <td data-label="Present" className="num">{round1(s.present_days)}/{round1(s.working_days)}</td>
                      <td data-label="Paid leave" className="num">{round1(s.paid_leave_days)}</td>
                      <td data-label="Unpaid days" className={`num ${Number(s.unpaid_days) > 0 ? 'text-red strong' : ''}`}>{round1(s.unpaid_days)}</td>
                      <td data-label="Deduction" className="num">{Number(s.attendance_deduction) ? `−${money(s.attendance_deduction, currency)}` : '—'}</td>
                      <td data-label="Tier"><TierBadge tier={{ level: r.tier.level, name: s.tier || r.tier.name }} /></td>
                      <td data-label="Incentive" className="num">{Number(s.incentive) ? `+${money(s.incentive, currency)}` : '—'}</td>
                      <td data-label="Net pay" className="num strong">{money(s.net_pay, currency)}</td>
                      <td data-label="Status">
                        {r.record?.status === 'paid' ? <Badge tone="green">Paid</Badge> : r.record ? <Badge tone="amber">Draft</Badge> : <Badge>Preview</Badge>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <PayslipModal
        row={edit}
        currency={currency}
        onClose={() => setEdit(null)}
        onSaved={(msg) => {
          setEdit(null);
          toast(msg);
          load();
        }}
      />
      <SalaryModal
        open={salaryOpen}
        people={(data?.people || []).filter((p) => p.status !== 'inactive')}
        salaries={data?.salaries || {}}
        currency={currency}
        onClose={() => setSalaryOpen(false)}
        onSaved={() => {
          setSalaryOpen(false);
          toast('Salaries saved');
          load();
        }}
      />
    </div>
  );
}

function PayslipModal({ row, currency, onClose, onSaved }) {
  const [f, setF] = useState(null);
  const [saving, setSaving] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!row) return;
    setError(null);
    const base = row.record || row.computed;
    setF({ ...base, paid_on: base.paid_on || ymd(new Date()) });
  }, [row]);

  if (!row || !f) return null;
  const locked = row.record?.status === 'paid';
  const set = (p) =>
    setF((x) => {
      const n = { ...x, ...p };
      if ('unpaid_days' in p) n.attendance_deduction = Math.round(row.perDay * (Number(p.unpaid_days) || 0));
      n.net_pay = calcNet(n);
      return n;
    });

  const save = async (status) => {
    setSaving(status);
    const { id, created_at, updated_at, ...rest } = f;
    const payload = {
      ...rest,
      status,
      paid_on: status === 'paid' ? f.paid_on : null,
      unpaid_days: Number(f.unpaid_days) || 0,
      incentive: Number(f.incentive) || 0,
      bonus: Number(f.bonus) || 0,
      other_deduction: Number(f.other_deduction) || 0,
      net_pay: calcNet(f),
    };
    const { error: err } = await supabase.from('payroll_records').upsert(payload, { onConflict: 'employee_id,month' });
    setSaving(null);
    if (err) return setError(cleanDbMessage(err));
    onSaved(status === 'paid' ? 'Marked as paid' : 'Payroll saved');
  };

  const reopen = async () => {
    const { error: err } = await supabase.from('payroll_records').update({ status: 'draft', paid_on: null }).eq('id', row.record.id);
    if (err) return setError(cleanDbMessage(err));
    onSaved('Payroll reopened');
  };

  const line = (label, value, cls = '') => (
    <div className="row-between small" style={{ padding: '6px 0' }}>
      <span className="muted">{label}</span>
      <span className={`tabular ${cls}`}>{value}</span>
    </div>
  );

  return (
    <Modal
      open
      onClose={onClose}
      title={`${row.person.full_name} · ${format(new Date(`${f.month}T00:00:00`), 'MMM yyyy')}`}
      footer={
        locked ? (
          <>
            <Button onClick={reopen}>Reopen</Button>
            <Button variant="primary" onClick={onClose}>Done</Button>
          </>
        ) : (
          <>
            <Button loading={saving === 'draft'} onClick={() => save('draft')}>Save draft</Button>
            <Button variant="primary" loading={saving === 'paid'} onClick={() => save('paid')}>Mark as paid</Button>
          </>
        )
      }
    >
      <div className="stack">
        <div className="card card-pad" style={{ background: 'var(--surface-2)', boxShadow: 'none' }}>
          {line('Monthly salary', money(f.base_salary, currency))}
          {line('Working days in month', round1(f.working_days))}
          {line('Days present', round1(f.present_days))}
          {line('Paid leave days', round1(f.paid_leave_days))}
          {line(`Approved points`, `${f.points} · ${f.tier || ''}`)}
          {line('Per-day rate', money(row.perDay, currency))}
        </div>

        <div className="form-grid">
          <Field label="Unpaid / absent days" hint={`Deduction ${money(f.attendance_deduction, currency)}`}>
            <input className="input" type="number" min={0} step={0.5} value={f.unpaid_days} disabled={locked} onChange={(e) => set({ unpaid_days: e.target.value })} />
          </Field>
          <Field label="Incentive">
            <input className="input" type="number" min={0} value={f.incentive} disabled={locked} onChange={(e) => set({ incentive: e.target.value })} />
          </Field>
          <Field label="Bonus / allowance">
            <input className="input" type="number" min={0} value={f.bonus} disabled={locked} onChange={(e) => set({ bonus: e.target.value })} />
          </Field>
          <Field label="Other deduction" hint="Advance, penalty, etc.">
            <input className="input" type="number" min={0} value={f.other_deduction} disabled={locked} onChange={(e) => set({ other_deduction: e.target.value })} />
          </Field>
          {!locked && (
            <Field label="Paid on">
              <input className="input" type="date" value={f.paid_on || ''} onChange={(e) => set({ paid_on: e.target.value })} />
            </Field>
          )}
          <Field label="Notes" className={locked ? 'span-2' : ''}>
            <input className="input" value={f.notes || ''} disabled={locked} onChange={(e) => set({ notes: e.target.value })} />
          </Field>
        </div>

        <div className="row-between" style={{ padding: '12px 16px', borderRadius: 'var(--r-md)', background: 'var(--brand-surface)', color: '#fff' }}>
          <span className="small" style={{ opacity: 0.7 }}>{locked ? `Paid on ${f.paid_on}` : 'Net pay'}</span>
          <span style={{ fontSize: 22, fontWeight: 700 }} className="tabular">{money(calcNet(f), currency)}</span>
        </div>
        {error && <Alert>{error}</Alert>}
      </div>
    </Modal>
  );
}

function SalaryModal({ open, people, salaries, currency, onClose, onSaved }) {
  const [values, setValues] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (open) {
      setError(null);
      setValues(Object.fromEntries(people.map((p) => [p.id, salaries[p.id]?.monthly_salary ?? ''])));
    }
  }, [open]);

  const save = async () => {
    setSaving(true);
    const rows = Object.entries(values)
      .filter(([id, v]) => v !== '' || salaries[id])
      .map(([employee_id, v]) => ({ employee_id, monthly_salary: Number(v) || 0 }));
    const { error: err } = await supabase.from('employee_salaries').upsert(rows, { onConflict: 'employee_id' });
    setSaving(false);
    if (err) return setError(cleanDbMessage(err));
    onSaved();
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Monthly salaries"
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save salaries</Button>
        </>
      }
    >
      <div className="stack-sm">
        <p className="small muted" style={{ margin: 0 }}>Gross monthly salary ({currency}). Only admins can see this.</p>
        {people.map((p) => (
          <div className="row-between" key={p.id}>
            <div className="row" style={{ minWidth: 0 }}>
              <Avatar name={p.full_name} size="sm" />
              <div style={{ minWidth: 0 }}>
                <div className="small strong truncate">{p.full_name}</div>
                <div className="xs muted">{p.designation || p.role}</div>
              </div>
            </div>
            <input
              className="input"
              style={{ width: 130, textAlign: 'right' }}
              type="number"
              min={0}
              inputMode="numeric"
              placeholder="0"
              value={values[p.id] ?? ''}
              onChange={(e) => setValues((v) => ({ ...v, [p.id]: e.target.value }))}
            />
          </div>
        ))}
        {error && <Alert>{error}</Alert>}
      </div>
    </Modal>
  );
}
