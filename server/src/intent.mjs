// Turns what the user is typing into action chips for the keyboard strip.
// Fast regex rules first; Gemini only for free-form text the rules miss.
import { contacts } from './store.mjs';
import * as schedule from './schedule.mjs';
import * as shop from './shop.mjs';

const OPERATORS = ['jio', 'airtel', 'vi', 'bsnl'];
// Brands people name in chat, and the Bitrefill India product each one buys.
export const BRAND_IDS = {
  flipkart: 'flipkart-india', zomato: 'zomato-india', swiggy: 'swiggy-money-india', myntra: 'myntra-india', uber: 'uber-india',
  bookmyshow: 'bookmyshow-voucher-india', hotstar: 'hotstar-india', makemytrip: 'makemytrip-voucher-india', apollo: 'apollo-pharmacy-india',
  bigbasket: 'bigbasket-india', blinkit: 'blink-it-india', jiomart: 'jiomart-india', phonepe: 'phonepe-india', nykaa: 'nykaa-india',
  starbucks: 'starbucks-india', dominos: 'dominos-india', pvr: 'pvr-cinemas-india', valorant: 'valorant-india', steam: 'steam-india',
  xbox: 'xbox-india', 'google play': 'google-play-india', 'app store': 'app-store-and-itunes-inr-india', prime: 'amazon-prime-subscription-india',
  croma: 'croma-voucher-india', ikea: 'ikea-india', decathlon: 'decathlon-india', 'pizza hut': 'pizza-hut-india', kfc: 'kfc-india', subway: 'subway-india',
  ajio: 'ajio-india', tanishq: 'tanishq-gold-jewellery-india', cleartrip: 'cleartrip-voucher-india', 'costa': 'costa-coffee-india',
};
const BRANDS = Object.keys(BRAND_IDS);
const BRAND_RE = BRANDS.map((b) => b.replace(' ', '\\s?')).join('|');
// TV (DTH) providers and their Bitrefill products; the contact's subscriber ID is the refill input.
const DTH = { 'tata play': 'tata-play-india', 'tata sky': 'tata-play-india', 'dish tv': 'dth-dish-tv-india', 'airtel dth': 'dth-airtel-india', d2h: 'd2h-dth-india', 'sun direct': 'sun-direct-dth-india' };
const OCCASIONS = [
  [/\b(happy\s*b(irth)?day|hbd|bday)\b/i, 'birthday', ['flipkart', 'zomato']],
  [/\bcongrat(s|ulations)?\b/i, 'congrats', ['flipkart', 'zomato']],
  [/\b(anniversary)\b/i, 'anniversary', ['bookmyshow', 'flipkart']],
  [/\b(get well|feel better)\b/i, 'get well', ['apollo', 'zomato']],
  [/\b(thank(s| you) so much|owe you one)\b/i, 'thanks', ['zomato', 'flipkart']],
  [/\b(hungry|starving|no food|order (some )?food)\b/i, 'food', ['zomato', 'swiggy']],
];
const TRIPS = /\b(?:going to|flying to|landing in|trip to|travell?ing to|landed in|reach(?:ing)?)\s+([a-z]+(?:\s[a-z]+)?)/i;

