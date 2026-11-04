// Turns what the user is typing, or the message they're replying to, into action chips
// for the keyboard strip. Fast rules first; Gemini for anything the rules don't know.
// Every amount is in US dollars.
import { contacts } from './store.mjs';
import * as schedule from './schedule.mjs';
import * as shop from './shop.mjs';
import * as cal from './calendar.mjs';

// Brands people name in chat, and the Bitrefill product each one buys.
export const BRAND_IDS = {
  starbucks: 'starbucks-usa', doordash: 'doordash-usa', uber: 'uber-usa', sephora: 'sephora-usa', target: 'target-usa',
};
const BRANDS = Object.keys(BRAND_IDS);
const OPERATORS = ['jio', 'airtel', 'vi', 'bsnl'];

const num = (s) => Number(String(s).replace(/[,$]/g, ''));
const cap = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);
const money = (n) => `$${Number(n) % 1 ? Number(n).toFixed(2) : Number(n)}`;

export function zcashUri(address, amount, memo) {
  const q = [];
  if (amount) q.push(`amount=${Number(amount)}`);
  // ZIP 321 memos are base64url without padding, shielded recipients only.
  if (memo) q.push(`memo=${Buffer.from(memo).toString('base64url')}`);
  return `zcash:${address}${q.length ? '?' + q.join('&') : ''}`;
}

