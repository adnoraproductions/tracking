import React, { useEffect, useState } from 'react';
import { addDays, eachDayOfInterval, format, isSameMonth, parseISO } from 'date-fns';
import { CalendarPlus, CalendarDays, Info, Umbrella, Siren, CircleSlash } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase/client';
import { useHrSettings, LEAVE_TYPES, cleanDbMessage, friendlyError } from '../../lib/hr';
import { prettyDate, ymd, round1 } from '../../lib/format';
import {
  PageHeader, Card, Stat, Button, Badge, StatusBadge, Field, Segmented, EmptyState, Alert, Loading, Modal, useToast, useConfirm,
} from '../../components/ui';

function countWorkingDays(start, end, perWeek) {
  if (!start || !end || end < start) return 0;
  return eachDayOfInterval({ start: parseISO(start), end: parseISO(end) }).filter((d) => {
    const dow = d.getDay(); // 0 = Sunday
    if (perWeek === 6 && dow === 0) return false;
    if (perWeek === 5 && (dow === 0 || dow === 6)) return false;
    return true;
  }).length;
}

export function leaveRangeText(l) {
  if (l.half_day) return `${prettyDate(l.start_date, 'EEE, dd MMM')} · Half day`;
  if (l.start_date === l.end_date) return prettyDate(l.start_date, 'EEE, dd MMM yyyy');
  return `${prettyDate(l.start_date, 'dd MMM')} – ${prettyDate(l.end_date, 'dd MMM yyyy')}`;
}

export function LeavePayBadge({ leave }) {
  if (Number(leave.unpaid_days) > 0 && Number(leave.paid_days) > 0) {
    return <Badge tone="amber">{round1(leave.paid_days)} paid · {round1(leave.unpaid_days)} unpaid</Badge>;
  }
  if (Number(leave.unpaid_days) > 0) return <Badge tone="gray">Unpaid</Badge>;
  return <Badge tone="green">Paid</Badge>;
}