const num = (s) => Number(String(s).replace(/[,₹]/g, ''));
const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1);

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
  const chips = [];

  // "send rahul ₹800 in zec": rupees, paid in shielded ZEC at the live price
  let m = t.match(/\b(?:send|pay)\s+(\w+)\s+(?:₹|rs\.?\s?)(\d[\d,]*)\s+in\s+zec\b/);
  if (m) {
    const who = findContact(m[1]);
    chips.push({ kind: 'zec_send', inr: num(m[2]), name: who?.name || m[1], address: who?.zec || null, demo: !!who?.demo });
    return chips;
  }

  // "invoice $150 in zec": a shielded request priced in dollars
  m = t.match(/\b(?:invoice|bill|request)\s+(?:\w+\s+)?\$(\d[\d,.]*)\s+in\s+zec(?:\s+for\s+(.+))?/);
  if (m) {
    chips.push({ kind: 'zec_request', usd: num(m[1]), memo: `Invoice${m[2] ? ' · ' + m[2].trim() : ''}` });
    return chips;
  }

  // "take 150 usdc as zec": they pay stablecoins, it lands as ZEC through NEAR Intents
  m = t.match(/\btake\s+([\d.]+)\s*(usdc|sol|eth)\s+as\s+zec\b(?:\s+from\s+(\w+))?/);
  if (m) {
    const who = findContact(m[3]);
    chips.push({ kind: 'swap_in', amount: num(m[1]), from: m[2].toUpperCase(), name: who?.name || m[3] || null, demo: !!who?.demo });
    return chips;
  }

  // "recharge mom's tata play for 350"
  m = t.match(/\b(?:recharge|top\s?up|pay)\s+(?:my\s+)?(?:(\w+?)(?:'s)?\s+)?(tata play|tata sky|dish tv|airtel dth|d2h|sun direct|tv|dth)\b(?:\s+(?:for|with|of))?\s*(?:₹|rs\.?\s?)?(\d[\d,]*)?/);
  if (m) {
    const who = findContact(m[1] || 'me');
    const provider = DTH[m[2]] ? m[2] : who?.dthProvider || 'tata play';
    chips.push({ kind: 'dth', provider, product_id: DTH[provider], amount: num(m[3] || 350), name: who?.name || m[1] || 'me', subscriber: who?.dth || null, demo: !!who?.demo });
    return chips;
  }

  // "send 0.1 zec to rahul", "pay rahul 0.1 zec"
  m = t.match(/\b(?:send|pay|transfer)\s+(?:(\w+)\s+)?([\d.]+)\s*zec(?:\s+to\s+(\w+))?/);
  if (m) {
    const who = findContact(m[3] || m[1]);
    chips.push({ kind: 'zec_send', amount: num(m[2]), name: who?.name || m[3] || m[1] || null, address: who?.zec || null, demo: !!who?.demo });
  }

  // "request 0.5 zec", "you owe me 0.2 zec"
  m = t.match(/\b(?:request|owe me|send me|ask(?:ing)? for)\s+([\d.]+)\s*zec/);
  if (m) chips.push({ kind: 'zec_request', amount: num(m[1]) });

  // "swap 20 usdc to zec"
  m = t.match(/\b(?:swap|convert|change)\s+([\d.]+)\s*(zec|usdc|sol|eth)\s+(?:to|for|into)\s+(zec|usdc|sol|eth)\b/);
  if (m) chips.push({ kind: 'swap', amount: num(m[1]), from: m[2].toUpperCase(), to: m[3].toUpperCase() });

  // "recharge mom's jio for 199", "top up my airtel 10"
  m = t.match(/\b(?:recharge|top\s?up|topup)\s+(?:my\s+)?(?:(\w+?)(?:'s)?\s+)?(?:(jio|airtel|vi|bsnl)\s+)?(?:phone\s+|number\s+)?(?:for\s+|with\s+|of\s+)?(?:₹|rs\.?\s?|inr\s?)?(\d[\d,]*)/);
  if (m) {
    let who = OPERATORS.includes(m[1]) ? null : findContact(m[1]);
    if (!who && (m[1] === undefined || m[1] === 'my' || OPERATORS.includes(m[1]))) who = findContact('me');
    const operator = m[2] || (OPERATORS.includes(m[1]) ? m[1] : null) || who?.operator || null;
    chips.push({ kind: 'topup', amount: num(m[3]), name: who?.name || m[1] || 'me', phone: who?.phone || null, operator, demo: !!who?.demo });
  }

  // "send mom a ₹500 swiggy gift card", "gift rahul 200 amazon"
  m = t.match(new RegExp(`\\b(?:send|gift|buy|get)\\s+(?:(\\w+)\\s+)?(?:an?\\s+)?(?:₹|rs\\.?\\s?)?(\\d[\\d,]*)?\\s*(?:rs\\.?\\s*|rupees?\\s*)?(${BRAND_RE})(?:\\s+(?:gift\\s*card|voucher|card|points|credit|tickets?))?(?:\\s+(?:of|for|worth)\\s+(?:₹|rs\\.?\\s?)?(\\d[\\d,]*))?(?:\\s+(?:to|for)\\s+(\\w+))?`));
  if (m && !chips.some((c) => c.kind === 'zec_send')) {
    const who = findContact(m[5] || m[1]);
    const brand = m[3].replace(/\s+/g, ' ');
    chips.push({ kind: 'gift', brand, product_id: BRAND_IDS[brand], amount: num(m[2] || m[4] || 100), name: who?.name || m[5] || (m[1] && !['a', 'me', 'some'].includes(m[1]) ? m[1] : null), email: who?.email || null, demo: !!who?.demo });
  }

  // "esim for dubai", "get mom an esim in london"
  m = t.match(/\besim\s+(?:for|in|to)\s+([a-z]+(?:\s[a-z]+)?)/);
  if (m) chips.push({ kind: 'esim', country: m[1].replace(/\b(tomorrow|today|tonight|please|pls)\b.*$/, '').trim() });

  // "split 1200 between 4", "dinner was ₹1200 split with 3 people"
  m = t.match(/(?:₹|rs\.?\s?)?(\d[\d,]*)\D{0,30}?\bsplit\b\D{0,20}?(\d+)|\bsplit\s+(?:₹|rs\.?\s?)?(\d[\d,]*)\s+(?:between|with|among|by|in)\s+(\d+)/);
  if (m) {
    const total = num(m[1] || m[3]);
    const people = Number(m[2] || m[4]);
    if (total && people > 1) chips.push({ kind: 'zec_request', inr: Math.round(total / people), split: { total, people } });
  }

  // "zec price", "₹500 in zec", "0.1 zec in rupees"
  if (/\b(zec|zcash)\s+(price|rate)\b|\bprice of (zec|zcash)\b|how much is (a |one |1 )?(zec|zcash)/.test(t)) chips.push({ kind: 'price', amount: 1, unit: 'ZEC' });
  m = t.match(/(?:₹|rs\.?\s?)(\d[\d,]*)\s+(?:in|to)\s+zec\b|\b(\d[\d,]*)\s*(?:rupees|inr)\s+(?:in|to)\s+zec\b/);
  if (m) chips.push({ kind: 'price', amount: num(m[1] || m[2]), unit: 'INR' });
  m = t.match(/\b([\d.]+)\s*zec\s+(?:in|to)\s+(rupees|inr|usd|dollars)\b/);
  if (m) chips.push({ kind: 'price', amount: num(m[1]), unit: 'ZEC' });

  // Occasion words suggest a gift card nobody asked for yet.
  if (!chips.length) {
    for (const [re, occasion, brands] of OCCASIONS) {
      if (re.test(t)) {
        for (const brand of brands) chips.push({ kind: 'gift', brand, amount: 100, occasion });
        break;
      }
    }
  }

  // Travel talk suggests an eSIM.
  m = t.match(TRIPS);
  if (m && !chips.length) {
    const place = m[1].replace(/\b(next|this|tomorrow|today|tonight|soon|week|month|morning|evening|night|on|for|in|at|by)\b.*$/, '').trim();
    if (place && !['the', 'my', 'a', 'office', 'home', 'work'].includes(place)) chips.push({ kind: 'esim', country: place });
  }

  // Low balance talk suggests a top-up for yourself.
  if (!chips.length && /\b(balance (is )?(over|finished|low|khatam)|data (is )?(over|finished)|no data|recharge (khatam|over|expired))\b/.test(t)) {
    const me = findContact('me');
    chips.push({ kind: 'topup', amount: 199, name: 'me', phone: me?.phone || null, operator: me?.operator || 'jio' });
  }
  // A plain question gets an instant answer chip.
  if (!chips.length && /\?\s*$/.test(t) && t.split(/\s+/).length >= 4) chips.push({ kind: 'answer', question: text.trim() });
  return chips;
}

async function ai(text) {
  const key = process.env.GEMINI_API_KEY;
  if (!key || text.trim().length < 12) return [];
  const model = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
  const names = contacts().map((c) => c.name).join(', ');
  const prompt = `You suggest at most 2 actions for a phone keyboard in India, from the message the user is typing.
Actions (JSON objects):
{"kind":"gift","brand":one of ${BRANDS.join('|')},"amount":INR number,"name":recipient or null,"occasion":short word}
{"kind":"topup","name":who,"operator":"jio|airtel|vi|bsnl","amount":INR number}
{"kind":"esim","country":"country name"}
{"kind":"zec_send","name":who,"amount":ZEC number}
{"kind":"zec_request","amount":ZEC number}
Only suggest an action the message clearly invites. Known contacts: ${names}.
Reply with JSON only: {"chips":[...]} (empty list if nothing fits).
Message: """${text.slice(-400)}"""`;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 3500);
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
      method: 'POST',
      signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: 'application/json', temperature: 0.2 },
      }),
    });
    clearTimeout(timer);
    const j = await r.json();
    const raw = j?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
    const chips = (JSON.parse(raw).chips || []).filter((c) => ['gift', 'topup', 'esim', 'zec_send', 'zec_request'].includes(c.kind));
    return chips.slice(0, 2).map((c) => {
      const who = findContact(c.name);
      if (c.kind === 'topup') return { ...c, phone: who?.phone || null, operator: c.operator || who?.operator, name: who?.name || c.name };
      if (c.kind === 'zec_send') return { ...c, address: who?.zec || null, name: who?.name || c.name };
      if (c.kind === 'gift') return { ...c, brand: BRANDS.includes(c.brand) ? c.brand : 'flipkart', amount: Number(c.amount) || 100 };
      return c;
    });
  } catch {
    return [];
  }
}

