import React, { useEffect, useState } from 'react';
import { addDays, format, parseISO, setDate, startOfMonth } from 'date-fns';
import { supabase } from '../../lib/supabase/client';
import { cleanDbMessage } from '../../lib/hr';
import { money, ymd } from '../../lib/format';
import { Button, Field, Alert, Modal, Badge, useConfirm } from '../../components/ui';

export const PAYMENT_METHODS = ['UPI', 'Bank transfer', 'Cash', 'Cheque', 'Card', 'Other'];
export const EXPENSE_CATEGORIES = ['Rent', 'Software & subscriptions', 'Equipment', 'Utilities & internet', 'Marketing', 'Travel', 'Food & refreshments', 'Freelancers', 'Taxes & fees', 'Miscellaneous'];

/** Load every client + invoice (with payments) — finance volumes are small. */
export async function loadLedger() {
  const [c, i, p] = await Promise.all([
    supabase.from('fin_clients').select('*').order('name'),
    supabase.from('fin_invoices').select('*').order('due_date', { ascending: false }),
    supabase.from('fin_payments').select('*').order('paid_on', { ascending: false }),
  ]);
  for (const r of [c, i, p]) if (r.error) throw r.error;
  const paidByInvoice = {};
  for (const pay of p.data || []) if (pay.invoice_id) paidByInvoice[pay.invoice_id] = (paidByInvoice[pay.invoice_id] || 0) + Number(pay.amount);
  const today = ymd(new Date());
  const invoices = (i.data || []).map((inv) => {
    const paid = paidByInvoice[inv.id] || 0;
    const balance = inv.is_cancelled ? 0 : Math.max(0, Number(inv.amount) - paid);
    let state = 'unpaid';
    if (inv.is_cancelled) state = 'cancelled';
    else if (balance <= 0.005) state = 'paid';
    else if (inv.due_date < today) state = 'overdue';
    else if (paid > 0) state = 'partial';
    return { ...inv, paid, balance, state };
  });
  return { clients: c.data || [], invoices, payments: p.data || [] };
}

export const INVOICE_STATE = {
  paid: { label: 'Paid', tone: 'green' },
  partial: { label: 'Part paid', tone: 'blue' },
  unpaid: { label: 'Due', tone: 'amber' },
  overdue: { label: 'Overdue', tone: 'red' },
  cancelled: { label: 'Cancelled', tone: 'gray' },
};

export function InvoiceStateBadge({ state }) {
  const s = INVOICE_STATE[state] || INVOICE_STATE.unpaid;
  return <Badge tone={s.tone}>{s.label}</Badge>;
}

/** The automatic monthly retainer bill for a period (clients can have other bills in the same month too). */
export function isRetainerBill(inv, period) {
  return inv.period_month === period && !inv.is_cancelled && /retainer/i.test(inv.title || '');
}

/** Create this month's bill for every active recurring client that doesn't have one yet. */
export async function generateRecurringInvoices(month, clients, invoices) {
  const period = ymd(startOfMonth(month));
  const existing = new Set(invoices.filter((i) => isRetainerBill(i, period)).map((i) => i.client_id));
  const rows = clients
    .filter((c) => c.is_active && c.client_type === 'recurring' && Number(c.monthly_fee) > 0 && !existing.has(c.id))
    .map((c) => {
      const issue = setDate(startOfMonth(month), Math.min(28, c.billing_day || 1));
      return {
        client_id: c.id,
        title: `${format(month, 'MMMM yyyy')} retainer`,
        period_month: period,
        issue_date: ymd(issue),
        due_date: ymd(addDays(issue, 7)),
        amount: Number(c.monthly_fee),
      };
    });
  if (rows.length === 0) return 0;
  const { error } = await supabase.from('fin_invoices').insert(rows);
  if (error) throw error;
  return rows.length;
}

