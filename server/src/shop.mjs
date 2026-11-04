// Keyo's shopper: turns "gift for dad under ₹1000" into real Bitrefill products.
// The catalog comes from Bitrefill; Gemini only chooses from it.

const BASE = 'https://api.bitrefill.com/v2';
let catalogCache = { at: 0, items: [] };

export async function catalog(country = 'IN') {
  if (Date.now() - catalogCache.at < 3600_000 && catalogCache.items.length) return catalogCache.items;
  const items = [];
  for (let start = 0; start < 600; start += 50) {
    const r = await fetch(`${BASE}/products?country=${country}&limit=50&start=${start}`, {
      headers: { Authorization: `Bearer ${process.env.BITREFILL_API_KEY}` },
    }).then((x) => x.json());
    const page = r.data || [];
    for (const p of page) {
      const cats = p.categories || [];
      if (!p.in_stock || cats.includes('refill') || cats.includes('bundles') || p.recipient_type === 'phone_number') continue;
      const amounts = (p.packages || []).map((k) => Number(k.amount)).filter(Number.isFinite).sort((a, b) => a - b);
      if (!amounts.length) continue;
      items.push({ id: p.id, name: p.base_name || p.name, cats, amounts });
    }
    if (page.length < 50) break;
  }
  catalogCache = { at: Date.now(), items };
  return items;
}

// Swiggy vouchers take days to arrive; never suggest them for a gift right now.
const SLOW = new Set(['swiggy-money-india']);

export async function picks(request, { budget } = {}) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return [];
  const items = (await catalog()).filter((p) => !SLOW.has(p.id));
  const list = items.map((p) => `${p.id} | ${p.name} | ${p.cats.join('/')} | ₹${p.amounts.slice(0, 6).join(',')}`).join('\n');
  const prompt = `You are a gifting assistant inside a keyboard in India. From this catalog of digital gift cards (id | brand | categories | ₹ amounts available), choose the 3 best for the request. Pick an amount from that brand's list${budget ? `, at most ₹${budget}` : ''}. Prefer instant, widely loved brands.
Reply JSON only: {"picks":[{"id":"...","amount":number,"why":"3-5 words"}]}

Request: """${request.slice(-300)}"""

Catalog:
${list}`;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 6000);
    const model = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
      method: 'POST',
      signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.4 } }),
    });
    clearTimeout(timer);
    const j = await r.json();
    const out = JSON.parse(j?.candidates?.[0]?.content?.parts?.[0]?.text || '{}').picks || [];
    const byId = new Map(items.map((p) => [p.id, p]));
    return out
      .filter((x) => byId.has(x.id))
      .slice(0, 3)
      .map((x) => {
        const p = byId.get(x.id);
        const want = Number(x.amount) || p.amounts[0];
        const amount = p.amounts.reduce((best, a) => (Math.abs(a - want) < Math.abs(best - want) && (!budget || a <= budget) ? a : best), p.amounts[0]);
        return { kind: 'gift', product_id: p.id, brand: p.name, amount, why: x.why };
      });
  } catch {
    return [];
  }
}
