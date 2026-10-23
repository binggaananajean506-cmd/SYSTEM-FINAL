"use strict";

const ANNOUNCEMENT_TYPES = ["general", "advisory", "event", "scheduled_activity"];

// Only structured schedule fields are considered. Never inspect announcement text.
function announcementSchedule(data) {
  if (!data || data.addToCalendar === false) return null;
  const date = (value) => {
    if (!value) return null;
    try {
      const result = typeof value.toDate === "function" ? value.toDate() : new Date(value);
      return result instanceof Date && Number.isFinite(result.getTime()) && result.getUTCFullYear() >= 2000 ? result : null;
    } catch (_) {
      return null;
    }
  };
  let startAt = date(data.eventStartAt);
  if (!startAt) return null;
  let endAt = date(data.eventEndAt);
  const allDay = data.eventAllDay === true || (data.eventAllDay == null && !data.eventEndAt);
  if (allDay) {
    const day = new Date(startAt.getTime() + 8 * 3600000).toISOString().slice(0, 10);
    startAt = new Date(`${day}T00:00:00+08:00`);
    endAt = new Date(startAt.getTime() + 86400000);
  }
  if (!endAt || endAt <= startAt || endAt - startAt > 14 * 86400000) return null;
  return { startAt, endAt, allDay };
}

module.exports = { ANNOUNCEMENT_TYPES, announcementSchedule };
