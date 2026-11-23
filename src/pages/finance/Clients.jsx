import React, { useMemo, useState } from 'react';
import { Plus, Building2, Pencil, IndianRupee, Phone } from 'lucide-react';
import { money } from '../../lib/format';
import { Card, Button, Badge, Segmented, EmptyState, Avatar } from '../../components/ui';

export default function Clients({ ledger, currency, actions }) {
  const { clients, invoices, payments } = ledger;
  const [filter, setFilter] = useState('active');
  const [q, setQ] = useState('');

  const stats = useMemo(() => {
    const m = {};
    for (const c of clients) m[c.id] = { balance: 0, received: 0 };
    for (const i of invoices) if (m[i.client_id]) m[i.client_id].balance += i.balance;
    for (const p of payments) if (m[p.client_id]) m[p.client_id].received += Number(p.amount);
    return m;
  }, [clients, invoices, payments]);

  const list = clients
    .filter((c) => (filter === 'active' ? c.is_active : filter === 'inactive' ? !c.is_active : c.client_type === filter && c.is_active))
    .filter((c) => !q || c.name.toLowerCase().includes(q.toLowerCase()));

  return (
    <Card
      title="Clients"
      subtitle={`${clients.filter((c) => c.is_active).length} active`}
      pad={false}
      actions={<Button size="sm" variant="primary" icon={Plus} onClick={actions.addClient}>Add client</Button>}
    >
      <div className="row wrap" style={{ padding: '12px 20px', borderBottom: '1px solid var(--border)' }}>
        <Segmented
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'active', label: 'Active' },
            { value: 'recurring', label: 'Recurring' },
            { value: 'one_time', label: 'One-time' },
            { value: 'inactive', label: 'Inactive' },
          ]}
        />
        <input className="input" style={{ maxWidth: 240, height: 38 }} placeholder="Search clients" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {list.length === 0 ? (
        <EmptyState icon={Building2} title="No clients here" action={<Button icon={Plus} onClick={actions.addClient}>Add client</Button>} />
      ) : (
        <div className="list">
          {list.map((c) => (
            <div className="list-row" key={c.id}>
              <Avatar name={c.name} />
              <div className="list-main">
                <div className="row wrap" style={{ gap: 8 }}>
                  <span className="list-title">{c.name}</span>
                  <Badge tone={c.client_type === 'recurring' ? 'violet' : 'blue'}>{c.client_type === 'recurring' ? 'Recurring' : 'One-time'}</Badge>
                </div>
                <div className="list-sub">
                  {c.client_type === 'recurring' && `${money(c.monthly_fee, currency)}/month · bills on day ${c.billing_day}`}
                  {c.client_type === 'recurring' && c.services ? ' · ' : ''}
                  {c.services}
                </div>
                {(c.contact_person || c.phone) && (
                  <div className="list-sub row" style={{ gap: 6 }}>
                    <Phone size={12} /> {[c.contact_person, c.phone].filter(Boolean).join(' · ')}
                  </div>
                )}
              </div>
              <div className="list-end wrap-mobile">
                <div style={{ textAlign: 'right', marginRight: 6 }}>
                  <div className={`strong tabular ${stats[c.id]?.balance > 0 ? 'text-amber' : ''}`}>{money(stats[c.id]?.balance, currency)}</div>
                  <div className="xs muted">pending</div>
                </div>
                <Button size="sm" onClick={() => actions.addInvoice({ client_id: c.id, amount: c.client_type === 'recurring' ? c.monthly_fee : '' })}>Bill</Button>
                <Button size="sm" icon={IndianRupee} onClick={() => actions.addPayment({ client_id: c.id })}>Paid</Button>
                <button className="icon-btn" onClick={() => actions.editClient(c)} aria-label="Edit client">
                  <Pencil size={15} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}
