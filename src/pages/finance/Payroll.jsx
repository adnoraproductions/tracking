import React, { useEffect, useMemo, useState } from 'react';
import { eachDayOfInterval, endOfMonth, format, isAfter, startOfDay } from 'date-fns';
import { Banknote, Settings2, RefreshCw, Download, CheckCircle2, Info, Check, TrendingDown, TrendingUp } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { friendlyError, cleanDbMessage } from '../../lib/hr';
import { fetchPlans, fetchAssignments, fetchBonuses, incentivePayout } from '../../lib/incentives';
import { money, monthRange, round1, ymd } from '../../lib/format';
import { Card, Button, Badge, TierBadge, EmptyState, Alert, Loading, Modal, Field, Avatar, useConfirm } from '../../components/ui';

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
  const confirm = useConfirm();
  const { start, startStr, endStr } = monthRange(month);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const [p, sal, att, lv, tk, hol, rec, plans, assigned, bonuses] = await Promise.all([
        supabase.from('profiles').select('id, full_name, employee_code, designation, role, status').order('full_name'),
        supabase.from('employee_salaries').select('*'),
        supabase.from('attendance_days').select('employee_id, date, status').gte('date', startStr).lte('date', endStr),
        supabase.from('leave_requests').select('employee_id, paid_days, unpaid_days, start_date').eq('status', 'approved').gte('start_date', startStr).lte('start_date', endStr),
        supabase.from('daily_tasks').select('employee_id, points_awarded').eq('status', 'approved').gte('task_date', startStr).lte('task_date', endStr),
        supabase.from('holidays').select('date').gte('date', startStr).lte('date', endStr),
        supabase.from('payroll_records').select('*').eq('month', startStr),
        fetchPlans().catch(() => []),
        fetchAssignments().catch(() => ({})),
        fetchBonuses(),
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
        plans: Object.fromEntries(plans.map((pl) => [pl.id, pl])),
        assigned,
        bonuses,
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
      .filter((p) => (p.status !== 'inactive' && p.role !== 'admin') || data.records[p.id])
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
        const plan = data.plans[data.assigned[p.id]] || null;
        const pay = incentivePayout(points, plan, plan ? data.bonuses[plan.id] : null);
        const tier = { level: pay.level.level, name: pay.level.hasPlan ? pay.level.name : '—', top: pay.level.inBonus, earns: pay.total > 0 };
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
          incentive: pay.total,
          bonus: Number(existing?.bonus || 0),
          other_deduction: Number(existing?.other_deduction || 0),
          notes: existing?.notes || null,
          status: 'draft',
        };
        computed.net_pay = calcNet(computed);
        const shown = existing || computed;
        return { person: p, salary, tier, pay, plan, computed, record: existing, shown, perDay };
      });
  }, [data, settings, startStr]);

  const payable = rows.filter((r) => r.salary > 0 || r.record);
  const totals = payable.reduce(
    (s, r) => {
      const v = r.shown;
      s.base += Number(v.base_salary);
      s.net += Number(v.net_pay);
      if (r.record?.status === 'paid') {
        s.paid += Number(r.record.net_pay);
        s.paidCount += 1;
      }
      if (r.record) s.savedCount += 1;
      s.minus += Number(v.attendance_deduction) + Number(v.other_deduction);
      s.plus += Number(v.incentive) + Number(v.bonus);
      return s;
    },
    { base: 0, net: 0, paid: 0, paidCount: 0, savedCount: 0, minus: 0, plus: 0 },
  );
  const remaining = Math.max(0, totals.net - totals.paid);

  const generate = async () => {
    const toSave = payable.filter((r) => r.record?.status !== 'paid').map((r) => r.computed);
    if (!toSave.length) return toast('Everyone is already paid for this month');
    setBusy('calc');
    const { error: err } = await supabase.from('payroll_records').upsert(toSave, { onConflict: 'employee_id,month' });
    setBusy(false);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast(`Payroll calculated for ${toSave.length} employee${toSave.length > 1 ? 's' : ''}`);
    load();
  };

  // Mark one or more people as paid today (uses their saved draft if any, otherwise the calculation)
  const markPaid = async (list) => {
    const rowsToPay = list.filter((r) => r.record?.status !== 'paid');
    if (!rowsToPay.length) return;
    const total = rowsToPay.reduce((s, r) => s + Number(r.shown.net_pay), 0);
    const ok = await confirm({
      title: rowsToPay.length > 1 ? `Pay ${rowsToPay.length} employees?` : `Pay ${rowsToPay[0].person.full_name}?`,
      message: `${money(total, currency)} will be marked as paid today (${format(new Date(), 'dd MMM yyyy')}). It will also count in this month's expenses.`,
      confirmLabel: 'Mark as paid',
    });
    if (!ok) return;
    setBusy('pay');
    const payload = rowsToPay.map((r) => {
      const { id, created_at, updated_at, ...base } = r.record || r.computed;
      return { ...base, status: 'paid', paid_on: ymd(new Date()), net_pay: calcNet(base) };
    });
    const { error: err } = await supabase.from('payroll_records').upsert(payload, { onConflict: 'employee_id,month' });
    setBusy(false);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast(rowsToPay.length > 1 ? `${rowsToPay.length} salaries marked as paid` : 'Salary marked as paid');
    load();
  };

  const exportCsv = () => {
    const header = ['Employee', 'Code', 'Base salary', 'Working days', 'Present', 'Paid leave', 'Unpaid days', 'Attendance deduction', 'Points', 'Tier', 'Incentive', 'Bonus', 'Other deduction', 'Net pay', 'Status', 'Paid on'];
    const lines = payable.map((r) => {
      const s = r.shown;
      return [r.person.full_name, r.person.employee_code || '', s.base_salary, s.working_days, s.present_days, s.paid_leave_days, s.unpaid_days, s.attendance_deduction, s.points, s.tier, s.incentive, s.bonus, s.other_deduction, s.net_pay, r.record?.status || 'not saved', r.record?.paid_on || '']
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
  const missingSalary = rows.filter((r) => r.salary === 0 && !r.record);
  const staffCount = rows.length;
  const salariesSet = staffCount - missingSalary.length;
  const paidPct = totals.net > 0 ? Math.min(100, (totals.paid / totals.net) * 100) : 0;
  const unpaidRows = payable.filter((r) => r.record?.status !== 'paid');

  const steps = [
    { n: 1, label: 'Salaries set', detail: `${salariesSet}/${staffCount}`, done: staffCount > 0 && missingSalary.length === 0, action: () => setSalaryOpen(true) },
    { n: 2, label: 'Calculated', detail: `${totals.savedCount}/${payable.length}`, done: payable.length > 0 && totals.savedCount === payable.length, action: generate },
    { n: 3, label: 'Paid', detail: `${totals.paidCount}/${payable.length}`, done: payable.length > 0 && totals.paidCount === payable.length },
  ];

  return (
    <div className="stack">
      {/* Summary */}
      <div className="hero">
        <div className="row-between wrap" style={{ alignItems: 'flex-start', gap: 16 }}>
          <div>
            <div className="muted small">Net payroll · {format(month, 'MMMM yyyy')}</div>
            <div className="hero-value">{money(totals.net, currency)}</div>
            <div className="muted small" style={{ marginTop: 4 }}>
              {payable.length} employee{payable.length === 1 ? '' : 's'} · base {money(totals.base, currency)}
            </div>
          </div>
          <div className="payroll-split">
            <div>
              <div className="muted xs">Paid</div>
              <div className="strong tabular" style={{ color: '#a3d64a' }}>{money(totals.paid, currency)}</div>
            </div>
            <div>
              <div className="muted xs">To pay</div>
              <div className="strong tabular">{money(remaining, currency)}</div>
            </div>
          </div>
        </div>
        <div className="progress" style={{ marginTop: 18, background: 'rgba(255,255,255,0.12)' }}>
          <span style={{ width: `${paidPct}%`, background: 'var(--brand-lime)' }} />
        </div>
        <div className="row wrap" style={{ marginTop: 16, gap: 8 }}>
          <span className="hero-chip"><TrendingDown size={13} /> Deductions −{money(totals.minus, currency)}</span>
          <span className="hero-chip"><TrendingUp size={13} /> Incentives &amp; bonus +{money(totals.plus, currency)}</span>
        </div>
      </div>

      {/* Steps */}
      <div className="steps">
        {steps.map((st) => (
          <button key={st.n} type="button" className={`step ${st.done ? 'done' : ''}`} onClick={st.action} disabled={!st.action}>
            <span className="step-num">{st.done ? <Check size={14} /> : st.n}</span>
            <span>
              <span className="step-label">{st.label}</span>
              <span className="step-detail">{st.detail}</span>
            </span>
          </button>
        ))}
      </div>

      {isCurrent && (
        <Alert tone="blue" icon={Info}>
          {format(month, 'MMMM')} is still running, so absences are counted only up to today. Calculate the final payroll after the month ends.
        </Alert>
      )}
      {missingSalary.length > 0 && (
        <Alert tone="amber" icon={Info}>
          No salary set for {missingSalary.map((r) => r.person.full_name).join(', ')}.{' '}
          <button type="button" className="link-btn" onClick={() => setSalaryOpen(true)}>Set salaries</button>
        </Alert>
      )}

      <Card
        title="Employees"
        subtitle="Tap a row to review the payslip, adjust bonus or deductions, or reopen it"
        pad={false}
        actions={
          <>
            <Button size="sm" icon={Settings2} onClick={() => setSalaryOpen(true)}>Salaries</Button>
            <Button size="sm" icon={Download} onClick={exportCsv} disabled={!payable.length}>CSV</Button>
            <Button size="sm" icon={RefreshCw} loading={busy === 'calc'} onClick={generate}>Calculate</Button>
            {unpaidRows.length > 0 && (
              <Button size="sm" variant="primary" icon={CheckCircle2} loading={busy === 'pay'} onClick={() => markPaid(unpaidRows)}>
                Pay all
              </Button>
            )}
          </>
        }
      >
        {payable.length === 0 ? (
          <EmptyState icon={Banknote} title="No salaries set up" text="Add monthly salaries for your team to start running payroll." action={<Button variant="primary" onClick={() => setSalaryOpen(true)}>Set salaries</Button>} />
        ) : (
          <div className="table-wrap">
            <table className="table responsive payroll-table">
              <thead>
                <tr>
                  <th>Employee</th>
                  <th>Attendance</th>
                  <th className="num">Salary</th>
                  <th className="num">Adjustments</th>
                  <th className="num">Net pay</th>
                  <th style={{ textAlign: 'right' }}>Status</th>
                </tr>
              </thead>
              <tbody>
                {payable.map((r) => {
                  const s = r.shown;
                  const minus = Number(s.attendance_deduction) + Number(s.other_deduction);
                  const plus = Number(s.incentive) + Number(s.bonus);
                  const paid = r.record?.status === 'paid';
                  return (
                    <tr key={r.person.id} onClick={() => setEdit(r)} style={{ cursor: 'pointer' }}>
                      <td data-label="">
                        <div className="row">
                          <Avatar name={r.person.full_name} size="sm" />
                          <div style={{ textAlign: 'left', minWidth: 0 }}>
                            <div className="strong truncate">{r.person.full_name}</div>
                            <div className="row" style={{ gap: 6, marginTop: 2 }}>
                              <span className="xs muted truncate">{r.person.designation || r.person.employee_code || ''}</span>
                              {r.tier.earns && <TierBadge tier={{ level: r.tier.level, name: s.tier || r.tier.name }} />}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td data-label="Attendance">
                        <div className="small">{round1(s.present_days)}/{round1(s.working_days)} days</div>
                        <div className="xs muted">
                          {Number(s.paid_leave_days) > 0 && `${round1(s.paid_leave_days)} paid leave · `}
                          <span className={Number(s.unpaid_days) > 0 ? 'text-red' : ''}>{round1(s.unpaid_days)} unpaid</span>
                        </div>
                      </td>
                      <td data-label="Salary" className="num">{money(s.base_salary, currency)}</td>
                      <td data-label="Adjustments" className="num">
                        {minus === 0 && plus === 0 ? (
                          <span className="muted">—</span>
                        ) : (
                          <div className="stack-xs">
                            {minus > 0 && <span className="text-red">−{money(minus, currency)}</span>}
                            {plus > 0 && <span className="text-green">+{money(plus, currency)}</span>}
                          </div>
                        )}
                      </td>
                      <td data-label="Net pay" className="num strong">{money(s.net_pay, currency)}</td>
                      <td data-label="Status" style={{ textAlign: 'right' }} onClick={(e) => !paid && e.stopPropagation()}>
                        {paid ? (
                          <Badge tone="green"><Check size={12} /> Paid {r.record.paid_on ? format(new Date(`${r.record.paid_on}T00:00:00`), 'dd MMM') : ''}</Badge>
                        ) : (
                          <Button size="sm" variant="primary" disabled={!!busy} onClick={() => markPaid([r])}>Pay</Button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr>
                  <td data-label="" className="strong">Total</td>
                  <td data-label="" />
                  <td data-label="Salary" className="num">{money(totals.base, currency)}</td>
                  <td data-label="Adjustments" className="num">
                    <span className="text-red">−{money(totals.minus, currency)}</span> <span className="text-green">+{money(totals.plus, currency)}</span>
                  </td>
                  <td data-label="Net pay" className="num strong">{money(totals.net, currency)}</td>
                  <td data-label="" />
                </tr>
              </tfoot>
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
        people={(data?.people || []).filter((p) => p.status !== 'inactive' && p.role !== 'admin')}
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
          {line('Incentive plan', row.plan?.name || 'Not assigned')}
          {row.pay && row.pay.total > 0 && line('Level incentive', money(row.pay.slab, currency))}
          {row.pay && row.pay.bonus > 0 && line(`Bonus beyond top level (${row.pay.bonusUnits}×)`, money(row.pay.bonus, currency))}
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
