import React from 'react';
import { Link } from 'react-router-dom';
import { Check, Flame, Rocket, Target, TrendingUp, Clock3, ChevronRight, Lock, Trophy } from 'lucide-react';
import { levelFor, projectPoints, unitsFor } from '../lib/incentives';
import { money } from '../lib/format';

/**
 * Motivational incentive tracker for employees.
 * Shows slabs and their amounts only — never the per-task bonus beyond the top slab.
 *
 * props: plan, points (approved this month), pending (points awaiting approval),
 *        today (points logged today, approved + pending), days (workingDaysInfo), currency, compact
 */
/** "posters" → "poster", "edits or shoots" → "edit or shoot" when n === 1 */
function unitWord(n, label) {
  if (n !== 1) return label;
  return label
    .split(' or ')
    .map((w) => w.replace(/s$/, ''))
    .join(' or ');
}

export default function IncentiveTracker({ plan, points = 0, pending = 0, today = 0, days, currency = 'INR', compact = false }) {
  if (!plan) {
    return (
      <div className="inc-card">
        <div className="inc-head">
          <span className="inc-plan">Incentive plan</span>
        </div>
        <div className="inc-msg">Your incentive plan hasn't been assigned yet. Your manager will set it up soon.</div>
      </div>
    );
  }

  const lv = levelFor(points, plan);
  const unit = plan.unit_label || 'tasks';

  if (!lv.hasPlan) {
    return (
      <div className="inc-card">
        <div className="inc-head">
          <span className="inc-plan">{plan.name} plan</span>
        </div>
        <div className="inc-points">
          <span className="inc-big">{points}</span>
          <span className="inc-unit">points this month</span>
        </div>
        <div className="inc-msg">Your incentive slabs are being finalised. Keep logging every task — all your points count.</div>
      </div>
    );
  }

  const withPending = points + pending;
  const lvPending = levelFor(withPending, plan);
  const slabs = plan.slabs;
  const top = slabs[slabs.length - 1];
  // Piecewise scale: each level gets an even share of the track so labels never crowd,
  // with a small "bonus zone" after the top level.
  const knots = [0, ...slabs.map((x) => x.min_points), Math.round(top.min_points * 1.12)];
  const stops = [0, ...slabs.map((_, i) => (slabs.length === 1 ? 70 : 38 + (i * (86 - 38)) / (slabs.length - 1))), 100];
  const pct = (v) => {
    if (v <= 0) return '0%';
    for (let i = 1; i < knots.length; i++) {
      if (v <= knots[i]) return `${stops[i - 1] + ((v - knots[i - 1]) / (knots[i] - knots[i - 1] || 1)) * (stops[i] - stops[i - 1])}%`;
    }
    return '100%';
  };

  const toNext = lv.next ? lv.next.min_points - points : 0;
  const unitsToNext = unitsFor(toNext, plan);
  const projected = days ? projectPoints(withPending, days) : withPending;
  const projectedLv = levelFor(projected, plan);
  // Aim at the next level not already covered by tasks waiting for approval
  const target = lvPending.next || null;
  const perDayPts = target && days?.remaining > 0 ? Math.max(0, Math.ceil((target.min_points - withPending) / days.remaining)) : 0;
  const perDayUnits = unitsFor(perDayPts, plan);

  // Headline
  let icon = Target;
  let headline;
  let sub;
  if (lv.inBonus) {
    icon = Rocket;
    headline = `${lv.name} unlocked — ${money(lv.incentive, currency)} earned!`;
    sub = `You're in the bonus zone: every extra ${unitWord(1, unit)} from now adds more to your incentive.`;
  } else if (lv.level === 0) {
    headline = `${toNext} points to reach ${lv.next.level}`;
    sub = `That's ${unitsToNext} more ${unitWord(unitsToNext, unit)}. ${lv.next.level} is your monthly target.`;
  } else {
    icon = unitsToNext <= 5 ? Flame : TrendingUp;
    headline = `${unitsToNext <= 5 ? 'So close! ' : ''}${unitsToNext} ${unitWord(unitsToNext, unit)} away from ${lv.next.level}`;
    sub = `Unlock ${money(lv.next.incentive, currency)} at ${lv.next.min_points} points.`;
  }
  const Icon = icon;
  const pendingUnlocks = pending > 0 && lvPending.level > lv.level;

  if (compact) {
    return (
      <Link to="/employee/tasks" className="inc-card inc-compact">
        <div className="inc-head">
          <span className="inc-plan">Incentive tracker</span>
          <span className={`tier tier-${lv.level}`}>
            <Trophy size={13} /> {lv.name}
          </span>
        </div>
        <div className="inc-headline">
          <Icon size={18} /> {headline}
        </div>
        <Track slabs={slabs} points={points} pending={pending} pct={pct} currency={currency} compact />
        <div className="inc-compact-foot">
          <span>
            <strong>{points}</strong> pts{pending > 0 && <span className="inc-dim"> · +{pending} pending</span>}
          </span>
          <span className="inc-link">
            Open tasks <ChevronRight size={14} />
          </span>
        </div>
      </Link>
    );
  }

  return (
    <div className="inc-card">
      <div className="inc-head">
        <span className="inc-plan">{plan.name} plan</span>
        <span className={`tier tier-${lv.level}`}>
          <Trophy size={13} /> {lv.name}
        </span>
      </div>

      <div className="inc-top">
        <div className="inc-points">
          <span className="inc-big">{points}</span>
          <span className="inc-unit">points{pending > 0 && <span className="inc-dim"> · +{pending} waiting for approval</span>}</span>
        </div>
        {lv.incentive > 0 || !lv.next ? (
          <div className="inc-earned">
            <span className="inc-dim">Incentive unlocked</span>
            <strong>{money(lv.incentive, currency)}</strong>
            {lv.inBonus && <span className="inc-plus">+ bonus</span>}
          </div>
        ) : (
          <div className="inc-earned">
            <span className="inc-dim">Next unlock</span>
            <strong>{money(slabs.find((x) => x.incentive > 0)?.incentive || 0, currency)}</strong>
            <span className="inc-dim">at {slabs.find((x) => x.incentive > 0)?.level}</span>
          </div>
        )}
      </div>

      <div className="inc-headline">
        <Icon size={18} /> {headline}
      </div>
      <div className="inc-sub">{sub}</div>
      {pendingUnlocks && (
        <div className="inc-pending-note">
          <Clock3 size={14} /> Once your pending tasks are approved you'll reach <strong>{lvPending.name}</strong>!
        </div>
      )}

      <Track slabs={slabs} points={points} pending={pending} pct={pct} currency={currency} />

      <div className="inc-chips">
        {plan.daily_points ? (
          <div className="inc-chip">
            <span className="inc-dim">Today's KPI</span>
            <strong>
              {today} / {plan.daily_points} pts
            </strong>
            <div className="inc-mini">
              <span style={{ width: `${Math.min(100, (today / plan.daily_points) * 100)}%` }} />
            </div>
            <span className="inc-dim">
              {today >= plan.daily_points ? 'Daily target hit ✓' : `${unitsFor(plan.daily_points - today, plan)} more ${unitWord(unitsFor(plan.daily_points - today, plan), unit)} today`}
            </span>
          </div>
        ) : (
          <div className="inc-chip">
            <span className="inc-dim">Logged today</span>
            <strong>{today} pts</strong>
            <span className="inc-dim">{unitsFor(today, plan)} {unitWord(unitsFor(today, plan), unit)}</span>
          </div>
        )}
        {days && !days.isPast && (
          <div className="inc-chip">
            <span className="inc-dim">Month-end forecast</span>
            <strong>~{projected} pts</strong>
            <span className="inc-dim">{projectedLv.level === 0 ? `${projectedLv.name} at this pace — push a little more` : `On track for ${projectedLv.name}`}</span>
          </div>
        )}
        {target && days?.remaining > 0 && (
          <div className="inc-chip highlight">
            <span className="inc-dim">To reach {target.level}</span>
            <strong>
              {Math.max(1, perDayUnits)} {unitWord(Math.max(1, perDayUnits), unit)}/day
            </strong>
            <span className="inc-dim">for the next {days.remaining} working day{days.remaining > 1 ? 's' : ''}</span>
          </div>
        )}
      </div>
    </div>
  );
}

function Track({ slabs, points, pending, pct, currency, compact }) {
  return (
    <div className={`inc-track-wrap ${compact ? 'compact' : ''}`}>
      <div className="inc-track">
        <span className="inc-fill" style={{ width: pct(points) }} />
        {pending > 0 && <span className="inc-pending" style={{ left: pct(points), width: `calc(${pct(points + pending)} - ${pct(points)})` }} />}
        {slabs.map((s) => {
          const reached = points >= s.min_points;
          return (
            <span key={s.level} className={`inc-milestone ${reached ? 'reached' : ''}`} style={{ left: pct(s.min_points) }}>
              <span className="inc-dot">{reached ? <Check size={11} /> : <Lock size={9} />}</span>
              {!compact && (
                <span className="inc-label">
                  <strong>{s.level}</strong>
                  <span>{s.min_points}</span>
                  <em>{s.incentive > 0 ? money(s.incentive, currency) : 'Target'}</em>
                </span>
              )}
            </span>
          );
        })}
        <span className="inc-you" style={{ left: pct(points) }} />
      </div>
    </div>
  );
}
