// Bitrefill REST API v2: search, pick a package, buy from balance, read the order.
const BASE = 'https://api.bitrefill.com/v2';

function headers() {
  const key = process.env.BITREFILL_API_KEY;
  if (!key) throw new Error('BITREFILL_API_KEY is not set in server/.env');
  return { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
}

async function call(path, init = {}) {
  const res = await fetch(BASE + path, { ...init, headers: headers() });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = body?.error?.message || body?.message || JSON.stringify(body).slice(0, 200);
    throw new Error(`Bitrefill: ${msg}`);
  }
  return body.data ?? body;
}

// The catalog barely changes during a demo, so cache it instead of searching in a loop.
const cache = new Map();
async function cached(key, fn) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < 10 * 60_000) return hit.value;
  const value = await fn();
  cache.set(key, { at: Date.now(), value });
  return value;
}

export const balance = () => call('/accounts/balance');

export function search(q, country = 'IN') {
  return cached(`s:${q}:${country}`, () =>
    call(`/products/search?q=${encodeURIComponent(q)}&country=${country}&limit=10`));
}

export function product(id) {
  return cached(`p:${id}`, () => call(`/products/${encodeURIComponent(id)}`));
}

export function checkPhone(phone) {
  return call(`/check_phone_number?phone_number=${encodeURIComponent(phone)}`);
}

const list = (x) => (Array.isArray(x) ? x : x?.products || x?.items || x?.results || []);

// Picks the product whose name best matches the brand, preferring exact matches.
export async function findProduct(brand, { country = 'IN', type } = {}) {
  // Search ignores the country, so filter it here ("airtel" returns Nigeria first).
  const all = list(await search(brand, country));
  const items = all.filter((p) => !country || p.country_code === country).filter((p) => !type || (p.categories || []).includes(type) || p.recipient_type === type);
  if (!items.length) throw new Error(`No Bitrefill product for "${brand}" in ${country}`);
  const b = brand.toLowerCase();
  return (
    items.find((p) => (p.base_name || '').toLowerCase() === b) ||
    items.find((p) => (p.id || '').toLowerCase().startsWith(b)) ||
    items[0]
  );
}

// Packages look like { id, value, amount (face value in the product's currency), price }.
// Plans have names for values ("30GB – 30 Day Data Pack"), so match on the rupee amount.
export function pickPackage(p, amount) {
  // Fixed packages carry the face value in `amount` (or only in `value` for some brands).
  const face = (k) => Number(k.amount ?? k.value);
  const pkgs = (p.packages || []).filter((k) => Number.isFinite(face(k)));
  const want = Number(amount);
  if (p.range && (!pkgs.length || !pkgs.some((k) => face(k) === want))) {
    const v = Math.round(Math.min(Math.max(want, p.range.min), p.range.max));
    return { value: v, local: v, exact: v === want };
  }
  if (pkgs.length) {
    const exact = pkgs.find((k) => face(k) === want);
    const k = exact || [...pkgs].sort((a, b) => Math.abs(face(a) - want) - Math.abs(face(b) - want))[0];
    const named = !/^\d+(\.\d+)?$/.test(String(k.value));
    return { package_id: k.id, value: k.value, local: face(k), plan: named ? k.value : null, exact: !!exact };
  }
  throw new Error(`${p.name || p.id} has no packages`);
}

export async function buy({ product_id, package_id, value, phone_number }) {
  const item = { product_id, quantity: 1 };
  if (package_id) item.package_id = package_id;
  else item.value = value;
  if (phone_number) item.phone_number = phone_number;
  return call('/invoices', {
    method: 'POST',
    body: JSON.stringify({ products: [item], payment_method: 'balance', auto_pay: true }),
  });
}

// eSIMs have their own endpoints; ids look like bitrefill-esim-united-arab-emirates.
const PLACES = {
  dubai: 'united-arab-emirates', 'abu dhabi': 'united-arab-emirates', uae: 'united-arab-emirates',
  london: 'united-kingdom', uk: 'united-kingdom', england: 'united-kingdom',
  bangkok: 'thailand', phuket: 'thailand', bali: 'indonesia', tokyo: 'japan', osaka: 'japan',
  paris: 'france', rome: 'italy', milan: 'italy', berlin: 'germany', amsterdam: 'netherlands',
  'new york': 'united-states', usa: 'united-states', us: 'united-states', america: 'united-states', 'san francisco': 'united-states',
  singapore: 'singapore', 'kuala lumpur': 'malaysia', istanbul: 'turkey', europe: 'europe', vietnam: 'vietnam', hanoi: 'vietnam',
  'sri lanka': 'sri-lanka', colombo: 'sri-lanka', nepal: 'nepal', kathmandu: 'nepal', maldives: 'maldives', seoul: 'south-korea', korea: 'south-korea',
};
export async function esimFor(place) {
  const p = place.toLowerCase().trim();
  const slug = PLACES[p] || p.replace(/\s+/g, '-');
  return cached(`e:${slug}`, () => call(`/products/esims/bitrefill-esim-${encodeURIComponent(slug)}`));
}
export function buyEsim({ product_id, value }) {
  return call('/esims', {
    method: 'POST',
    body: JSON.stringify({ products: [{ product_id, value, quantity: 1 }], payment_method: 'balance', auto_pay: true }),
  });
}

export const invoice = (id, esim = false) => call(`${esim ? '/esims/invoice' : '/invoices'}/${encodeURIComponent(id)}`);
export const order = (id) => call(`/orders/${encodeURIComponent(id)}`);

// Paid isn't delivered: poll the order until it lands or we run out of time.
export async function waitDelivered(inv, { esim = false, timeoutMs = 40_000 } = {}) {
  const start = Date.now();
  let current = inv;
  while (Date.now() - start < timeoutMs) {
    const orderId = current?.orders?.[0]?.id;
    if (orderId) {
      const o = await order(orderId);
      if (['delivered', 'complete', 'completed'].includes(o.status)) return { invoice: current, order: o };
      if (['failed', 'refunded', 'cancelled'].includes(o.status)) throw new Error(`Order ${o.status}`);
    }
    await new Promise((r) => setTimeout(r, 2500));
    current = await invoice(current.id, esim);
  }
  return { invoice: current, order: null, pending: true };
}
