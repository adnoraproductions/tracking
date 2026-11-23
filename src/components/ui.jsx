import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, X, Inbox, Award } from 'lucide-react';
import { addMonths, format, startOfMonth } from 'date-fns';
import { STATUS_TONE } from '../lib/hr';

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="page-head">
      <div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      {actions && <div className="page-actions">{actions}</div>}
    </div>
  );
}

export function Card({ title, subtitle, actions, children, pad = true, className = '', style }) {
  return (
    <section className={`card ${className}`} style={style}>
      {(title || actions) && (
        <div className="card-head">
          <div style={{ minWidth: 0 }}>
            {title && <h3>{title}</h3>}
            {subtitle && <p>{subtitle}</p>}
          </div>
          {actions && <div className="row">{actions}</div>}
        </div>
      )}
      {pad ? <div className="card-pad">{children}</div> : children}
    </section>
  );
}

export function Stat({ label, value, sub, icon: Icon, tone = '' }) {
  return (
    <div className={`card stat ${tone ? `tone-${tone}` : ''}`}>
      <div className="stat-top">
        <span>{label}</span>
        {Icon && (
          <span className="stat-icon">
            <Icon size={16} />
          </span>
        )}
      </div>
      <div className="stat-value">{value}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  );
}

export function Button({ variant = 'default', size, loading, icon: Icon, children, className = '', block, ...rest }) {
  const cls = [
    'btn',
    variant !== 'default' && `btn-${variant}`,
    size && `btn-${size}`,
    block && 'btn-block',
    className,
  ]
    .filter(Boolean)
    .join(' ');
  return (
    <button className={cls} disabled={loading || rest.disabled} {...rest}>
      {loading ? <span className="spinner sm" /> : Icon ? <Icon size={size === 'sm' ? 14 : 16} /> : null}
      {children}
    </button>
  );
}

export function Badge({ tone = 'gray', children, dot }) {
  return (
    <span className={`badge badge-${tone}`}>
      {dot && <span className="dot" />}
      {children}
    </span>
  );
}

export function StatusBadge({ status }) {
  if (!status) return null;
  return <Badge tone={STATUS_TONE[status] || 'gray'}>{status.charAt(0).toUpperCase() + status.slice(1)}</Badge>;
}

export function TierBadge({ tier }) {
  if (!tier) return null;
  return (
    <span className={`tier tier-${tier.level}`}>
      <Award size={14} />
      {tier.name}
    </span>
  );
}

export function Field({ label, hint, children, className = '' }) {
  return (
    <div className={`field ${className}`}>
      {label && <label>{label}</label>}
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </div>
  );
}

export function Segmented({ options, value, onChange, full }) {
  return (
    <div className={`segmented ${full ? 'full' : ''}`} role="tablist">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="tab"
          aria-selected={value === o.value}
          className={value === o.value ? 'active' : ''}
          onClick={() => onChange(o.value)}
        >
          {o.icon && <o.icon size={14} />}
          {o.label}
          {o.count > 0 && <span className="seg-count">{o.count}</span>}
        </button>
      ))}
    </div>
  );
}

export function EmptyState({ icon: Icon = Inbox, title, text, action }) {
  return (
    <div className="empty">
      <div className="empty-icon">
        <Icon size={22} />
      </div>
      {title && <h4>{title}</h4>}
      {text && <p>{text}</p>}
      {action && <div style={{ marginTop: 14 }}>{action}</div>}
    </div>
  );
}

export function Alert({ tone = 'red', children, icon: Icon }) {
  if (!children) return null;
  return (
    <div className={`alert alert-${tone}`}>
      {Icon && <Icon size={16} style={{ flexShrink: 0, marginTop: 1 }} />}
      <div>{children}</div>
    </div>
  );
}

export function Loading() {
  return (
    <div className="page-loading">
      <span className="spinner" />
    </div>
  );
}

export function Progress({ value, max, tone }) {
  const pct = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
  return (
    <div className={`progress ${tone || ''}`}>
      <span style={{ width: `${pct}%` }} />
    </div>
  );
}

export function Avatar({ name, size }) {
  const parts = (name || '?').trim().split(/\s+/);
  const ini = ((parts[0]?.[0] || '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
  return <span className={`avatar ${size || ''}`}>{ini || '?'}</span>;
}

export function Modal({ open, onClose, title, children, footer, wide }) {
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => e.key === 'Escape' && onClose?.();
    document.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [open, onClose]);

  if (!open) return null;
  return createPortal(
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose?.()}>
      <div className={`modal ${wide ? 'wide' : ''}`} role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-head">
          <h3>{title}</h3>
          <button className="icon-btn" onClick={onClose} aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>,
    document.body,
  );
}

export function MonthPicker({ value, onChange, allowFuture = false }) {
  const isCurrent = format(value, 'yyyy-MM') >= format(new Date(), 'yyyy-MM');
  return (
    <div className="month-picker">
      <button type="button" aria-label="Previous month" onClick={() => onChange(startOfMonth(addMonths(value, -1)))}>
        <ChevronLeft size={16} />
      </button>
      <span>{format(value, 'MMMM yyyy')}</span>
      <button
        type="button"
        aria-label="Next month"
        disabled={!allowFuture && isCurrent}
        onClick={() => onChange(startOfMonth(addMonths(value, 1)))}
      >
        <ChevronRight size={16} />
      </button>
    </div>
  );
}

/* ---------- Confirm dialog ----------
   In-app replacement for window.confirm(), which is blocked inside some
   embedded browsers and app WebViews. Usage:
     const confirm = useConfirm();
     if (!(await confirm({ title, message, confirmLabel, danger: true }))) return;
*/
const ConfirmCtx = createContext(async () => false);

export function ConfirmProvider({ children }) {
  const [req, setReq] = useState(null);
  const confirm = useCallback(
    (opts) =>
      new Promise((resolve) => {
        setReq({ ...(typeof opts === 'string' ? { message: opts } : opts), resolve });
      }),
    [],
  );
  const close = (answer) => {
    req?.resolve(answer);
    setReq(null);
  };
  return (
    <ConfirmCtx.Provider value={confirm}>
      {children}
      <Modal
        open={!!req}
        onClose={() => close(false)}
        title={req?.title || 'Are you sure?'}
        footer={
          <>
            <Button onClick={() => close(false)} autoFocus={!!req?.danger}>{req?.cancelLabel || 'Cancel'}</Button>
            <Button variant={req?.danger ? 'danger' : 'primary'} onClick={() => close(true)} autoFocus={!req?.danger}>
              {req?.confirmLabel || 'Confirm'}
            </Button>
          </>
        }
      >
        <p className="small" style={{ margin: 0, color: 'var(--text-2)', whiteSpace: 'pre-line' }}>{req?.message}</p>
      </Modal>
    </ConfirmCtx.Provider>
  );
}

export const useConfirm = () => useContext(ConfirmCtx);

/* ---------- Toasts ---------- */
const ToastCtx = createContext(() => {});

export function ToastProvider({ children }) {
  const [toast, setToast] = useState(null);
  const show = useCallback((message, type = 'ok') => {
    setToast({ message, type, id: Date.now() });
  }, []);
  useEffect(() => {
    if (!toast) return undefined;
    const t = setTimeout(() => setToast(null), 3200);
    return () => clearTimeout(t);
  }, [toast]);
  return (
    <ToastCtx.Provider value={show}>
      {children}
      {toast && createPortal(<div key={toast.id} className={`toast ${toast.type === 'error' ? 'error' : ''}`}>{toast.message}</div>, document.body)}
    </ToastCtx.Provider>
  );
}

export const useToast = () => useContext(ToastCtx);