export default function MyLeaves() {
  const { profile } = useAuth();
  const { settings } = useHrSettings();
  const toast = useToast();
  const confirm = useConfirm();
  const [leaves, setLeaves] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [open, setOpen] = useState(false);
  const [filter, setFilter] = useState('all');

  const load = async () => {
    setLoading(true);
    setError(null);
    const { data, error: err } = await supabase
      .from('leave_requests')
      .select('*')
      .eq('employee_id', profile.id)
      .order('start_date', { ascending: false })
      .limit(200);
    if (err) setError(friendlyError(err));
    setLeaves(data || []);
    setLoading(false);
  };

  useEffect(() => {
    if (profile) load();
  }, [profile]);

  const now = new Date();
  const thisMonth = leaves.filter((l) => ['pending', 'approved'].includes(l.status) && isSameMonth(parseISO(l.start_date), now));
  const usedPaid = (type) => thisMonth.filter((l) => l.leave_type === type).reduce((s, l) => s + Number(l.paid_days || 0), 0);
  const unpaidThisMonth = thisMonth.reduce((s, l) => s + Number(l.unpaid_days || 0), 0);
  const casualLeft = Math.max(0, settings.paid_casual_per_month - usedPaid('casual'));
  const emergencyLeft = Math.max(0, settings.paid_emergency_per_month - usedPaid('emergency'));

  const cancel = async (leave) => {
    const ok = await confirm({ title: 'Cancel leave request?', message: leaveRangeText(leave), confirmLabel: 'Cancel request', cancelLabel: 'Keep it', danger: true });
    if (!ok) return;
    const { error: err } = await supabase.from('leave_requests').update({ status: 'cancelled' }).eq('id', leave.id);
    if (err) return toast(cleanDbMessage(err), 'error');
    toast('Leave request cancelled');
    load();
  };

  const visible = filter === 'all' ? leaves : leaves.filter((l) => l.status === filter);

  return (
    <div className="stack">
      <PageHeader
        title="Leaves"
        subtitle={`${format(now, 'MMMM')}: ${settings.paid_casual_per_month} paid casual + ${settings.paid_emergency_per_month} paid emergency leave`}
        actions={<Button variant="primary" icon={CalendarPlus} onClick={() => setOpen(true)}>Apply for leave</Button>}
      />

      {error && <Alert>{error}</Alert>}

      <div className="grid-stats">
        <Stat label="Casual left" value={`${round1(casualLeft)} / ${settings.paid_casual_per_month}`} sub="Paid · apply in advance" icon={Umbrella} tone="blue" />
        <Stat label="Emergency left" value={`${round1(emergencyLeft)} / ${settings.paid_emergency_per_month}`} sub="Paid · for urgent needs" icon={Siren} tone="amber" />
        <Stat label="Unpaid this month" value={round1(unpaidThisMonth)} sub="Days beyond paid quota" icon={CircleSlash} tone="red" />
      </div>

      <Card
        title="My requests"
        pad={false}
        actions={
          <Segmented
            value={filter}
            onChange={setFilter}
            options={[
              { value: 'all', label: 'All' },
              { value: 'pending', label: 'Pending' },
              { value: 'approved', label: 'Approved' },
            ]}
          />
        }
      >
        {loading ? (
          <Loading />
        ) : visible.length === 0 ? (
          <EmptyState icon={CalendarDays} title="No leave requests" text="Requests you apply for will show here with their status." />
        ) : (
          <div className="list">
            {visible.map((l) => (
              <div className="list-row" key={l.id}>
                <div className="list-main">
                  <div className="row wrap" style={{ gap: 8 }}>
                    <span className="list-title">{leaveRangeText(l)}</span>
                    <Badge tone={LEAVE_TYPES[l.leave_type]?.tone}>{LEAVE_TYPES[l.leave_type]?.label}</Badge>
                  </div>
                  <div className="list-sub">
                    {round1(l.days)} day{Number(l.days) === 1 ? '' : 's'} · {l.reason}
                  </div>
                  {l.review_note && <div className="list-sub">Note: {l.review_note}</div>}
                </div>
                <div className="list-end wrap-mobile">
                  {l.status !== 'cancelled' && l.status !== 'rejected' && <LeavePayBadge leave={l} />}
                  <StatusBadge status={l.status} />
                  {l.status === 'pending' && (
                    <Button size="sm" variant="ghost" onClick={() => cancel(l)}>Cancel</Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      <ApplyLeaveModal
        open={open}
        onClose={() => setOpen(false)}
        settings={settings}
        casualLeft={casualLeft}
        emergencyLeft={emergencyLeft}
        onSaved={() => {
          setOpen(false);
          toast('Leave request sent for approval');
          load();
        }}
      />
    </div>
  );
}

function ApplyLeaveModal({ open, onClose, settings, casualLeft, emergencyLeft, onSaved }) {
  const notice = Number(settings.casual_notice_days || 1);
  const earliestCasual = ymd(addDays(new Date(), notice));
  const today = ymd(new Date());
  const blank = { leave_type: 'casual', start_date: earliestCasual, end_date: earliestCasual, half_day: false, reason: '' };
  const [form, setForm] = useState(blank);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (open) {
      setForm(blank);
      setError(null);
    }
  }, [open]);

  const set = (patch) => setForm((f) => ({ ...f, ...patch }));

  const changeType = (t) => {
    const patch = { leave_type: t };
    if (t === 'casual' && form.start_date < earliestCasual) {
      patch.start_date = earliestCasual;
      if (form.end_date < earliestCasual) patch.end_date = earliestCasual;
    }
    if (t !== 'casual' && form.start_date === earliestCasual) {
      patch.start_date = today;
      patch.end_date = today;
    }
    set(patch);
  };

  const days = form.half_day ? 0.5 : countWorkingDays(form.start_date, form.half_day ? form.start_date : form.end_date, settings.working_days_per_week);
  const left = form.leave_type === 'casual' ? casualLeft : form.leave_type === 'emergency' ? emergencyLeft : 0;
  const paid = Math.min(days, left);
  const unpaid = Math.max(0, days - paid);
  const casualTooLate = form.leave_type === 'casual' && form.start_date < earliestCasual;

  const submit = async (e) => {
    e?.preventDefault();
    setError(null);
    if (!form.reason.trim()) return setError('Please add a short reason.');
    if (!form.half_day && form.end_date < form.start_date) return setError('End date cannot be before start date.');
    if (casualTooLate) return setError(`Casual leave must be applied at least ${notice} day${notice > 1 ? 's' : ''} in advance. Choose Emergency for urgent leave.`);
    if (days <= 0) return setError('The selected dates have no working days.');
    setSaving(true);
    const { data: auth } = await supabase.auth.getUser();
    const { error: err } = await supabase.from('leave_requests').insert({
      employee_id: auth.user.id,
      leave_type: form.leave_type,
      start_date: form.start_date,
      end_date: form.half_day ? form.start_date : form.end_date,
      half_day: form.half_day,
      reason: form.reason.trim(),
    });
    setSaving(false);
    if (err) return setError(cleanDbMessage(err));
    onSaved();
  };

  const typeHint = {
    casual: `Planned leave. Apply at least ${notice} day${notice > 1 ? 's' : ''} before (ideally 2). ${casualLeft > 0 ? `${casualLeft} paid left this month.` : 'Paid casual leave used this month — extra days are unpaid.'}`,
    emergency: `For urgent, unplanned situations — can be applied on the same day. ${emergencyLeft > 0 ? `${emergencyLeft} paid left this month.` : 'Paid emergency leave used this month — extra days are unpaid.'}`,
    unpaid: 'Leave without pay (loss of pay). Salary is deducted for these days.',
  }[form.leave_type];

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Apply for leave"
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" loading={saving} onClick={submit}>Send request</Button>
        </>
      }
    >
      <form className="stack" onSubmit={submit}>
        <Segmented
          full
          value={form.leave_type}
          onChange={changeType}
          options={[
            { value: 'casual', label: 'Casual' },
            { value: 'emergency', label: 'Emergency' },
            { value: 'unpaid', label: 'Unpaid' },
          ]}
        />
        <Alert tone="blue" icon={Info}>{typeHint}</Alert>

        <div className="form-grid">
          <Field label={form.half_day ? 'Date' : 'From'}>
            <input
              className="input"
              type="date"
              value={form.start_date}
              min={form.leave_type === 'casual' ? earliestCasual : undefined}
              onChange={(e) => set({ start_date: e.target.value, end_date: e.target.value > form.end_date ? e.target.value : form.end_date })}
            />
          </Field>
          {!form.half_day && (
            <Field label="To">
              <input className="input" type="date" value={form.end_date} min={form.start_date} onChange={(e) => set({ end_date: e.target.value })} />
            </Field>
          )}
        </div>

        <label className="check">
          <input type="checkbox" checked={form.half_day} onChange={(e) => set({ half_day: e.target.checked })} />
          Half day
        </label>

        <Field label="Reason">
          <textarea className="textarea" value={form.reason} onChange={(e) => set({ reason: e.target.value })} placeholder="e.g. Family function" />
        </Field>

        <div className="card card-pad" style={{ background: 'var(--surface-2)', boxShadow: 'none' }}>
          <div className="row-between small">
            <span className="muted">Working days</span>
            <span className="strong">{days}</span>
          </div>
          <div className="row-between small" style={{ marginTop: 6 }}>
            <span className="muted">Paid</span>
            <span className="strong text-green">{round1(paid)}</span>
          </div>
          <div className="row-between small" style={{ marginTop: 6 }}>
            <span className="muted">Unpaid (salary deducted)</span>
            <span className={`strong ${unpaid > 0 ? 'text-red' : ''}`}>{round1(unpaid)}</span>
          </div>
        </div>

        {error && <Alert>{error}</Alert>}
      </form>
    </Modal>
  );
}