// Labels the keyboard shows; the payload goes back unchanged when the chip is tapped.
function label(c) {
  switch (c.kind) {
    case 'zec_send':
      if (c.inr) return { title: `Send ₹${c.inr} in ZEC to ${cap(c.name || '')}`, subtitle: c.address ? 'Shielded · live price' : 'No address saved' };
      return { title: `Send ${c.amount} ZEC${c.name ? ' to ' + cap(c.name) : ''}`, subtitle: c.address ? 'Shielded · Zcash' : 'No address saved' };
    case 'zec_request':
      if (c.split) return { title: `Split ₹${c.split.total} by ${c.split.people}: ask ₹${c.inr}`, subtitle: 'Paid in shielded ZEC' };
      if (c.usd) return { title: `Invoice $${c.usd} in ZEC`, subtitle: 'Shielded · live price' };
      return { title: `Request ${c.amount} ZEC`, subtitle: 'Shielded link' };
    case 'swap_in':
      return { title: `Take ${c.amount} ${c.from} as ZEC`, subtitle: 'NEAR Intents · lands in Zcash' };
    case 'dth':
      return { title: `Recharge ${(c.name || '').toLowerCase() === 'me' ? 'my' : cap(c.name) + "'s"} ${c.provider.replace(/\b\w/g, (x) => x.toUpperCase())} ₹${c.amount}`, subtitle: c.subscriber ? `TV · ID ••••${c.subscriber.slice(-4)}` : 'No TV ID saved' };
    case 'price':
      return { title: c.unit === 'INR' ? `₹${c.amount} in ZEC` : `${c.amount} ZEC in ₹ and $`, subtitle: 'Live price' };
    case 'answer':
      return { title: 'Ask Keyo', subtitle: c.question.slice(0, 32) };
    case 'schedule':
      return { title: `Every ${c.every} · ${label(c.chip).title}`, subtitle: 'Standing order · runs by itself' };
    case 'swap':
      return { title: `Swap ${c.amount} ${c.from} → ${c.to}`, subtitle: 'NEAR Intents' };
    case 'topup':
      return { title: `Recharge ${(c.name || '').toLowerCase() === 'me' ? 'my' : cap(c.name) + "'s"} ${cap(c.operator || 'phone')} ₹${c.amount}`, subtitle: c.phone ? c.phone.replace(/^(\+\d{2})(\d{2})\d+(\d{3})$/, '$1 $2•••••$3') : 'No number saved' };
    case 'gift':
      return { title: `${c.name ? 'Send ' + cap(c.name) + ' ' : ''}₹${c.amount} ${cap(c.brand)} card`, subtitle: c.why ? cap(c.why) : c.occasion ? `Gift for the ${c.occasion}` : 'Gift card · Bitrefill' };
    case 'esim':
      return { title: `eSIM for ${cap(c.country)}`, subtitle: 'Data on landing' };
    default:
      return { title: c.kind, subtitle: '' };
  }
}

