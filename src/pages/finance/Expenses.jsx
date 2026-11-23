import React, { useEffect, useState } from 'react';
import { format, parseISO } from 'date-fns';
import { Plus, Receipt, Repeat, Banknote, Info } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { friendlyError, cleanDbMessage } from '../../lib/hr';
import { money, monthRange, ymd } from '../../lib/format';
import { Card, Button, Badge, EmptyState, Alert, Loading, Modal, Field, Segmented, useConfirm } from '../../components/ui';
import { EXPENSE_CATEGORIES, PAYMENT_METHODS } from './shared';

export default function Expenses({ month, currency, toast, setTab }) {
  const [rows, setRows] = useState([]);
  const [salaries, setSalaries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [edit, setEdit] = useState(null);
  const [filter, setFilter] = useState('all');
  const { startStr, endStr } = monthRange(month);

  const load = async () => {
    setLoading(true);
    const [e, p, base] = await Promise.all([
      supabase.from('fin_expenses').select('*').gte('expense_date', startStr).lte('expense_date', endStr).order('expense_date', { ascending: false }),
      supabase.from('payroll_records').select('id, employee_id, net_pay, status, paid_on, profiles(full_name, designation)').eq('month', startStr),
      supabase.from('employee_salaries').select('employee_id, monthly_salary, profiles(full_name, designation, role, status)'),
    ]);
    setError(e.error ? friendlyError(e.error) : p.error ? friendlyError(p.error) : null);
    setRows(e.data || []);
    // Payroll records where calculated; otherwise each active employee's monthly salary as "expected"
    const calculated = p.data || [];
    const have = new Set(calculated.map((x) => x.employee_id));
    const expected = (base.data || [])
      .filter((x) => !have.has(x.employee_id) && Number(x.monthly_salary) > 0 && x.profiles && x.profiles.role !== 'admin' && x.profiles.status !== 'inactive')
      .map((x) => ({ id: `exp-${x.employee_id}`, employee_id: x.employee_id, net_pay: x.monthly_salary, status: 'expected', paid_on: null, profiles: x.profiles }));
    setSalaries([...calculated, ...expected]);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, [startStr]);

  const running = rows.reduce((s, r) => s + Number(r.amount), 0);
  const salaryPaid = salaries.filter((x) => x.status === 'paid').reduce((s, x) => s + Number(x.net_pay), 0);
  const salaryDue = salaries.filter((x) => x.status === 'draft').reduce((s, x) => s + Number(x.net_pay), 0);
  const salaryExpected = salaries.filter((x) => x.status === 'expected').reduce((s, x) => s + Number(x.net_pay), 0);
  const salaryTotal = salaryPaid + salaryDue + salaryExpected;
  const total = running + salaryTotal;
  const pct = (v) => (total > 0 ? `${(v / total) * 100}%` : '0%');

  const byCat = Object.entries(
    rows.reduce((m, r) => {
      m[r.category] = (m[r.category] || 0) + Number(r.amount);
      return m;
    }, salaryTotal > 0 ? { [SALARY_CATEGORY]: salaryTotal } : {}),
  ).sort((a, b) => b[1] - a[1]);

  // One combined, date-sorted list of running costs and salaries
  const items = [
    ...rows.map((r) => ({ kind: 'expense', id: r.id, date: r.expense_date, amount: Number(r.amount), row: r })),
    ...salaries.map((x) => ({
      kind: 'salary',
      id: x.id,
      date: x.paid_on || endStr,
      amount: Number(x.net_pay),
      row: x,
    })),
  ]
    .filter((i) => filter === 'all' || (filter === 'running' ? i.kind === 'expense' : i.kind === 'salary'))
    .sort((a, b) => b.date.localeCompare(a.date));

  const copyRecurring = async () => {
    const prevStart = ymd(new Date(month.getFullYear(), month.getMonth() - 1, 1));
    const prevEnd = ymd(new Date(month.getFullYear(), month.getMonth(), 0));
    const { data, error: err } = await supabase.from('fin_expenses').select('*').eq('is_recurring', true).gte('expense_date', prevStart).lte('expense_date', prevEnd);
    if (err) return toast(err.message, 'error');
    const existing = new Set(rows.filter((r) => r.is_recurring).map((r) => `${r.category}|${r.vendor}|${r.amount}`));
    const toAdd = (data || [])
      .filter((r) => !existing.has(`${r.category}|${r.vendor}|${r.amount}`))
      .map(({ id, created_at, expense_date, ...r }) => ({
        ...r,
        expense_date: ymd(new Date(month.getFullYear(), month.getMonth(), Math.min(28, parseISO(expense_date).getDate()))),
      }));
    if (!toAdd.length) return toast('No new recurring expenses to copy');
    const { error: e2 } = await supabase.from('fin_expenses').insert(toAdd);
    if (e2) return toast(e2.message, 'error');
    toast(`${toAdd.length} recurring expense${toAdd.length > 1 ? 's' : ''} added`);
    load();
  };

  return (
    <div className="stack">
      {error && <Alert>{error}</Alert>}

      {/* Summary */}
      <div className="hero">
        <div className="row-between wrap" style={{ alignItems: 'flex-start', gap: 16 }}>
          <div>
            <div className="muted small">Total spending · {format(month, 'MMMM yyyy')}</div>
            <div className="hero-value">{money(total, currency)}</div>
            <div className="muted small" style={{ marginTop: 4 }}>Running costs + salaries</div>
          </div>
          <div className="row wrap" style={{ gap: 8 }}>
            <Button size="sm" icon={Repeat} onClick={copyRecurring}>Copy monthly costs</Button>
            <Button size="sm" variant="primary" icon={Plus} onClick={() => setEdit({})}>Add expense</Button>
          </div>
        </div>
        <div className="split-bar" style={{ marginTop: 18 }}>
          <span style={{ width: pct(running), background: '#a78bfa' }} />
          <span style={{ width: pct(salaryPaid), background: 'var(--brand-lime)' }} />
          <span style={{ width: pct(salaryDue), background: 'rgba(124,181,24,0.55)' }} />
          <span style={{ width: pct(salaryExpected), background: 'rgba(255,255,255,0.35)' }} />
        </div>
        <div className="row wrap small" style={{ marginTop: 12, gap: 18 }}>
          <span><span className="legend-dot" style={{ background: '#a78bfa' }} />Running costs <strong className="tabular">{money(running, currency)}</strong></span>
          <span><span className="legend-dot" style={{ background: 'var(--brand-lime)' }} />Salaries paid <strong className="tabular">{money(salaryPaid, currency)}</strong></span>
          {salaryDue > 0 && (
            <span><span className="legend-dot" style={{ background: 'rgba(124,181,24,0.55)' }} />Salaries to pay <strong className="tabular">{money(salaryDue, currency)}</strong></span>
          )}
          {salaryExpected > 0 && (
            <span><span className="legend-dot" style={{ background: 'rgba(255,255,255,0.35)' }} />Salaries expected <strong className="tabular">{money(salaryExpected, currency)}</strong></span>
          )}
        </div>
      </div>

      {salaryExpected > 0 && !loading && (
        <Alert tone="blue" icon={Info}>
          “Expected” salaries are full monthly salaries. After you calculate payroll they are replaced with the actual amounts (after leave and attendance deductions).{' '}
          {setTab && <button type="button" className="link-btn" onClick={() => setTab('payroll')}>Open payroll</button>}
        </Alert>
      )}
      {salaries.length === 0 && !loading && (
        <Alert tone="blue" icon={Info}>
          Set monthly salaries in Payroll and they will appear here as part of your spending.{' '}
          {setTab && <button type="button" className="link-btn" onClick={() => setTab('payroll')}>Open payroll</button>}
        </Alert>
      )}

      <div className="grid-main-side">
        <Card
          title="All spending"
          pad={false}
          actions={
            <Segmented
              value={filter}
              onChange={setFilter}
              options={[
                { value: 'all', label: 'All' },
                { value: 'running', label: 'Running costs' },
                { value: 'salary', label: 'Salaries' },
              ]}
            />
          }
        >
          {loading ? (
            <Loading />
          ) : items.length === 0 ? (
            <EmptyState icon={Receipt} title="Nothing here yet" text={filter === 'salary' ? 'Calculate payroll to see salaries.' : 'Add rent, software, equipment and other costs.'} />
          ) : (
            <div className="list">
              {items.map((i) =>
                i.kind === 'expense' ? (
                  <div className="list-row" key={`e-${i.id}`} style={{ cursor: 'pointer' }} onClick={() => setEdit(i.row)}>
                    <span className="stat-icon" style={{ background: 'var(--violet-50)', color: 'var(--violet)' }}><Receipt size={16} /></span>
                    <div className="list-main">
                      <div className="row wrap" style={{ gap: 8 }}>
                        <span className="list-title">{i.row.vendor || i.row.category}</span>
                        {i.row.is_recurring && <Badge tone="violet">Monthly</Badge>}
                      </div>
                      <div className="list-sub">
                        {format(parseISO(i.date), 'dd MMM')} · {i.row.category}
                        {i.row.method ? ` · ${i.row.method}` : ''}
                        {i.row.description ? ` · ${i.row.description}` : ''}
                      </div>
                    </div>
                    <div className="list-end">
                      <span className="strong tabular">{money(i.amount, currency)}</span>
                    </div>
                  </div>
                ) : (
                  <div className="list-row" key={`s-${i.id}`} style={{ cursor: setTab ? 'pointer' : undefined }} onClick={() => setTab?.('payroll')}>
                    <span className="stat-icon" style={{ background: 'var(--brand-50)', color: 'var(--brand-600)' }}><Banknote size={16} /></span>
                    <div className="list-main">
                      <div className="row wrap" style={{ gap: 8 }}>
                        <span className="list-title">{i.row.profiles?.full_name || 'Employee'}</span>
                        <Badge tone={i.row.status === 'paid' ? 'green' : i.row.status === 'draft' ? 'amber' : 'gray'}>{i.row.status === 'paid' ? 'Paid' : i.row.status === 'draft' ? 'To pay' : 'Expected'}</Badge>
                      </div>
                      <div className="list-sub">
                        {i.row.status === 'paid' && i.row.paid_on ? format(parseISO(i.row.paid_on), 'dd MMM') : format(month, 'MMMM')} · Salary
                        {i.row.profiles?.designation ? ` · ${i.row.profiles.designation}` : ''}
                      </div>
                    </div>
                    <div className="list-end">
                      <span className="strong tabular">{money(i.amount, currency)}</span>
                    </div>
                  </div>
                ),
              )}
            </div>
          )}
        </Card>

        <Card title="Where the money went" subtitle={format(month, 'MMMM yyyy')}>
          {byCat.length === 0 ? (
            <div className="small muted">No spending recorded yet.</div>
          ) : (
            <div className="stack-sm">
              {byCat.map(([cat, v]) => (
                <div key={cat}>
                  <div className="row-between small" style={{ marginBottom: 6 }}>
                    <span className={cat === SALARY_CATEGORY ? 'strong' : ''}>{cat}</span>
                    <span className="tabular">
                      <strong>{money(v, currency)}</strong> <span className="muted xs">{total ? Math.round((v / total) * 100) : 0}%</span>
                    </span>
                  </div>
                  <div className="progress">
                    <span style={{ width: `${total ? (v / total) * 100 : 0}%`, background: cat === SALARY_CATEGORY ? 'var(--brand-lime)' : 'var(--violet)' }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      <ExpenseModal
        expense={edit}
        defaultDate={format(month, 'yyyy-MM') === format(new Date(), 'yyyy-MM') ? ymd(new Date()) : startStr}
        onClose={() => setEdit(null)}
        onSaved={(msg) => {
          setEdit(null);
          toast(msg);
          load();
        }}
      />
    </div>
  );
}

const SALARY_CATEGORY = 'Salaries & payroll';

function ExpenseModal({ expense, defaultDate, onClose, onSaved }) {
  const confirm = useConfirm();
  const isNew = expense && !expense.id;
  const [f, setF] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!expense) return;
    setError(null);
    setF({
      expense_date: expense.expense_date || defaultDate,
      category: expense.category || EXPENSE_CATEGORIES[0],
      vendor: expense.vendor || '',
      description: expense.description || '',
      amount: expense.amount ?? '',
      method: expense.method || 'UPI',
      is_recurring: expense.is_recurring || false,
    });
  }, [expense]);

  const set = (p) => setF((x) => ({ ...x, ...p }));

  const save = async () => {
    if (!(Number(f.amount) > 0)) return setError('Enter the amount.');
    setSaving(true);
    const payload = { ...f, amount: Number(f.amount), vendor: f.vendor || null, description: f.description || null };
    const res = isNew ? await supabase.from('fin_expenses').insert(payload) : await supabase.from('fin_expenses').update(payload).eq('id', expense.id);
    setSaving(false);
    if (res.error) return setError(cleanDbMessage(res.error));
    onSaved(isNew ? 'Expense added' : 'Expense updated');
  };

  const remove = async () => {
    if (!(await confirm({ title: 'Delete this expense?', message: `${expense.vendor || expense.category} · ${money(expense.amount)}. This cannot be undone.`, confirmLabel: 'Delete expense', danger: true }))) return;
    const { error: err } = await supabase.from('fin_expenses').delete().eq('id', expense.id);
    if (err) return setError(cleanDbMessage(err));
    onSaved('Expense deleted');
  };

  return (
    <Modal
      open={!!expense}
      onClose={onClose}
      title={isNew ? 'Add expense' : 'Edit expense'}
      footer={
        <>
          {!isNew && <Button variant="danger" onClick={remove} style={{ marginRight: 'auto' }}>Delete</Button>}
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Amount">
          <input className="input" type="number" min={0} inputMode="decimal" value={f.amount ?? ''} onChange={(e) => set({ amount: e.target.value })} autoFocus />
        </Field>
        <Field label="Date">
          <input className="input" type="date" value={f.expense_date || ''} onChange={(e) => set({ expense_date: e.target.value })} />
        </Field>
        <Field label="Category">
          <select className="select" value={f.category || ''} onChange={(e) => set({ category: e.target.value })}>
            {EXPENSE_CATEGORIES.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </Field>
        <Field label="Paid via">
          <select className="select" value={f.method || ''} onChange={(e) => set({ method: e.target.value })}>
            {PAYMENT_METHODS.map((m) => (
              <option key={m}>{m}</option>
            ))}
          </select>
        </Field>
        <Field label="Vendor / paid to" className="span-2">
          <input className="input" value={f.vendor || ''} onChange={(e) => set({ vendor: e.target.value })} placeholder="e.g. Adobe, landlord" />
        </Field>
        <Field label="Description" className="span-2">
          <input className="input" value={f.description || ''} onChange={(e) => set({ description: e.target.value })} />
        </Field>
        <label className="check span-2">
          <input type="checkbox" checked={!!f.is_recurring} onChange={(e) => set({ is_recurring: e.target.checked })} />
          Repeats every month
        </label>
      </div>
      {error && <div style={{ marginTop: 12 }}><Alert>{error}</Alert></div>}
    </Modal>
  );
}
