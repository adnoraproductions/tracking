import React, { useState } from 'react';
import { format, parseISO } from 'date-fns';
import { Plus, FileText, Pencil, Trash2, Wallet } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { money, monthRange } from '../../lib/format';
import { Card, Button, Segmented, EmptyState, useConfirm } from '../../components/ui';
import { InvoiceStateBadge, deleteInvoice } from './shared';

export default function Invoices({ ledger, month, currency, actions, reload, toast }) {
  const { clients, invoices, payments } = ledger;
  const confirm = useConfirm();
  const [view, setView] = useState('pending');
  const nameOf = (id) => clients.find((c) => c.id === id)?.name || '—';
  const { startStr, endStr } = monthRange(month);

  const remove = async (inv) => {
    try {
      if (!(await deleteInvoice(inv, payments, currency, confirm))) return;
      toast('Bill deleted');
      reload();
    } catch (e) {
      toast(e.message, 'error');
    }
  };

  let rows = [];
  if (view === 'pending') rows = invoices.filter((i) => i.balance > 0).sort((a, b) => a.due_date.localeCompare(b.due_date));
  if (view === 'month') rows = invoices.filter((i) => i.issue_date >= startStr && i.issue_date <= endStr);
  if (view === 'all') rows = invoices;

  const monthPayments = payments.filter((p) => p.paid_on >= startStr && p.paid_on <= endStr);
  const total = rows.reduce((s, i) => s + (view === 'pending' ? i.balance : Number(i.is_cancelled ? 0 : i.amount)), 0);

  return (
    <div className="stack">
      <div className="row-between wrap">
        <Segmented
          value={view}
          onChange={setView}
          options={[
            { value: 'pending', label: 'Pending' },
            { value: 'month', label: `Billed in ${format(month, 'MMM')}` },
            { value: 'all', label: 'All bills' },
            { value: 'payments', label: `Received in ${format(month, 'MMM')}` },
          ]}
        />
        <div className="row">
          <Button icon={Wallet} onClick={() => actions.addPayment()} disabled={!clients.length}>Record payment</Button>
          <Button variant="primary" icon={Plus} onClick={() => actions.addInvoice()} disabled={!clients.length}>New bill</Button>
        </div>
      </div>

      {view === 'payments' ? (
        <Card title="Payments received" subtitle={`${monthPayments.length} payments · ${money(monthPayments.reduce((s, p) => s + Number(p.amount), 0), currency)}`} pad={false}>
          {monthPayments.length === 0 ? (
            <EmptyState icon={Wallet} title="No payments recorded this month" />
          ) : (
            <div className="table-wrap">
              <table className="table responsive">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Client</th>
                    <th>For</th>
                    <th>Method</th>
                    <th className="num">Amount</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {monthPayments.map((p) => (
                    <tr key={p.id}>
                      <td data-label="Date">{format(parseISO(p.paid_on), 'dd MMM')}</td>
                      <td data-label="Client" className="strong">{nameOf(p.client_id)}</td>
                      <td data-label="For" className="muted">{invoices.find((i) => i.id === p.invoice_id)?.title || 'Advance'}</td>
                      <td data-label="Method">{p.method}{p.reference ? ` · ${p.reference}` : ''}</td>
                      <td data-label="Amount" className="num strong text-green">{money(p.amount, currency)}</td>
                      <td data-label="">
                        <button className="icon-btn" onClick={() => actions.editPayment(p)} aria-label="Edit payment"><Pencil size={15} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      ) : (
        <Card
          title={view === 'pending' ? 'Pending bills' : 'Bills'}
          subtitle={`${rows.length} bill${rows.length === 1 ? '' : 's'} · ${money(total, currency)}${view === 'pending' ? ' to collect' : ''}`}
          pad={false}
        >
          {rows.length === 0 ? (
            <EmptyState icon={FileText} title={view === 'pending' ? 'No pending bills' : 'No bills'} text={clients.length ? '' : 'Add a client first.'} />
          ) : (
            <div className="table-wrap">
              <table className="table responsive">
                <thead>
                  <tr>
                    <th>Client</th>
                    <th>Bill</th>
                    <th>Due</th>
                    <th className="num">Amount</th>
                    <th className="num">Received</th>
                    <th className="num">Balance</th>
                    <th>Status</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((i) => (
                    <tr key={i.id} style={i.is_cancelled ? { opacity: 0.5 } : undefined}>
                      <td data-label="Client" className="strong">{nameOf(i.client_id)}</td>
                      <td data-label="Bill">{i.title}</td>
                      <td data-label="Due">{format(parseISO(i.due_date), 'dd MMM yy')}</td>
                      <td data-label="Amount" className="num">{money(i.amount, currency)}</td>
                      <td data-label="Received" className="num muted">{money(i.paid, currency)}</td>
                      <td data-label="Balance" className="num strong">{money(i.balance, currency)}</td>
                      <td data-label="Status"><InvoiceStateBadge state={i.state} /></td>
                      <td data-label="">
                        <div className="row" style={{ justifyContent: 'flex-end', gap: 6 }}>
                          {i.balance > 0 && (
                            <Button size="sm" variant="primary" onClick={() => actions.addPayment({ client_id: i.client_id, invoice_id: i.id })}>
                              Mark paid
                            </Button>
                          )}
                          {!i.is_cancelled && (
                            <button className="icon-btn" onClick={() => actions.editInvoice(i)} aria-label="Edit bill" title="Edit bill"><Pencil size={15} /></button>
                          )}
                          <button className="icon-btn" onClick={() => remove(i)} aria-label="Delete bill" title="Delete bill"><Trash2 size={15} color="var(--red)" /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      )}
    </div>
  );
}