// What the other person just said, turned into the reply command Keyo would run for you.
function replyCommand(incoming, from) {
  const t = incoming.toLowerCase();
  const who = (from || 'them').toLowerCase();
  let m;
  const rupees = num(incoming.match(/(?:₹|rs\.?\s?)(\d[\d,]*)/i)?.[1] || 0);
  const people = Number(t.match(/\b(\d+)\s+(?:of us|people|ways|friends)\b|\b(?:the|all)\s+(\d+)\s+of us\b/)?.slice(1).find(Boolean) || 0);
  const dollars = num(incoming.match(/\$\s?(\d[\d,.]*)/)?.[1] || 0);
  if (rupees && people > 1 && /\b(your share|pay me back|send me)\b/.test(t)) return `send ${who} ₹${Math.round(rupees / people)} in zec`;
  if (rupees && people > 1 && /\b(each|split|per head|owe)\b/.test(t)) return `split ${rupees} between ${people}`;
  if (/\b(usdc|stablecoins?|usdt)\b/.test(t)) return `take ${dollars || 100} usdc as zec from ${who}`;
  if (/\binvoice\b/.test(t) && dollars) return `invoice $${dollars} in zec${(m = t.match(/\b(?:the|your) (\w+) (?:is|looks)/)) ? ' for ' + m[1] : ''}`;
  if (/\b(tv|tata play|tata sky|dish tv|dth|d2h)\b/.test(t) && /\b(recharge|stopped|expired|not working|off)\b/.test(t)) return `recharge ${who}'s tata play for 350`;
  if (/\bvalorant\b|\bout of (?:vp|points)\b/.test(t)) return `get ${who} 475 valorant points`;
  if (/\bsteam\b/.test(t)) return `get ${who} 650 steam card`;
  if (/\bmovie\b|\bfilm\b/.test(t)) return `get ${who} 500 pvr tickets`;
  if (/\b(lunch|pizza|domino'?s)\b/.test(t)) return 'buy a ₹500 dominos card';
  if (/\b(coffee|starbucks)\b/.test(t)) return `get ${who} 1000 starbucks card`;
  if (/\bmy (birthday|bday)\b|\bit'?s my (birthday|bday)\b/.test(t)) return `shop:birthday gift for ${from} under 500`;
  if (/\bevery month\b|\bmonthly\b|\bso i don'?t have to ask\b/.test(t) && /\b(recharge|top ?up|phone|balance)\b/.test(t)) return `every month recharge ${who}'s phone for 199`;
  if (/\b(balance|recharge|data|validity)\b.*\b(over|finished|low|expired|khatam)\b|\bcan'?t call\b/.test(t)) return `recharge ${who}'s phone for 199`;
  if (/\b(gift|present)\b.*\b(ideas?|suggest|what (?:should|can))\b|\bwhat (?:should|can) (?:i|we) (?:get|gift)\b/.test(t)) return incoming;
  if ((m = t.match(/\b(?:send|give|pay)\s+me\s+([\d.]+)\s*zec/))) return `send ${m[1]} zec to ${who}`;
  if (/\bwhat do i owe\b|\bhow much do i owe\b|\bmy share\b/.test(t)) return 'request 0.05 zec for dinner';
  if ((m = t.match(/(?:₹|rs\.?\s?)(\d[\d,]*)\s+(swiggy|zomato|amazon|flipkart|blinkit|myntra|uber|bookmyshow)/))) return `send ${who} a ${m[1]} ${m[2]} gift card`;
  if ((m = t.match(/\b(?:landing in|flying to|going to|trip to|travell?ing to)\s+([a-z]+(?:\s[a-z]+)?)/))) return `get ${who} an esim for ${m[1].replace(/\b(tomorrow|today|tonight|next|this)\b.*$/, '').trim()}`;
  if (/\b(zec|zcash)\b.*\b(dollars|usd|usdc|cash out)\b/.test(t)) return 'swap 0.01 zec to usdc';
  if (/\bbirthday\b/.test(t)) {
    const name = incoming.match(/\b([A-Z][a-z]+)'s birthday/)?.[1];
    return `happy birthday${name ? ' ' + name.toLowerCase() : ''}!`;
  }
  if (/\b(tired to cook|hungry|starving|nothing to eat|no food)\b/.test(t)) return 'order some food';
  if (/\b(zec|zcash)\b.*\b(price|worth|rate)\b|how much is (?:a |one )?(zec|zcash)/.test(t)) return 'zec price';
  if (/\?\s*$/.test(t) && t.split(/\s+/).length >= 4) return incoming;
  return null;
}

const t0 = (s) => s.toLowerCase();
const SHOP = /\b(gift|present|something|ideas?|what (?:should|can) i (?:get|buy|gift))\b.*\b(for|under|below|within)\b|\b(movie night|date night|housewarming|anniversary gift|diwali gift|wedding gift)\b/;

async function fromCommand(cmd, incoming, from) {
  if (!cmd) return [];
  if (cmd.startsWith('shop:')) {
    const want = cmd.slice(5).trim();
    const budget = num(want.match(/under\s*(?:₹)?(\d[\d,]*)/)?.[1] || 0) || undefined;
    const who = findContact(from);
    let found = await shop.picks(want, { budget });
    if (!found.length) found = await shop.picks(want, { budget });
    // The shopper is down: fall back to cards that always deliver instantly.
    if (!found.length) found = ['flipkart', 'zomato', 'bookmyshow'].map((brand) => ({ kind: 'gift', brand, product_id: BRAND_IDS[brand], amount: Math.min(budget || 500, 500) }));
    return found.map((c) => ({ ...c, name: who?.name || from || null, email: who?.email || null }));
  }
  if (cmd.startsWith('ask:')) return [{ kind: 'answer', question: cmd.slice(4).trim() || incoming }];
  const order = schedule.parse(cmd);
  if (order) {
    const inner = rules(order.command)[0];
    return inner ? [{ kind: 'schedule', every: order.every, chip: { ...inner, ...label(inner) } }] : [];
  }
  if (cmd === incoming && SHOP.test(t0(incoming))) return [];
  return rules(cmd);
}

// The agent's read of a message no rule knows: one Keyo command, or nothing.
export async function aiReply(incoming, from) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  const model = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
  const who = (from || 'them').toLowerCase();
  const prompt = `You are Keyo, a keyboard agent in India that runs errands for the user from chat messages. ${from || 'Someone'} just sent the user the message below. Pick the ONE errand that would help most, as a command in exactly one of these forms (fill the braces):
recharge ${who}'s phone for {rupees}
recharge ${who}'s tata play for {rupees}
send ${who} ₹{rupees} in zec
send {zec} zec to ${who}
split {total rupees} between {people}
invoice $\{dollars} in zec
take {dollars} usdc as zec from ${who}
get ${who} an esim for {city or country}
get ${who} {rupees} {brand} card   (brand one of: ${BRANDS.join(', ')})
shop:{what to buy, for whom, under ₹budget}
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
    return /^(shop|ask):/.test(cmd) ? cmd : String(cmd).toLowerCase();
  } catch {
    return null;
  }
}

export async function suggest(text, { incoming, from } = {}) {
  // "every month recharge mom's jio for 199" → a standing order around the inner action.
  const order = text.trim() ? schedule.parse(text) : null;
  if (order) {
    const inner = rules(order.command)[0];
    if (inner) {
      const chip = { kind: 'schedule', every: order.every, chip: { ...inner, ...label(inner) } };
      return [{ id: `${Date.now()}-0`, ...label(chip), ...chip }];
    }
  }
  let chips = rules(text);
  // Open-ended shopping goes to the shopper, which chooses from Bitrefill's real catalog.
  const ask = text.trim() || incoming || '';
  if ((!chips.length || chips.every((c) => c.kind === 'answer')) && SHOP.test(ask.toLowerCase())) {
    const budget = num(ask.match(/(?:under|below|within|upto|up to)\s*(?:₹|rs\.?\s?)?(\d[\d,]*)/i)?.[1] || 0) || undefined;
    const who = ask.match(/\bfor (?:my |your )?(mom|dad|bro|sis|wife|husband|[A-Z][a-z]+)\b/)?.[1] || ask.match(/\b([A-Z][a-z]+)'s (?:last day|birthday|farewell|anniversary|wedding)/)?.[1];
    const found = await shop.picks(ask, { budget });
    const person = who ? findContact(who) : null;
    if (found.length) chips = found.map((c) => ({ ...c, name: person?.name || null, email: person?.email || null }));
  }
  // Nothing typed yet: offer the reply the incoming message asks for.
  if (!chips.length && !text.trim() && incoming) {
    // Known situations answer instantly; for anything else Gemini reads the message and picks the errand.
    const cmd = replyCommand(incoming, from) || (await aiReply(incoming, from));
    chips = await fromCommand(cmd, incoming, from);
  }
  if (!chips.length && text.trim()) chips = await ai(text);
  // People without a real number (the test chat's Mom) never get charged.
  const sender = from ? findContact(from) : null;
  return chips.slice(0, 3).map((c, i) => {
    const who = findContact(c.name);
    const demo = c.demo || !!who?.demo || (!!sender?.demo && (!c.name || c.name.toLowerCase() === sender.name.toLowerCase()));
    return { id: `${Date.now()}-${i}`, ...label(c), ...c, demo };
  });
}
