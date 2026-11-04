// Standing orders: "every month recharge mom's jio for 199" runs on its own,
// inside the same spending limits, and lands in the ledger.
import * as store from './store.mjs';

const DAY = 86_400_000;
const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

export function parse(text) {
  const m = text.toLowerCase().match(/^\s*(?:every|each)\s+(minute|hour|day|week|month|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s*(?:,|:)?\s*(.+)$/)
    || text.toLowerCase().match(/^(.+?)\s+(?:every|each)\s+(minute|hour|day|week|month|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\s*$/);
  if (!m) return null;
  const [every, command] = WEEKDAYS.includes(m[1]) || ['minute', 'hour', 'day', 'week', 'month'].includes(m[1]) ? [m[1], m[2]] : [m[2], m[1]];
  return { every, command: command.trim() };
}

export function nextRun(every, from = Date.now()) {
  if (every === 'minute') return from + 60_000;
  if (every === 'hour') return from + 3600_000;
  if (every === 'day') return from + DAY;
  if (every === 'week') return from + 7 * DAY;
  if (every === 'month') {
    const d = new Date(from);
    d.setMonth(d.getMonth() + 1);
    return d.getTime();
  }
  const target = WEEKDAYS.indexOf(every);
  const d = new Date(from + DAY);
  while (d.getDay() !== target) d.setTime(d.getTime() + DAY);
  d.setHours(9, 0, 0, 0);
  return d.getTime();
}

export function add(every, chip) {
  const rule = { id: `rule_${Date.now().toString(36)}`, every, chip, next: nextRun(every), runs: 0, created: new Date().toISOString() };
  store.saveRule(rule);
  return rule;
}

// Runs due orders once a minute.
export function start(act) {
  setInterval(async () => {
    for (const r of store.rules()) {
      if (r.paused || r.next > Date.now()) continue;
      r.next = nextRun(r.every);
      r.runs += 1;
      store.saveRule(r);
      try {
        const out = await act(r.chip, process.env.AEGIS_DEFAULT_MODE || 'server', !!r.chip.demo);
        store.record({ type: 'auto', ok: out.status === 'done', rule: r.id, every: r.every, title: r.chip.title, result: out.status, invoice_id: out.invoice_id, txid: out.txid });
      } catch (e) {
        store.record({ type: 'auto', ok: false, rule: r.id, every: r.every, title: r.chip.title, error: e.message });
      }
    }
  }, 30_000);
}
