import React, { useEffect, useState } from 'react';
import { startOfMonth } from 'date-fns';
import { LayoutDashboard, Building2, FileText, Receipt, Banknote } from 'lucide-react';
import { useHrSettings, friendlyError } from '../../lib/hr';
import { PageHeader, Segmented, Alert, Loading, MonthPicker, useToast } from '../../components/ui';
import { loadLedger, ClientModal, InvoiceModal, PaymentModal } from './shared';
import FinanceOverview from './FinanceOverview';
import Clients from './Clients';
import Invoices from './Invoices';
import Expenses from './Expenses';
import Payroll from './Payroll';

const TABS = [
  { value: 'overview', label: 'Overview', icon: LayoutDashboard },
  { value: 'clients', label: 'Clients', icon: Building2 },
  { value: 'invoices', label: 'Bills & payments', icon: FileText },
  { value: 'expenses', label: 'Expenses', icon: Receipt },
  { value: 'payroll', label: 'Payroll', icon: Banknote },
];

export default function Finance() {
  const { settings } = useHrSettings();
  const toast = useToast();
  const [tab, setTab] = useState(() => {
    try {
      return sessionStorage.getItem('finance-tab') || 'overview';
    } catch {
      return 'overview';
    }
  });
  const [month, setMonth] = useState(startOfMonth(new Date()));
  const [ledger, setLedger] = useState({ clients: [], invoices: [], payments: [] });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [clientEdit, setClientEdit] = useState(null);
  const [invoiceEdit, setInvoiceEdit] = useState(null);
  const [paymentEdit, setPaymentEdit] = useState(null);

  const reload = async () => {
    setError(null);
    try {
      setLedger(await loadLedger());
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const changeTab = (t) => {
    setTab(t);
    try {
      sessionStorage.setItem('finance-tab', t);
    } catch {
      /* ignore */
    }
  };

  const saved = (msg) => {
    setClientEdit(null);
    setInvoiceEdit(null);
    setPaymentEdit(null);
    toast(msg);
    reload();
  };

  const currency = settings.currency || 'INR';
  const actions = {
    addClient: () => setClientEdit({}),
    editClient: (c) => setClientEdit(c),
    addInvoice: (preset = {}) => setInvoiceEdit(preset),
    editInvoice: (i) => setInvoiceEdit(i),
    addPayment: (preset = {}) => setPaymentEdit(preset),
    editPayment: (p) => setPaymentEdit(p),
  };
  const shared = { ledger, month, currency, reload, actions, toast, setTab: changeTab };

  return (
    <div className="stack">
      <PageHeader
        title="Finance"
        subtitle="Client billing, payments, expenses and payroll — visible to admins only."
        actions={tab !== 'clients' && <MonthPicker value={month} onChange={setMonth} />}
      />

      <Segmented value={tab} onChange={changeTab} options={TABS} />

      {error && <Alert>{error}</Alert>}

      {loading ? (
        <Loading />
      ) : (
        <>
          {tab === 'overview' && <FinanceOverview {...shared} />}
          {tab === 'clients' && <Clients {...shared} />}
          {tab === 'invoices' && <Invoices {...shared} />}
          {tab === 'expenses' && <Expenses month={month} currency={currency} toast={toast} />}
          {tab === 'payroll' && <Payroll month={month} currency={currency} toast={toast} settings={settings} />}
        </>
      )}

      <ClientModal client={clientEdit} onClose={() => setClientEdit(null)} onSaved={saved} />
      <InvoiceModal invoice={invoiceEdit} clients={ledger.clients} payments={ledger.payments} currency={currency} onClose={() => setInvoiceEdit(null)} onSaved={saved} />
      <PaymentModal
        payment={paymentEdit}
        clients={ledger.clients}
        invoices={ledger.invoices}
        currency={currency}
        onClose={() => setPaymentEdit(null)}
        onSaved={saved}
      />
    </div>
  );
}
