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
    throw new Error(`Bitrefill ${res.status}: ${msg}`);
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
  const items = list(await search(brand, country)).filter((p) => !type || !p.type || p.type === type);
  if (!items.length) throw new Error(`No Bitrefill product for "${brand}" in ${country}`);
  const b = brand.toLowerCase();
  return (
    items.find((p) => (p.name || '').toLowerCase() === b) ||
    items.find((p) => (p.id || '').toLowerCase().startsWith(b)) ||
    items[0]
  );
}

// Returns { package_id } or { value } for the amount asked, plus the price Bitrefill will charge.
export function pickPackage(p, amount) {
  const pkgs = p.packages || [];
  if (pkgs.length) {
    // Values can be numbers ("10") or plan names ("₹199 – 1.5GB/day"): read the first number.
    const val = (k) => {
      const n = Number(k.value);
      if (Number.isFinite(n) && k.value !== '' && k.value != null) return n;
      const s = String(k.package_value ?? k.name ?? String(k.package_id || '').split('<&>')[1] ?? '');
      const m = s.replace(/,/g, '').match(/\d+(\.\d+)?/);
      return m ? Number(m[0]) : NaN;
    };
    const exact = pkgs.find((k) => val(k) === Number(amount));
    const above = pkgs.filter((k) => val(k) >= Number(amount)).sort((a, b) => val(a) - val(b))[0];
    const k = exact || above || pkgs[pkgs.length - 1];
    return { package_id: k.package_id, value: val(k), price: k.price ?? k.payment_price, name: k.name || k.package_value };
  }
  if (p.range) {
    const v = Math.min(Math.max(Number(amount), p.range.min), p.range.max);
    return { value: v };
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

export const invoice = (id) => call(`/invoices/${encodeURIComponent(id)}`);
export const order = (id) => call(`/orders/${encodeURIComponent(id)}`);

// Paid isn't delivered: poll the order until it lands or we run out of time.
export async function waitDelivered(inv, timeoutMs = 40_000) {
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
    current = await invoice(current.id);
  }
  return { invoice: current, order: null, pending: true };
}
