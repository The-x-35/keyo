// A demo calendar for the keyboard: seeded with a believable week, so "can we talk this
// week?" gets real free slots, and a tap books one.
import * as store from './store.mjs';

const MIN = 60_000;
const at = (day, h, m = 0) => {
  const d = new Date();
  d.setDate(d.getDate() + day);
  d.setHours(h, m, 0, 0);
  return d;
};
const ev = (title, start, minutes) => ({ title, start: start.toISOString(), end: new Date(start.getTime() + minutes * MIN).toISOString(), by: 'you' });

// A fresh week whenever the stored one has run out.
export function events() {
  const now = Date.now();
  if (!store.calendar().some((e) => Date.parse(e.end) > now)) {
    const week = [];
    for (let day = 0; day < 7; day++) {
      const wd = at(day, 9).getDay();
      if (wd === 0 || wd === 6) continue;
      week.push(ev('Standup', at(day, 10), 30));
      week.push(ev('Lunch', at(day, 13), 60));
      if (day % 2 === 0) week.push(ev('Design review', at(day, 11), 90));
      else week.push(ev('Focus time', at(day, 15), 120));
    }
    week.push(ev('Gym', at(1, 18, 30), 60));
    store.setCalendar(week.sort((a, b) => Date.parse(a.start) - Date.parse(b.start)));
  }
  return store.calendar().filter((e) => Date.parse(e.end) > now);
}

const DAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

// Free 30-minute slots in working hours: the first one on each of the next days,
// or three on the day the message names.
export function freeSlots(text = '', minutes = 30, count = 3) {
  const busy = events().map((e) => [Date.parse(e.start), Date.parse(e.end)]);
  const named = DAYS.findIndex((d) => new RegExp(`\\b${d}\\b`, 'i').test(text));
  const tomorrow = /\btomorrow\b/i.test(text);
  const out = [];
  for (let day = 1; day < 10 && out.length < count; day++) {
    const d = at(day, 9);
    if (d.getDay() === 0 || d.getDay() === 6) continue;
    if (named >= 0 && d.getDay() !== named) continue;
    if (tomorrow && day !== 1) continue;
    // Spread the offers over the day (morning, after lunch, late afternoon) like a person would.
    const from = named >= 0 || tomorrow ? 10 : [10, 14, 16][out.length] ?? 10;
    for (let t = at(day, from).getTime(); t + minutes * MIN <= at(day, 18).getTime(); t += 30 * MIN) {
      const end = t + minutes * MIN;
      if (busy.some(([s, e]) => t < e && end > s)) continue;
      out.push(new Date(t));
      if (named < 0 && !tomorrow) break;
      if (out.length >= count) break;
    }
  }
  return out;
}

export function book({ title, start, minutes = 30, with: who }) {
  const s = new Date(start);
  return store.addEvent({ title, start: s.toISOString(), end: new Date(s.getTime() + minutes * MIN).toISOString(), with: who, by: 'keyo' });
}

export const dayLabel = (d) => new Date(d).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
export const timeLabel = (d) => new Date(d).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
