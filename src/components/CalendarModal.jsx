import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { format, addMonths, subMonths, startOfMonth, endOfMonth, startOfWeek, endOfWeek, isSameMonth, isSameDay, addDays, isToday } from 'date-fns';
import { ChevronLeft, ChevronRight, X } from 'lucide-react';

export default function CalendarModal({ isOpen, onClose, selectedDate, onSelectDate }) {
  const [currentMonth, setCurrentMonth] = useState(selectedDate || new Date());

  if (!isOpen) return null;

  const nextMonth = () => setCurrentMonth(addMonths(currentMonth, 1));
  const prevMonth = () => setCurrentMonth(subMonths(currentMonth, 1));

  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(monthStart);
  const startDate = startOfWeek(monthStart);
  const endDate = endOfWeek(monthEnd);

  const dateFormat = "d";
  const rows = [];
  let days = [];
  let day = startDate;
  let formattedDate = "";

  // Render Days of Week (Su, Mo, Tu, etc.)
  const daysOfWeek = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  while (day <= endDate) {
    for (let i = 0; i < 7; i++) {
      formattedDate = format(day, dateFormat);
      const cloneDay = day;
      const isSelected = isSameDay(day, selectedDate);
      const isCurrentMonth = isSameMonth(day, monthStart);
      const isTodayDate = isToday(day);

      days.push(
        <div
          key={day.toString()}
          onClick={() => {
            onSelectDate(cloneDay);
            onClose();
          }}
          className={`cal-day ${!isCurrentMonth ? 'disabled' : ''} ${isSelected ? 'selected' : ''} ${isTodayDate && !isSelected ? 'today' : ''}`}
        >
          <span>{formattedDate}</span>
        </div>
      );
      day = addDays(day, 1);
    }
    rows.push(
      <div className="cal-row" key={day.toString()}>
        {days}
      </div>
    );
    days = [];
  }

  return createPortal(
    <div className="cal-modal-overlay" onClick={onClose}>
      <div className="cal-modal" onClick={e => e.stopPropagation()}>
        <div className="cal-header">
          <button className="cal-nav" onClick={prevMonth}><ChevronLeft size={20} /></button>
          <h3>{format(currentMonth, 'MMMM yyyy')}</h3>
          <button className="cal-nav" onClick={nextMonth}><ChevronRight size={20} /></button>
        </div>

        <div className="cal-body">
          <div className="cal-days-header">
            {daysOfWeek.map((d, i) => <div key={i} className="cal-day-name">{d}</div>)}
          </div>
          {rows}
        </div>

        <div className="cal-footer">
          <button className="cal-btn-text" onClick={() => { onSelectDate(new Date()); onClose(); }}>
            Today
          </button>
          <button className="cal-btn-text danger" onClick={onClose}>
            Cancel
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}