/** Permanently delete a bill. Payments already recorded against it are kept as advance payments. */
export async function deleteInvoice(inv, payments, currency, confirm) {
  const linked = payments.filter((p) => p.invoice_id === inv.id);
  const total = linked.reduce((s, p) => s + Number(p.amount), 0);
  const msg =
    `"${inv.title}" · ${money(inv.amount, currency)}\nThis cannot be undone.` +
    (linked.length ? `\n\n${linked.length} payment${linked.length > 1 ? 's' : ''} recorded against it (${money(total, currency)}) will be kept as advance payment${linked.length > 1 ? 's' : ''} for this client.` : '');
  if (!(await confirm({ title: 'Delete this bill?', message: msg, confirmLabel: 'Delete bill', danger: true }))) return false;
  const { error } = await supabase.from('fin_invoices').delete().eq('id', inv.id);
  if (error) throw error;
  return true;
}

/* ---------------- Modals ---------------- */

export function ClientModal({ client, onClose, onSaved }) {
  const isNew = client && !client.id;
  const [f, setF] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!client) return;
    setError(null);
    setF({
      name: client.name || '',
      client_type: client.client_type || 'recurring',
      contact_person: client.contact_person || '',
      phone: client.phone || '',
      email: client.email || '',
      services: client.services || '',
      monthly_fee: client.monthly_fee ?? '',
      billing_day: client.billing_day || 1,
      start_date: client.start_date || '',
      is_active: client.is_active ?? true,
      notes: client.notes || '',
    });
  }, [client]);

  const set = (p) => setF((x) => ({ ...x, ...p }));

  const save = async () => {
    if (!f.name.trim()) return setError('Client name is required.');
    setSaving(true);
    const payload = {
      ...f,
      name: f.name.trim(),
      monthly_fee: Number(f.monthly_fee) || 0,
      billing_day: Math.min(28, Math.max(1, Number(f.billing_day) || 1)),
      start_date: f.start_date || null,
    };
    const res = isNew ? await supabase.from('fin_clients').insert(payload) : await supabase.from('fin_clients').update(payload).eq('id', client.id);
    setSaving(false);
    if (res.error) return setError(cleanDbMessage(res.error));
    onSaved(isNew ? 'Client added' : 'Client updated');
  };

  return (
    <Modal
      open={!!client}
      onClose={onClose}
      title={isNew ? 'Add client' : 'Edit client'}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Client / business name" className="span-2">
          <input className="input" value={f.name || ''} onChange={(e) => set({ name: e.target.value })} autoFocus />
        </Field>
        <Field label="Type" className="span-2">
          <div className="segmented full">
            {[
              ['recurring', 'Recurring (monthly)'],
              ['one_time', 'One-time project'],
            ].map(([v, l]) => (
              <button type="button" key={v} className={f.client_type === v ? 'active' : ''} onClick={() => set({ client_type: v })}>
                {l}
              </button>
            ))}
          </div>
        </Field>
        {f.client_type === 'recurring' && (
          <>
            <Field label="Monthly fee">
              <input className="input" type="number" min={0} inputMode="decimal" value={f.monthly_fee ?? ''} onChange={(e) => set({ monthly_fee: e.target.value })} />
            </Field>
            <Field label="Billing day" hint="Day of month the bill is raised (1–28)">
              <input className="input" type="number" min={1} max={28} value={f.billing_day ?? 1} onChange={(e) => set({ billing_day: e.target.value })} />
            </Field>
          </>
        )}
        <Field label="Contact person">
          <input className="input" value={f.contact_person || ''} onChange={(e) => set({ contact_person: e.target.value })} />
        </Field>
        <Field label="Phone">
          <input className="input" type="tel" value={f.phone || ''} onChange={(e) => set({ phone: e.target.value })} />
        </Field>
        <Field label="Email">
          <input className="input" type="email" value={f.email || ''} onChange={(e) => set({ email: e.target.value })} />
        </Field>
        <Field label="Client since">
          <input className="input" type="date" value={f.start_date || ''} onChange={(e) => set({ start_date: e.target.value })} />
        </Field>
        <Field label="Services" className="span-2">
          <input className="input" value={f.services || ''} onChange={(e) => set({ services: e.target.value })} placeholder="e.g. Social media, 12 posters + 4 reels / month" />
        </Field>
        <Field label="Notes" className="span-2">
          <textarea className="textarea" value={f.notes || ''} onChange={(e) => set({ notes: e.target.value })} />
        </Field>
        <label className="check span-2">
          <input type="checkbox" checked={!!f.is_active} onChange={(e) => set({ is_active: e.target.checked })} />
          Active client
        </label>
      </div>
      {error && <div style={{ marginTop: 12 }}><Alert>{error}</Alert></div>}
    </Modal>
  );
}

