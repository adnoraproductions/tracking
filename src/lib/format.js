import { format, startOfMonth, endOfMonth } from 'date-fns';

const moneyFormatters = {};

export function money(value, currency = 'INR') {
  const n = Number(value) || 0;
  if (!moneyFormatters[currency]) {
    moneyFormatters[currency] = new Intl.NumberFormat(currency === 'INR' ? 'en-IN' : 'en-US', {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    });
  }
  return moneyFormatters[currency].format(Math.round(n));
}

export const ymd = (d) => format(d, 'yyyy-MM-dd');

export function monthRange(month) {
  const start = startOfMonth(month);
  const end = endOfMonth(month);
  return { start, end, startStr: ymd(start), endStr: ymd(end) };
}

export function prettyDate(value, pattern = 'dd MMM yyyy') {
  if (!value) return '—';
  const d = typeof value === 'string' && value.length === 10 ? new Date(`${value}T00:00:00`) : new Date(value);
  return format(d, pattern);
}

export function initials(name) {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/);
  return ((parts[0]?.[0] || '') + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
}

export function firstName(name) {
  return name?.trim().split(/\s+/)[0] || '';
}

export const round1 = (n) => Math.round((Number(n) || 0) * 10) / 10;
