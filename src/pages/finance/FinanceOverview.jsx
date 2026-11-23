import React, { useEffect, useMemo, useState } from 'react';
import { format, parseISO, startOfMonth, subMonths } from 'date-fns';
import { ArrowDownLeft, ArrowUpRight, Hourglass, AlertTriangle, Users, Wallet, Repeat, Plus } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';
import { money, monthRange, ymd } from '../../lib/format';
import { Card, Stat, Button, EmptyState, Avatar } from '../../components/ui';
import { generateRecurringInvoices, isRetainerBill } from './shared';

export default function FinanceOverview({ ledger, month, currency, reload, actions, toast, setTab }) {
  const { clients, invoices, payments } = ledger;
  const { startStr, endStr } = monthRange(month);
  const [spend, setSpend] = useState({ expenses: 0, payroll: 0 });
  const [generating, setGenerating] = useState(false);

  useEffect(() => {
    (async () => {
      const [e, p] = await Promise.all([
        supabase.from('fin_expenses').select('amount').gte('expense_date', startStr).lte('expense_date', endStr),
        supabase.from('payroll_records').select('net_pay').eq('month', startStr),
      ]);
      setSpend({
        expenses: (e.data || []).reduce((s, x) => s + Number(x.amount), 0),
        payroll: (p.data || []).reduce((s, x) => s + Number(x.net_pay), 0),
      });
    })();
  }, [startStr]);

  const received = payments.filter((p) => p.paid_on >= startStr && p.paid_on <= endStr).reduce((s, p) => s + Number(p.amount), 0);
  const billed = invoices.filter((i) => !i.is_cancelled && i.issue_date >= startStr && i.issue_date <= endStr).reduce((s, i) => s + Number(i.amount), 0);
  const open = invoices.filter((i) => i.balance > 0);
  const outstanding = open.reduce((s, i) => s + i.balance, 0);
  const overdue = open.filter((i) => i.state === 'overdue').reduce((s, i) => s + i.balance, 0);
  const net = received - spend.expenses - spend.payroll;

  // Aging: this month / last month / older (by bill date)
  const thisM = ymd(startOfMonth(new Date()));
  const lastM = ymd(startOfMonth(subMonths(new Date(), 1)));
  const aging = { current: 0, last: 0, older: 0 };
  for (const i of open) {
    if (i.issue_date >= thisM) aging.current += i.balance;
    else if (i.issue_date >= lastM) aging.last += i.balance;
    else aging.older += i.balance;
  }

  const byClient = useMemo(() => {
    const m = {};
    for (const i of open) {
      const r = (m[i.client_id] ||= { balance: 0, count: 0, oldest: i.due_date });
      r.balance += i.balance;
      r.count += 1;
      if (i.due_date < r.oldest) r.oldest = i.due_date;
    }
    return Object.entries(m)
      .map(([id, r]) => ({ client: clients.find((c) => c.id === id), ...r }))
      .filter((r) => r.client)
      .sort((a, b) => b.balance - a.balance);
  }, [open, clients]);

  const period = ymd(month);
  const recurring = clients.filter((c) => c.is_active && c.client_type === 'recurring' && Number(c.monthly_fee) > 0);
  const missing = recurring.filter((c) => !invoices.some((i) => i.client_id === c.id && isRetainerBill(i, period)));
  const mrr = recurring.reduce((s, c) => s + Number(c.monthly_fee), 0);

  const generate = async () => {
    setGenerating(true);
    try {
      const n = await generateRecurringInvoices(month, clients, invoices);
      toast(n ? `${n} monthly bill${n > 1 ? 's' : ''} created` : 'All monthly bills already exist');
      reload();
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setGenerating(false);
    }
  };

  const m = format(month, 'MMMM');

  return (
    <div className="stack">
      <div className="grid-stats">
        <Stat label={`Received in ${m}`} value={money(received, currency)} sub={`Billed ${money(billed, currency)}`} icon={ArrowDownLeft} tone="green" />
        <Stat label="Pending from clients" value={money(outstanding, currency)} sub={`${open.length} open bill${open.length === 1 ? '' : 's'}`} icon={Hourglass} tone="amber" />
        <Stat label="Overdue" value={money(overdue, currency)} sub="Past due date" icon={AlertTriangle} tone="red" />
        <Stat label={`Spent in ${m}`} value={money(spend.expenses + spend.payroll, currency)} sub={`Expenses ${money(spend.expenses, currency)} · Payroll ${money(spend.payroll, currency)}`} icon={ArrowUpRight} tone="violet" />
      </div>

      <div className="hero">
        <div className="row-between wrap" style={{ alignItems: 'flex-start' }}>
          <div>
            <div className="muted small">Net cash flow · {format(month, 'MMMM yyyy')}</div>
            <div className="hero-value" style={{ color: net < 0 ? '#fda29b' : '#fff' }}>{money(net, currency)}</div>
            <div className="muted small" style={{ marginTop: 4 }}>Received − expenses − payroll</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="muted small">Monthly recurring revenue</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{money(mrr, currency)}</div>
            <div className="muted xs">{recurring.length} retainer client{recurring.length === 1 ? '' : 's'}</div>
          </div>
        </div>
      </div>

      {missing.length > 0 && (
        <Card pad>
          <div className="row-between wrap">
            <div className="row">
              <span className="stat-icon" style={{ background: 'var(--blue-50)', color: 'var(--blue)' }}><Repeat size={16} /></span>
              <div>
                <div className="strong small">{missing.length} retainer bill{missing.length > 1 ? 's' : ''} not raised for {format(month, 'MMMM')}</div>
                <div className="xs muted">{missing.map((c) => c.name).join(', ')}</div>
              </div>
            </div>
            <Button variant="dark" size="sm" loading={generating} onClick={generate}>Create {format(month, 'MMM')} bills</Button>
          </div>
        </Card>
      )}

      <div className="grid-2">
        <Card title="Pending by age" subtitle="Unpaid balance grouped by bill date">
          <div className="stack-sm">
            {[
              ['This month', aging.current, 'var(--brand)'],
              ['Last month', aging.last, 'var(--amber)'],
              ['Older than last month', aging.older, 'var(--red)'],
            ].map(([label, v, color]) => (
              <div key={label}>
                <div className="row-between small" style={{ marginBottom: 6 }}>
                  <span>{label}</span>
                  <span className="strong tabular">{money(v, currency)}</span>
                </div>
                <div className="progress">
                  <span style={{ width: `${outstanding ? (v / outstanding) * 100 : 0}%`, background: color }} />
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card
          title="Who owes what"
          pad={false}
          actions={<Button size="sm" icon={Plus} onClick={() => actions.addPayment()}>Record payment</Button>}
        >
          {byClient.length === 0 ? (
            <EmptyState icon={Wallet} title="Nothing pending" text="All bills are paid." />
          ) : (
            <div className="list">
              {byClient.slice(0, 8).map((r) => (
                <div className="list-row" key={r.client.id} style={{ cursor: 'pointer' }} onClick={() => actions.addPayment({ client_id: r.client.id })}>
                  <Avatar name={r.client.name} size="sm" />
                  <div className="list-main">
                    <div className="list-title truncate">{r.client.name}</div>
                    <div className="list-sub">
                      {r.count} bill{r.count > 1 ? 's' : ''} · oldest due {format(parseISO(r.oldest), 'dd MMM')}
                    </div>
                  </div>
                  <div className="list-end">
                    <span className="strong tabular">{money(r.balance, currency)}</span>
                  </div>
                </div>
              ))}
              {byClient.length > 8 && (
                <div className="list-row">
                  <Button size="sm" variant="ghost" onClick={() => setTab('invoices')}>View all pending bills</Button>
                </div>
              )}
            </div>
          )}
        </Card>
      </div>

      {clients.length === 0 && (
        <Card>
          <EmptyState
            icon={Users}
            title="Start by adding your clients"
            text="Add retainer clients with their monthly fee, and one-time project clients. Bills and payments are tracked per client."
            action={<Button variant="primary" icon={Plus} onClick={actions.addClient}>Add client</Button>}
          />
        </Card>
      )}
    </div>
  );
}