export function InvoiceModal({ invoice, clients, payments, currency, onClose, onSaved }) {
  const confirm = useConfirm();
  const isNew = invoice && !invoice.id;
  const [f, setF] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!invoice) return;
    setError(null);
    const today = ymd(new Date());
    setF({
      client_id: invoice.client_id || clients[0]?.id || '',
      title: invoice.title || '',
      period_month: invoice.period_month ? invoice.period_month.slice(0, 7) : '',
      issue_date: invoice.issue_date || today,
      due_date: invoice.due_date || ymd(addDays(new Date(), 7)),
      amount: invoice.amount ?? '',
      notes: invoice.notes || '',
    });
  }, [invoice]);

  const set = (p) => setF((x) => ({ ...x, ...p }));

  const save = async () => {
    if (!f.client_id) return setError('Choose a client.');
    if (!f.title.trim()) return setError('Add a short description.');
    if (!(Number(f.amount) >= 0) || f.amount === '') return setError('Enter the amount.');
    setSaving(true);
    const payload = {
      client_id: f.client_id,
      title: f.title.trim(),
      period_month: f.period_month ? `${f.period_month}-01` : null,
      issue_date: f.issue_date,
      due_date: f.due_date,
      amount: Number(f.amount),
      notes: f.notes || null,
    };
    const res = isNew ? await supabase.from('fin_invoices').insert(payload) : await supabase.from('fin_invoices').update(payload).eq('id', invoice.id);
    setSaving(false);
    if (res.error) {
      return setError(
        /duplicate key/i.test(res.error.message)
          ? 'The database still allows only one bill per client per month. Run migrations/002_multiple_bills_per_month.sql in the Supabase SQL editor, then try again.'
          : cleanDbMessage(res.error),
      );
    }
    onSaved(isNew ? 'Bill created' : 'Bill updated');
  };

  const remove = async () => {
    try {
      if (await deleteInvoice(invoice, payments, currency, confirm)) onSaved('Bill deleted');
    } catch (e) {
      setError(cleanDbMessage(e));
    }
  };

  return (
    <Modal
      open={!!invoice}
      onClose={onClose}
      title={isNew ? 'New bill' : 'Edit bill'}
      footer={
        <>
          {!isNew && <Button variant="danger" onClick={remove} style={{ marginRight: 'auto' }}>Delete</Button>}
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Client" className="span-2">
          <select className="select" value={f.client_id || ''} onChange={(e) => set({ client_id: e.target.value })}>
            {clients.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </Field>
        <Field label="Description" className="span-2">
          <input className="input" value={f.title || ''} onChange={(e) => set({ title: e.target.value })} placeholder="e.g. Logo + brand kit" />
        </Field>
        <Field label="Amount">
          <input className="input" type="number" min={0} inputMode="decimal" value={f.amount ?? ''} onChange={(e) => set({ amount: e.target.value })} />
        </Field>
        <Field label="For month" hint="Optional — which month this bill is for">
          <input className="input" type="month" value={f.period_month || ''} onChange={(e) => set({ period_month: e.target.value })} />
        </Field>
        <Field label="Bill date">
          <input className="input" type="date" value={f.issue_date || ''} onChange={(e) => set({ issue_date: e.target.value })} />
        </Field>
        <Field label="Due date">
          <input className="input" type="date" value={f.due_date || ''} onChange={(e) => set({ due_date: e.target.value })} />
        </Field>
        <Field label="Notes" className="span-2">
          <textarea className="textarea" value={f.notes || ''} onChange={(e) => set({ notes: e.target.value })} />
        </Field>
      </div>
      {error && <div style={{ marginTop: 12 }}><Alert>{error}</Alert></div>}
    </Modal>
  );
}

export function PaymentModal({ payment, clients, invoices, currency, onClose, onSaved }) {
  const confirm = useConfirm();
  const isNew = payment && !payment.id;
  const [f, setF] = useState({});
  const [mode, setMode] = useState('full'); // 'full' | 'part' (only when linked to a bill)
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  // What is still due on a bill, ignoring this payment itself when editing it
  const dueOn = (inv) => (inv ? Math.max(0, inv.balance + (payment?.id && payment.invoice_id === inv.id ? Number(payment.amount) : 0)) : 0);

  useEffect(() => {
    if (!payment) return;
    setError(null);
    const inv = invoices.find((i) => i.id === payment.invoice_id);
    setMode(inv && payment.amount != null && Number(payment.amount) < dueOn(inv) ? 'part' : 'full');
    setF({
      client_id: payment.client_id || inv?.client_id || clients[0]?.id || '',
      invoice_id: payment.invoice_id || '',
      amount: payment.amount ?? (inv ? inv.balance : ''),
      paid_on: payment.paid_on || ymd(new Date()),
      method: payment.method || 'UPI',
      reference: payment.reference || '',
      notes: payment.notes || '',
    });
  }, [payment]);

  const set = (p) => setF((x) => ({ ...x, ...p }));
  const bill = invoices.find((i) => i.id === f.invoice_id);
  const due = dueOn(bill);
  const after = bill ? Math.max(0, due - (Number(f.amount) || 0)) : 0;

  const chooseMode = (m) => {
    setMode(m);
    setError(null);
    set({ amount: m === 'full' ? due : '' });
  };
  const openInvoices = invoices.filter((i) => i.client_id === f.client_id && !i.is_cancelled && (i.balance > 0 || i.id === payment?.invoice_id));

  const save = async () => {
    if (!f.client_id) return setError('Choose a client.');
    if (!(Number(f.amount) > 0)) return setError('Enter the amount received.');
    if (bill && Number(f.amount) > due + 0.5) {
      return setError(`That is more than the ${money(due, currency)} still due on this bill. Record the extra separately as an advance.`);
    }
    setSaving(true);
    const payload = {
      client_id: f.client_id,
      invoice_id: f.invoice_id || null,
      amount: Number(f.amount),
      paid_on: f.paid_on,
      method: f.method,
      reference: f.reference || null,
      notes: f.notes || null,
    };
    const res = isNew ? await supabase.from('fin_payments').insert(payload) : await supabase.from('fin_payments').update(payload).eq('id', payment.id);
    setSaving(false);
    if (res.error) return setError(cleanDbMessage(res.error));
    const msg = !bill
      ? 'Payment recorded'
      : after > 0.5
        ? `Part payment recorded · ${money(after, currency)} still pending`
        : 'Bill marked as fully paid';
    onSaved(isNew ? msg : 'Payment updated');
  };

  const remove = async () => {
    if (!(await confirm({ title: 'Delete this payment?', message: `${money(payment.amount, currency)} received on ${payment.paid_on}. This cannot be undone.`, confirmLabel: 'Delete payment', danger: true }))) return;
    const { error: err } = await supabase.from('fin_payments').delete().eq('id', payment.id);
    if (err) return setError(cleanDbMessage(err));
    onSaved('Payment deleted');
  };

  return (
    <Modal
      open={!!payment}
      onClose={onClose}
      title={isNew ? (bill ? 'Mark bill as paid' : 'Record payment received') : 'Edit payment'}
      footer={
        <>
          {!isNew && <Button variant="danger" onClick={remove} style={{ marginRight: 'auto' }}>Delete</Button>}
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={save}>Save</Button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Client" className="span-2">
          <select className="select" value={f.client_id || ''} onChange={(e) => set({ client_id: e.target.value, invoice_id: '' })}>
            {clients.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </Field>
        <Field label="Against bill" className="span-2" hint="Pick the pending bill this payment clears (oldest first is usual).">
          <select
            className="select"
            value={f.invoice_id || ''}
            onChange={(e) => {
              const inv = invoices.find((i) => i.id === e.target.value);
              setMode('full');
              set({ invoice_id: e.target.value, ...(inv ? { amount: dueOn(inv) } : {}) });
            }}
          >
            <option value="">— Advance / not linked to a bill —</option>
            {openInvoices
              .slice()
              .sort((a, b) => a.due_date.localeCompare(b.due_date))
              .map((i) => (
                <option key={i.id} value={i.id}>
                  {i.title} · {format(parseISO(i.due_date), 'dd MMM yy')} · {money(i.balance, currency)} due
                </option>
              ))}
          </select>
        </Field>
        {bill && (
          <div className="span-2 stack-sm">
            <div className="card card-pad" style={{ background: 'var(--surface-2)', boxShadow: 'none', padding: 14 }}>
              <div className="row-between small"><span className="muted">Bill amount</span><span className="tabular">{money(bill.amount, currency)}</span></div>
              <div className="row-between small" style={{ marginTop: 4 }}><span className="muted">Already received</span><span className="tabular">{money(Number(bill.amount) - due, currency)}</span></div>
              <div className="row-between small" style={{ marginTop: 4 }}><span className="strong">Balance due</span><span className="strong tabular">{money(due, currency)}</span></div>
            </div>
            <div className="segmented full">
              <button type="button" className={mode === 'full' ? 'active' : ''} onClick={() => chooseMode('full')}>Full payment</button>
              <button type="button" className={mode === 'part' ? 'active' : ''} onClick={() => chooseMode('part')}>Part payment</button>
            </div>
          </div>
        )}
        <Field
          label={bill && mode === 'part' ? 'Amount received now' : 'Amount received'}
          hint={
            bill && f.amount !== '' && Number(f.amount) > 0
              ? after > 0.5
                ? `${money(after, currency)} will stay pending on this bill`
                : 'This clears the bill completely'
              : undefined
          }
        >
          <input
            className="input"
            type="number"
            min={0}
            inputMode="decimal"
            value={f.amount ?? ''}
            readOnly={!!bill && mode === 'full'}
            style={bill && mode === 'full' ? { background: 'var(--surface-2)' } : undefined}
            autoFocus={!!bill && mode === 'part'}
            key={mode}
            placeholder={bill && mode === 'part' ? 'e.g. 5000' : undefined}
            onChange={(e) => set({ amount: e.target.value })}
          />
        </Field>
        <Field label="Date received">
          <input className="input" type="date" value={f.paid_on || ''} onChange={(e) => set({ paid_on: e.target.value })} />
        </Field>
        <Field label="Method">
          <select className="select" value={f.method || ''} onChange={(e) => set({ method: e.target.value })}>
            {PAYMENT_METHODS.map((m) => (
              <option key={m}>{m}</option>
            ))}
          </select>
        </Field>
        <Field label="Reference / UTR">
          <input className="input" value={f.reference || ''} onChange={(e) => set({ reference: e.target.value })} />
        </Field>
        <Field label="Notes" className="span-2">
          <input className="input" value={f.notes || ''} onChange={(e) => set({ notes: e.target.value })} />
        </Field>
      </div>
      {error && <div style={{ marginTop: 12 }}><Alert>{error}</Alert></div>}
    </Modal>
  );
}
