import React, { useEffect, useState } from 'react';
import { format, parseISO } from 'date-fns';
import { Plus, Receipt, Pencil, Repeat } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { friendlyError, cleanDbMessage } from '../../lib/hr';
import { money, monthRange, ymd } from '../../lib/format';
import { Card, Button, Badge, EmptyState, Alert, Loading, Modal, Field, useConfirm } from '../../components/ui';
import { EXPENSE_CATEGORIES, PAYMENT_METHODS } from './shared';

export default function Expenses({ month, currency, toast }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [edit, setEdit] = useState(null);
  const { startStr, endStr } = monthRange(month);

  const load = async () => {
    setLoading(true);
    const { data, error: err } = await supabase
      .from('fin_expenses')
      .select('*')
      .gte('expense_date', startStr)
      .lte('expense_date', endStr)
      .order('expense_date', { ascending: false });
    setError(err ? friendlyError(err) : null);
    setRows(data || []);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, [startStr]);

  const total = rows.reduce((s, r) => s + Number(r.amount), 0);
  const byCat = Object.entries(
    rows.reduce((m, r) => {
      m[r.category] = (m[r.category] || 0) + Number(r.amount);
      return m;
    }, {}),
  ).sort((a, b) => b[1] - a[1]);

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
      <div className="grid-2">
        <Card title={`Expenses · ${format(month, 'MMMM yyyy')}`} subtitle="Rent, software, equipment and other running costs">
          <div className="hero-value" style={{ fontSize: 30 }}>{money(total, currency)}</div>
          <div className="small muted" style={{ marginTop: 4 }}>{rows.length} entries · payroll is tracked separately</div>
          <div className="row wrap" style={{ marginTop: 16 }}>
            <Button variant="primary" icon={Plus} onClick={() => setEdit({})}>Add expense</Button>
            <Button icon={Repeat} onClick={copyRecurring}>Copy recurring from last month</Button>
          </div>
        </Card>
        <Card title="By category">
          {byCat.length === 0 ? (
            <div className="small muted">No expenses yet.</div>
          ) : (
            <div className="stack-sm">
              {byCat.map(([cat, v]) => (
                <div key={cat}>
                  <div className="row-between small" style={{ marginBottom: 6 }}>
                    <span>{cat}</span>
                    <span className="strong tabular">{money(v, currency)}</span>
                  </div>
                  <div className="progress">
                    <span style={{ width: `${(v / total) * 100}%`, background: 'var(--violet)' }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      <Card title="All expenses" pad={false}>
        {loading ? (
          <Loading />
        ) : rows.length === 0 ? (
          <EmptyState icon={Receipt} title="No expenses this month" />
        ) : (
          <div className="list">
            {rows.map((r) => (
              <div className="list-row" key={r.id}>
                <div className="list-main">
                  <div className="row wrap" style={{ gap: 8 }}>
                    <span className="list-title">{r.vendor || r.category}</span>
                    <Badge>{r.category}</Badge>
                    {r.is_recurring && <Badge tone="violet">Monthly</Badge>}
                  </div>
                  <div className="list-sub">
                    {format(parseISO(r.expense_date), 'dd MMM')}
                    {r.method ? ` · ${r.method}` : ''}
                    {r.description ? ` · ${r.description}` : ''}
                  </div>
                </div>
                <div className="list-end">
                  <span className="strong tabular">{money(r.amount, currency)}</span>
                  <button className="icon-btn" onClick={() => setEdit(r)} aria-label="Edit expense"><Pencil size={15} /></button>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

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