function findContact(name) {
  if (!name) return null;
  const n = name.toLowerCase().replace(/'s$/, '');
  return contacts().find((c) => c.name.toLowerCase() === n || (c.aliases || []).includes(n)) || null;
}

function rules(text) {
  const t = text.toLowerCase();
  let m;

  // "send rahul $30 in zec": dollars, paid in shielded ZEC at the live price
  if ((m = t.match(/\b(?:send|pay)\s+(\w+)\s+\$(\d[\d,.]*)\s+in\s+zec\b/))) {
    const who = findContact(m[1]);
    return [{ kind: 'zec_send', usd: num(m[2]), name: who?.name || m[1], address: who?.zec || null, demo: !!who?.demo }];
  }
  // "send 0.1 zec to rahul", "pay rahul 0.1 zec"
  if ((m = t.match(/\b(?:send|pay|transfer)\s+(?:(\w+)\s+)?([\d.]+)\s*zec(?:\s+to\s+(\w+))?/))) {
    const who = findContact(m[3] || m[1]);
    return [{ kind: 'zec_send', amount: num(m[2]), name: who?.name || m[3] || m[1] || null, address: who?.zec || null, demo: !!who?.demo }];
  }
  // "invoice $150 in zec for the logo": a shielded request priced in dollars
  if ((m = t.match(/\b(?:invoice|bill|request)\s+(?:\w+\s+)?\$(\d[\d,.]*)\s+in\s+zec(?:\s+for\s+(.+))?/))) {
    return [{ kind: 'zec_request', usd: num(m[1]), memo: `Invoice${m[2] ? ' · ' + m[2].trim() : ''}` }];
  }
  // "request 0.5 zec"
  if ((m = t.match(/\b(?:request|owe me|ask(?:ing)? for)\s+([\d.]+)\s*zec/))) return [{ kind: 'zec_request', amount: num(m[1]) }];
  // "split $120 between 4"
  if ((m = t.match(/\bsplit\s+\$(\d[\d,.]*)\s+(?:between|with|among|by|in)\s+(\d+)/))) {
    const total = num(m[1]);
    const people = Number(m[2]);
    if (total && people > 1) return [{ kind: 'zec_request', usd: Math.round((total / people) * 100) / 100, split: { total, people } }];
  }
  // "take 150 usdc as zec from alex": they pay stablecoins, it lands as ZEC through NEAR Intents
  if ((m = t.match(/\btake\s+([\d.]+)\s*(usdc|sol|eth)\s+as\s+zec\b(?:\s+from\s+(\w+))?/))) {
    const who = findContact(m[3]);
    return [{ kind: 'swap_in', amount: num(m[1]), from: m[2].toUpperCase(), name: who?.name || m[3] || null, demo: !!who?.demo }];
  }
  // "swap 0.1 zec to usdc"
  if ((m = t.match(/\b(?:swap|convert|change)\s+([\d.]+)\s*(zec|usdc|sol|eth)\s+(?:to|for|into)\s+(zec|usdc|sol|eth)\b/))) {
    return [{ kind: 'swap', amount: num(m[1]), from: m[2].toUpperCase(), to: m[3].toUpperCase() }];
  }
  // "recharge mom's phone for $3", "top up my jio"
  if ((m = t.match(/\b(?:recharge|top\s?up|topup)\s+(?:my\s+)?(?:(\w+?)(?:'s)?\s+)?(?:(jio|airtel|vi|bsnl)\s+)?(?:phone\s*|number\s*)?(?:for\s+|with\s+)?(?:\$(\d[\d.]*))?/))) {
    let who = OPERATORS.includes(m[1]) ? null : findContact(m[1]);
    if (!who) who = findContact('me');
    return [{ kind: 'topup', usd: num(m[3] || 2.5), name: who?.name || m[1] || 'me', phone: who?.phone || null, operator: m[2] || who?.operator || 'jio', demo: !!who?.demo }];
  }
  // "send sakshi a $25 starbucks card"
  if ((m = t.match(new RegExp(`\\b(?:send|gift|buy|get)\\s+(?:(\\w+)\\s+)?(?:an?\\s+)?\\$?(\\d[\\d,.]*)?\\s*(${BRANDS.join('|')})(?:\\s+(?:gift\\s*card|card|credit))?(?:\\s+(?:to|for)\\s+(\\w+))?`)))) {
    const who = findContact(m[4] || m[1]);
    return [{ kind: 'gift', brand: m[3], product_id: BRAND_IDS[m[3]], usd: num(m[2] || 25), name: who?.name || null, email: who?.email || null, demo: !!who?.demo }];
  }
  // "esim for london"
  if ((m = t.match(/\besim\s+(?:for|in|to)\s+([a-z]+(?:\s[a-z]+)?)/))) return [{ kind: 'esim', country: m[1].replace(/\b(tomorrow|today|please)\b.*$/, '').trim() }];
  // "zec price", "$50 in zec", "0.1 zec in dollars"
  if (/\b(zec|zcash)\s+(price|rate)\b|\bprice of (zec|zcash)\b|how much is (a |one |1 )?(zec|zcash)/.test(t)) return [{ kind: 'price', amount: 1, unit: 'ZEC' }];
  if ((m = t.match(/\$(\d[\d,.]*)\s+(?:in|to)\s+zec\b/))) return [{ kind: 'price', amount: num(m[1]), unit: 'USD' }];
  if ((m = t.match(/\b([\d.]+)\s*zec\s+(?:in|to)\s+(usd|dollars)\b/))) return [{ kind: 'price', amount: num(m[1]), unit: 'ZEC' }];
  // A plain question gets an instant answer chip.
  if (/\?\s*$/.test(t) && t.split(/\s+/).length >= 4) return [{ kind: 'answer', question: text.trim() }];
  return [];
}

// Meeting talk: offer free slots from the calendar.
function meetChips(text, from) {
  const who = findContact(from);
  return cal.freeSlots(text).map((d) => ({ kind: 'meet', start: d.toISOString(), minutes: 30, with: who?.name || from || null, email: who?.email || null, event: `Call with ${who?.name || from || 'them'}` }));
}

// Labels the keyboard shows; the payload goes back unchanged when the chip is tapped.
function label(c) {
  switch (c.kind) {
    case 'zec_send':
      if (c.usd) return { title: `Send ${money(c.usd)} in ZEC to ${cap(c.name || '')}`, subtitle: c.address ? 'Shielded · live price' : 'No address saved' };
      return { title: `Send ${c.amount} ZEC${c.name ? ' to ' + cap(c.name) : ''}`, subtitle: c.address ? 'Shielded · Zcash' : 'No address saved' };
    case 'zec_request':
      if (c.split) return { title: `Split ${money(c.split.total)} by ${c.split.people}: ask ${money(c.usd)}`, subtitle: 'Paid in shielded ZEC' };
      if (c.usd) return { title: `Invoice ${money(c.usd)} in ZEC`, subtitle: 'Shielded · live price' };
      return { title: `Request ${c.amount} ZEC`, subtitle: 'Shielded link' };
    case 'swap_in':
      return { title: `Take ${c.amount} ${c.from} as ZEC`, subtitle: 'NEAR Intents · lands in Zcash' };
    case 'swap':
      return { title: `Swap ${c.amount} ${c.from} → ${c.to}`, subtitle: 'NEAR Intents' };
    case 'price':
      return { title: c.unit === 'USD' ? `${money(c.amount)} in ZEC` : `${c.amount} ZEC in dollars`, subtitle: 'Live price' };
    case 'answer':
      return { title: 'Ask Keyo', subtitle: c.question.slice(0, 32) };
    case 'schedule':
      return { title: `Every ${c.every} · ${label(c.chip).title}`, subtitle: 'Standing order · runs by itself' };
    case 'topup':
      return { title: `Recharge ${(c.name || '').toLowerCase() === 'me' ? 'my' : cap(c.name) + "'s"} ${cap(c.operator || 'phone')} · ${money(c.usd)}`, subtitle: c.phone ? c.phone.replace(/^(\+\d{1,2})(\d{2})\d+(\d{3})$/, '$1 $2•••••$3') : 'No number saved' };
    case 'gift':
      return { title: `${c.name ? 'Send ' + cap(c.name) + ' ' : ''}${money(c.usd)} ${cap(c.brand)} card`, subtitle: c.why ? cap(c.why) : c.email ? 'Emailed by Bitrefill' : 'Gift card · Bitrefill' };
    case 'esim':
      return { title: `eSIM for ${cap(c.country)}`, subtitle: 'Data on landing' };
    case 'meet':
      return { title: `${cal.dayLabel(c.start)} · ${cal.timeLabel(c.start)}`, subtitle: `Free · ${c.minutes} min${c.with ? ' with ' + c.with : ''}` };
    default:
      return { title: c.kind, subtitle: '' };
  }
}

// What the other person just said, turned into the command Keyo would run for you.
function replyCommand(incoming, from) {
  const t = incoming.toLowerCase();
  const who = (from || 'them').toLowerCase();
  const dollars = num(incoming.match(/\$\s?(\d[\d,.]*)/)?.[1] || 0);
  const people = Number(t.match(/\b(\d+)\s+(?:of us|people|ways|friends)\b/)?.[1] || 0);
  if (/\bevery month\b|\bmonthly\b|\bso i don'?t have to ask\b/.test(t)) return `every month recharge ${who}'s phone`;
  if (/\b(balance|recharge|data|validity)\b.*\b(over|finished|low|expired|ran out|run out)\b|\bcan'?t call\b/.test(t)) return `recharge ${who}'s phone`;
  if (dollars && people > 1 && /\b(your share|pay me back|send me)\b/.test(t)) return `send ${who} $${Math.round((dollars / people) * 100) / 100} in zec`;
  if (dollars && people > 1 && /\b(each|split|per head|owe)\b/.test(t)) return `split $${dollars} between ${people}`;
  if (/\b(usdc|stablecoins?|usdt)\b/.test(t)) return `take ${dollars || 100} usdc as zec from ${who}`;
  if (/\binvoice\b/.test(t) && dollars) return `invoice $${dollars} in zec`;
  if (/\b(call|meet|chat|catch up|hop on|sync)\b/.test(t) && /\b(this week|tomorrow|today|next week|monday|tuesday|wednesday|thursday|friday|free|when|time)\b/.test(t)) return 'meet:';
  if (/\bmy (birthday|bday)\b|\bit'?s my (birthday|bday)\b/.test(t)) return `shop:birthday gift for ${from}: two cards around $20 and one special card around $50`;
  if (/\b(landing in|landed in|flying to|going to|trip to)\s+([a-z]+)/.test(t)) return `esim for ${t.match(/\b(?:landing in|landed in|flying to|going to|trip to)\s+([a-z]+(?:\s[a-z]+)?)/)[1]}`;
  if (/\b(zec|zcash)\b.*\b(price|worth|rate)\b|how much is (?:a |one )?(zec|zcash)/.test(t)) return 'zec price';
  return null;
}

async function fromCommand(cmd, incoming, from) {
  if (!cmd) return [];
  if (cmd.startsWith('meet:')) return meetChips(incoming, from);
  if (cmd.startsWith('shop:')) {
    const want = cmd.slice(5).trim();
    const who = findContact(from);
    let found = await shop.picks(want);
    if (!found.length) found = await shop.picks(want);
    // The shopper is down: fall back to cards that always deliver instantly.
    if (!found.length) found = [['starbucks', 20], ['sephora', 25], ['doordash', 50]].map(([brand, usd]) => ({ kind: 'gift', brand, product_id: BRAND_IDS[brand], usd }));
    return found.map((c) => ({ ...c, name: who?.name || from || null, email: who?.email || null }));
  }
  if (cmd.startsWith('ask:')) return [{ kind: 'answer', question: cmd.slice(4).trim() || incoming }];
  const order = schedule.parse(cmd);
  if (order) {
    const inner = rules(order.command)[0];
    return inner ? [{ kind: 'schedule', every: order.every, chip: { ...inner, ...label(inner) } }] : [];
  }
  return rules(cmd);
}

// The agent's read of a message no rule knows: one Keyo command, or nothing.
export async function aiReply(incoming, from) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  const model = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
  const who = (from || 'them').toLowerCase();
  const prompt = `You are Keyo, a keyboard agent that runs errands for the user from chat messages. ${from || 'Someone'} just sent the user the message below. Pick the ONE errand that would help most, as a command in exactly one of these forms (fill the braces; amounts in US dollars):
recharge ${who}'s phone
send ${who} \${dollars} in zec
send {zec} zec to ${who}
split \${total} between {people}
invoice \${dollars} in zec
take {dollars} usdc as zec from ${who}
esim for {city or country}
get ${who} \${dollars} {brand} card   (brand one of: ${BRANDS.join(', ')})
meet:
shop:{what to buy, for whom, under $budget}
ask:{the question to answer}
zec price
none
Reply JSON only: {"command":"..."}

Message from ${from || 'them'}: ${incoming.slice(-400)}`;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 8000);
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
      method: 'POST',
      signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.1 } }),
    });
    clearTimeout(timer);
    const j = await r.json();
    const cmd = String(JSON.parse(j?.candidates?.[0]?.content?.parts?.[0]?.text || '{}').command || '').replace(/[{}]/g, '').trim();
    if (!cmd || cmd === 'none') return null;
    return /^(shop|ask|meet):/.test(cmd) ? cmd : cmd.toLowerCase();
  } catch {
    return null;
  }
}

