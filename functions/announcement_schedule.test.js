const { test } = require("node:test");
const assert = require("node:assert/strict");
const { announcementSchedule } = require("./announcement_schedule");

test("does not guess dates from content or accept invalid schedules", () => {
  assert.equal(announcementSchedule({ content: "Meet Sep 15, 2026 at 7 AM" }), null);
  assert.equal(announcementSchedule({ eventStartAt: "bad" }), null);
  assert.equal(announcementSchedule({ addToCalendar: false, eventStartAt: "2026-09-15" }), null);
  assert.equal(announcementSchedule({ eventStartAt: "2026-09-15T07:00:00+08:00", eventAllDay: false }), null);
});
test("date-only schedules use Manila all-day boundaries", () => {
  const schedule = announcementSchedule({ eventStartAt: "2026-09-20T00:00:00+08:00" });
  assert.equal(schedule.allDay, true);
  assert.equal(schedule.startAt.toISOString(), "2026-09-19T16:00:00.000Z");
  assert.equal(schedule.endAt - schedule.startAt, 86400000);
});
test("timed events retain the official's exact times", () => {
  const schedule = announcementSchedule({ eventStartAt: "2026-09-15T07:00:00+08:00", eventEndAt: "2026-09-15T09:00:00+08:00", eventAllDay: false });
  assert.equal(schedule.allDay, false);
  assert.equal(schedule.endAt - schedule.startAt, 7200000);
});