const SHOP = /\b(gift|present|ideas?|what (?:should|can) i (?:get|buy|gift))\b.*\b(for|under|below|within)\b/;

export async function suggest(text, { incoming, from } = {}) {
  let chips = [];
  const typed = text.trim();
  if (typed) {
    // "every month recharge mom's phone" → a standing order around the inner action.
    const order = schedule.parse(typed);
    const inner = order ? rules(order.command)[0] : null;
    if (inner) chips = [{ kind: 'schedule', every: order.every, chip: { ...inner, ...label(inner) } }];
    else if (SHOP.test(typed.toLowerCase())) chips = await fromCommand(`shop:${typed}`, typed, null);
    else if (/\b(free|meet|call)\b.*\b(this week|tomorrow|monday|tuesday|wednesday|thursday|friday)\b/i.test(typed)) chips = meetChips(typed, null);
    else chips = rules(typed);
  } else if (incoming) {
    // Nothing typed yet: offer the reply the incoming message asks for. Known situations
    // answer instantly; for anything else Gemini reads the message and picks the errand.
    const cmd = replyCommand(incoming, from) || (await aiReply(incoming, from));
    chips = await fromCommand(cmd, incoming, from);
  }
  // Test contacts (no real number) never get charged.
  const sender = from ? findContact(from) : null;
  return chips.slice(0, 3).map((c, i) => {
    const who = findContact(c.name || c.with);
    const demo = c.demo || !!who?.demo || !!sender?.demo;
    return { id: `${Date.now()}-${i}`, ...label(c), ...c, demo };
  });
}
