import crypto from 'node:crypto';
// Keyo server: the keyboard's brain. Suggests actions, buys through Bitrefill, swaps
// through NEAR Intents and sends shielded ZEC from the server wallet.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as br from './bitrefill.mjs';
import * as mcp from './mcp.mjs';
import * as swap from './swap.mjs';
import * as zec from './zec.mjs';
import { suggest, zcashUri } from './intent.mjs';
import * as store from './store.mjs';
import * as schedule from './schedule.mjs';
import * as cal from './calendar.mjs';

// Tiny .env loader so the server runs with plain `node`.
const envFile = path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const PORT = Number(process.env.PORT || 8787);
const CAP_PER_PURCHASE = Number(process.env.CAP_PER_PURCHASE_USD || 3);
const CAP_PER_DAY = Number(process.env.CAP_PER_DAY_USD || 20);

const cap = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);
const money = (n) => `$${Number(n).toFixed(2).replace(/\.00$/, '')}`;
const maskPhone = (p) => (p ? p.replace(/^(\+\d{1,2})(\d{2})\d+(\d{3})$/, '$1 $2•••••$3') : p);

const OPERATOR_PRODUCTS = { jio: 'reliance-jio-india-bundles', airtel: 'airtel-india', vi: 'vodafone-india', bsnl: 'bsnl-india' };

// Resolves a top-up, gift or eSIM chip to a Bitrefill product and package, priced in dollars.
// Products in another currency (an Indian phone plan) convert at the day's rate.
async function priced(product, usd) {
  const rate = await swap.fx(product.currency || 'USD');
  const pkg = br.pickPackage(product, Number(usd) * rate);
  return { product, pkg, usd: Math.round((pkg.local / rate) * 100) / 100 };
}

async function resolve(chip) {
  if (chip.kind === 'topup') {
    if (!chip.phone) throw new Error(`No phone number saved for ${chip.name}. Add it in the Keyo app.`);
    let productId = null;
    try {
      const info = await br.checkPhone(chip.phone);
      const ops = info.operators || [];
      const want = (chip.operator || '').toLowerCase();
      const op = ops.find((o) => `${o.id} ${o.name}`.toLowerCase().includes(want)) || ops[0];
      productId = op?.id;
    } catch {}
    if (!productId) productId = OPERATOR_PRODUCTS[(chip.operator || 'jio').toLowerCase()];
    const product = await br.product(productId);
    // The MCP knows every plan's dollar price; take the one closest to what was asked.
    const plans = await mcp.packages(productId).catch(() => []);
    if (plans.length) {
      const k = [...plans].sort((a, b) => Math.abs(a.usd - chip.usd) - Math.abs(b.usd - chip.usd))[0];
      const named = !/^\d+(\.\d+)?$/.test(k.value);
      return { product, pkg: { value: k.value, plan: named ? k.value : null }, usd: k.usd, phone_number: chip.phone };
    }
    return { ...(await priced(product, chip.usd)), phone_number: chip.phone };
  }
  if (chip.kind === 'gift') {
    const product = await br.product(chip.product_id || (await br.findProduct(chip.brand)).id);
    return priced(product, chip.usd);
  }
  if (chip.kind === 'esim') {
    const product = await br.esimFor(chip.country);
    // Cheapest bundle; eSIM prices are in dollars.
    const k = [...(product.packages || [])].sort((a, b) => a.amount - b.amount)[0];
    if (!k) throw new Error(`No eSIM bundles for ${chip.country}`);
    return { product, pkg: { value: k.value, plan: k.value, esim: true }, usd: Number(k.amount) };
  }
  throw new Error(`Not a Bitrefill action: ${chip.kind}`);
}

function resultText(chip, product, order) {
  const name = product.base_name || product.name || cap(chip.brand || chip.operator);
  if (chip.kind === 'topup') {
    const plan = chip.plan ? ` (${chip.plan})` : '';
    return `✅ Recharged ${maskPhone(chip.phone)} with ${name} · ${money(chip.usd)}${plan}. It should land in a minute.`;
  }
  const r = order?.redemption_info || {};
  if (chip.kind === 'esim') {
    const lines = [`📶 ${name} · ${chip.plan}`];
    // Apple's one-tap install link opens the eSIM setup straight from the chat.
    if (r.barcode_value) lines.push(`Install: https://esimsetup.apple.com/esim_qrcode_provisioning?carddata=${encodeURIComponent(r.barcode_value)}`);
    else if (r.instructions) lines.push(r.instructions);
    return lines.join('\n');
  }
  const lines = [`🎁 ${money(chip.usd)} ${name} gift card for you!`];
  if (r.code) lines.push(`Code: ${r.code}`);
  if (r.pin) lines.push(`${r.code ? 'PIN' : 'Card'}: ${r.pin}`);
  if (r.other) lines.push(r.other);
  if (r.link) lines.push(`Redeem: ${r.link}`);
  if (!r.code && !r.pin && !r.link && r.instructions) lines.push(r.instructions.replace(/\\n/g, '\n'));
  return lines.join('\n');
}

async function bitrefill(chip, { approved = false, sandbox = false } = {}) {
  const { product, pkg, usd, phone_number } = await resolve(chip);
  chip = { ...chip, usd, plan: pkg.plan };
  const spent = store.spentToday();
  if (!approved && (usd > CAP_PER_PURCHASE || spent + usd > CAP_PER_DAY)) {
    const id = `apr_${Date.now().toString(36)}`;
    store.addApproval(id, { chip, usd, product: product.name, sandbox });
    return {
      status: 'needs_approval',
      approval_id: id,
      open: `keyo://approve?id=${id}`,
      message: `${money(usd)} is over your limit (${money(CAP_PER_PURCHASE)} a purchase, ${money(Math.max(CAP_PER_DAY - spent, 0))} left today). Approve it in Keyo.`,
    };
  }
  // Someone else with an email on file gets the card straight from Bitrefill.
  const gift = chip.kind === 'gift' && chip.email && chip.name && chip.name.toLowerCase() !== 'me'
    ? { recipient_name: cap(chip.name), recipient_email: chip.email, sender_name: process.env.SENDER_NAME || 'A friend', message: 'For you' }
    : null;
  const emailed = () => `🎁 Sent you a ${money(usd)} ${product.base_name || product.name} gift card. Check your email ${chip.email.replace(/^(.).*(@.*)$/, '$1•••$2')}!`;
  if (sandbox || process.env.DRY_RUN === '1') {
    // Same product, price and wording as a real purchase; nothing is paid.
    const invoice_id = crypto.randomUUID();
    const fake = () => Math.random().toString(36).slice(2, 6).toUpperCase();
    const redemption = chip.kind === 'esim'
      ? { barcode_value: `LPA:1$rsp.keyo.app$${fake()}${fake()}` }
      : { pin: String(6000 + Math.floor(Math.random() * 9000)) + String(Math.floor(1e11 + Math.random() * 9e11)), other: `PIN Code: ${Math.floor(100000 + Math.random() * 900000)}` };
    store.record({ type: 'bitrefill', ok: true, sandbox: true, kind: chip.kind, product: product.name, usd, invoice_id, to: chip.name });
    return { status: 'done', sandbox: true, invoice_id, text: gift ? emailed() : resultText(chip, product, { redemption_info: redemption }) };
  }
  const inv = await mcp.buy({ product_id: product.id, package_value: pkg.value, refill_input: phone_number, gift });
  const done = await mcp.waitDelivered(inv.invoice_id);
  const entry = store.record({ type: 'bitrefill', ok: done.delivered, kind: chip.kind, product: product.name, usd: done.price ?? usd, invoice_id: inv.invoice_id, to: chip.name });
  if (!done.delivered) {
    return { status: 'pending', invoice_id: inv.invoice_id, message: `Paid. ${product.base_name || product.name} is on its way` };
  }
  const text = gift ? emailed() : resultText(chip, product, { redemption_info: done.redemption });
  return { status: 'done', invoice_id: inv.invoice_id, activity_id: entry.id, text };
}

// The same payment or purchase to the same person twice in two minutes is a mistake
// (a double tap, a stale button), never a second order.
const recent = new Map();
function duplicate(chip) {
  if (!['topup', 'gift', 'esim', 'zec_send'].includes(chip.kind)) return false;
  const key = [chip.kind, chip.name, chip.product_id || chip.brand || chip.operator || chip.address, chip.usd ?? chip.amount].join('|');
  const last = recent.get(key);
  recent.set(key, Date.now());
  return last && Date.now() - last < 120_000;
}

async function act(chip, mode = 'zodl', sandbox = false) {
  if (duplicate(chip)) return { status: 'skipped', message: 'Already done a moment ago' };
  switch (chip.kind) {
    case 'topup':
    case 'gift':
    case 'esim':
      return bitrefill(chip, { sandbox });

    case 'zec_send': {
      if (!chip.address) throw new Error(`No Zcash address saved for ${chip.name || 'that contact'}.`);
      const memo = chip.memo || 'Sent with Keyo';
      if (chip.usd && !chip.amount) chip = { ...chip, amount: Number((chip.usd / (await swap.prices()).ZEC).toFixed(5)) };
      // Testnet coins are free, so even the test chats' contacts get a real shielded send.
      const testnet = process.env.AEGIS_NETWORK === 'test';
      if (sandbox && !testnet) {
        const txid = [...Array(64)].map(() => '0123456789abcdef'[Math.floor(Math.random() * 16)]).join('');
        store.record({ type: 'zec', ok: true, sandbox: true, kind: 'send', amount: chip.amount, to: chip.name, txid });
        return { status: 'done', txid, text: `🛡️ Sent you ${chip.usd ? money(chip.usd) + ' in ZEC' : chip.amount + ' ZEC'}, privately.` };
      }
      if (mode === 'server' || sandbox) {
        const tx = await zec.send(chip.address, chip.amount, memo);
        store.record({ type: 'zec', ok: true, kind: 'send', amount: chip.amount, to: chip.name, txid: tx.txid, network: tx.network });
        const proof = tx.network === 'test' ? `\n${tx.explorer}` : '';
        return { status: 'done', txid: tx.txid, text: `🛡️ Sent you ${chip.usd ? money(chip.usd) + ' in ZEC' : chip.amount + ' ZEC'}, privately. Only we can see it.${proof}` };
      }
      return { status: 'open', open: zcashUri(chip.address, chip.amount, memo), message: `Confirm ${chip.amount} ZEC in Zodl` };
    }

    case 'price': {
      const usd = (await swap.prices()).ZEC;
      if (chip.unit === 'USD') return { status: 'done', text: `${money(chip.amount)} = ${(chip.amount / usd).toFixed(5)} ZEC` };
      return { status: 'done', text: `${chip.amount} ZEC = ${money(chip.amount * usd)}` };
    }

    case 'answer':
      return { status: 'done', text: await answer(chip.question) };

    case 'meet': {
      const ev = cal.book({ title: chip.event || 'Call', start: chip.start, minutes: chip.minutes, with: chip.with });
      store.record({ type: 'calendar', ok: true, title: ev.title, start: ev.start, to: chip.with });
      const invite = chip.email ? ` Invite sent to ${chip.email.replace(/^(.).*(@.*)$/, '$1•••$2')}.` : '';
      return { status: 'done', text: `📅 Booked: ${cal.dayLabel(ev.start)} at ${cal.timeLabel(ev.start)} (${chip.minutes} min).${invite}` };
    }

    case 'schedule': {
      // First run now, then on its own every period.
      const first = await act(chip.chip, mode, sandbox);
      const rule = schedule.add(chip.every, chip.chip);
      const when = new Date(rule.next).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      const lines = [first.text, `🗓️ I'll do this every ${chip.every} by myself. Next: ${when}.`].filter(Boolean);
      return { ...first, status: first.status === 'done' ? 'done' : first.status, rule_id: rule.id, text: lines.join('\n') };
    }

    case 'zec_request': {
      if (chip.usd && !chip.amount) chip = { ...chip, amount: Number((chip.usd / (await swap.prices()).ZEC).toFixed(5)) };
      const mine = (process.env.AEGIS_NETWORK === 'test' ? null : process.env.USER_ZEC_ADDRESS) || (await zec.address().catch(() => ({}))).unified;
      if (!mine) throw new Error('No Zcash address to receive on');
      const uri = zcashUri(mine, chip.amount, chip.memo || 'Keyo request');
      const why = chip.split ? `Your share of ${money(chip.split.total)} is ${money(chip.usd)}. ` : chip.usd ? `Here's my invoice for ${money(chip.usd)}. ` : '';
      return { status: 'done', text: `${why}Pay ${chip.amount} ZEC privately here: ${uri}` };
    }

    case 'swap_in': {
      const q = await swap.quote({ from: chip.from, to: 'ZEC', amount: chip.amount, payer: true });
      store.record({ type: 'swap', ok: true, sandbox: !!sandbox, from: q.from, to: q.to, amountIn: q.amountIn, amountOut: q.amountOut, deposit: q.depositAddress });
      return { status: 'done', quote: q, text: `Sure! Send ${Number(q.amountIn)} ${q.from} on Solana to this address:\n${q.depositAddress}\nIt reaches me as ZEC.` };
    }

    case 'swap': {
      const q = await swap.quote({ from: chip.from, to: chip.to, amount: chip.amount, dry: sandbox });
      if (sandbox) {
        store.record({ type: 'swap', ok: true, sandbox: true, from: q.from, to: q.to, amountIn: q.amountIn, amountOut: q.amountOut });
        return { status: 'done', quote: q, text: `🔁 Swapped ${q.amountIn} ${q.from} → ${q.amountOut} ${q.to} through NEAR Intents.` };
      }
      store.record({ type: 'swap', ok: true, from: q.from, to: q.to, amountIn: q.amountIn, amountOut: q.amountOut, deposit: q.depositAddress });
      if (q.from === 'ZEC') {
        if (mode === 'server') {
          const tx = await zec.send(q.depositAddress, chip.amount, null);
          return { status: 'done', quote: q, txid: tx.txid, message: `Swapping ${q.amountIn} ZEC → ${q.amountOut} ${q.to}` };
        }
        return { status: 'open', quote: q, open: zcashUri(q.depositAddress, q.amountIn), message: `${q.amountIn} ZEC → ${q.amountOut} ${q.to}. Confirm in Zodl` };
      }
      return { status: 'quote', quote: q, message: `Send ${q.amountIn} ${q.from} to ${q.depositAddress} to get ${q.amountOut} ${q.to}` };
    }
  }
  throw new Error(`Unknown action ${chip.kind}`);
}

// Instant answers for questions typed in the chat.
async function answer(question) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('Answers need GEMINI_API_KEY');
  const model = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
  const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: `Now: ${new Date().toISOString()} (UTC). Reply with only the answer, one or two short sentences the user can send as a chat message. No preamble, no follow-up remarks.\n\n${question}` }] }],
      generationConfig: { temperature: 0.3, maxOutputTokens: 120 },
    }),
  });
  const j = await r.json();
  const text = j?.candidates?.[0]?.content?.parts?.map((p) => p.text).join('').trim();
  if (!text) throw new Error('No answer right now');
  return text;
}

function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(body));
}

async function readJson(req) {
  let raw = '';
  for await (const chunk of req) raw += chunk;
  return raw ? JSON.parse(raw) : {};
}

const routes = {
  'GET /health': async () => ({ ok: true }),
  'POST /suggest': async (b) => ({ chips: await suggest(String(b.text || ''), { incoming: b.incoming, from: b.from }) }),
  // Rehearsal mode runs every flow with real products and prices but pays for nothing.
  'POST /act': async (b) => act(b.chip, b.mode, !!b.sandbox || !!b.chip?.demo || !store.live()),
  'GET /demo/live': async () => ({ live: store.live() }),
  'POST /demo/live': async (b) => ({ live: store.setLive(!!b.live) }),
  'GET /approval': async (_, q) => store.approval(q.get('id')) || { status: 'missing' },
  'POST /approve': async (b) => {
    const a = store.approval(b.id);
    if (!a || a.status !== 'waiting') throw new Error('Nothing to approve');
    if (!b.approve) {
      store.settleApproval(b.id, 'declined');
      return { status: 'declined' };
    }
    store.settleApproval(b.id, 'approved');
    const out = await bitrefill(a.chip, { approved: true, sandbox: !!a.sandbox });
    store.settleApproval(b.id, out.status === 'done' ? 'done' : 'approved');
    store.approval(b.id).result = out;
    return out;
  },
  'GET /activity': async () => ({ activity: store.activity(), spentToday: store.spentToday(), caps: { perPurchase: CAP_PER_PURCHASE, perDay: CAP_PER_DAY } }),
  'GET /contacts': async () => ({ contacts: store.contacts() }),
  'GET /calendar': async () => ({ events: cal.events() }),
  'POST /demo/reset': async () => {
    store.resetDemo();
    return { ok: true };
  },
  'GET /rules': async () => ({ rules: store.rules() }),
  'POST /rules/run': async (b) => {
    const r = store.rules().find((x) => x.id === b.id);
    if (!r) throw new Error('No such order');
    r.next = Date.now() - 1;
    store.saveRule(r);
    return { ok: true };
  },
  'POST /rules/delete': async (b) => {
    store.deleteRule(b.id);
    return { ok: true };
  },
  'POST /contacts': async (b) => {
    store.setContacts(b.contacts || []);
    return { ok: true };
  },
  'GET /balance': async () => {
    const out = {};
    try {
      const b = await mcp.balances();
      out.bitrefill = { balance: b.USD ?? 0, currency: 'USD', all: b };
    } catch (e) {
      out.bitrefillError = e.message;
    }
    const [main, test] = await Promise.allSettled([zec.balance('main'), zec.balance('test')]);
    if (main.status === 'fulfilled') out.zec = main.value;
    else out.zecError = main.reason.message;
    if (test.status === 'fulfilled') out.zecTest = test.value;
    return out;
  },
  'GET /swap/status': async (_, q) => swap.status(q.get('deposit')),
};

http
  .createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    const handler = routes[`${req.method} ${url.pathname}`];
    if (req.method === 'OPTIONS') return send(res, 204, {});
    if (!handler) return send(res, 404, { error: 'not found' });
    const token = process.env.KEYO_TOKEN;
    if (token && url.pathname !== '/health' && req.headers['x-keyo-token'] !== token) return send(res, 401, { error: 'bad token' });
    try {
      const body = req.method === 'POST' ? await readJson(req) : {};
      const t0 = Date.now();
      const out = await handler(body, url.searchParams);
      console.log(req.method, url.pathname, `${Date.now() - t0}ms`, body.chip?.kind || '', body.incoming ? 'incoming:' + String(body.incoming).slice(0, 30) : '', body.text != null ? 'text:' + String(body.text).slice(0, 20) : '');
      send(res, 200, out);
    } catch (e) {
      console.error(req.method, url.pathname, e.message);
      send(res, 400, { error: e.message });
    }
  })
  .listen(PORT, () => {
    console.log(`Keyo server on :${PORT}`);
    schedule.start(act);
    // Warm the catalog and the birthday picks so the first gift ideas show at once.
    suggest('', { incoming: "It's my birthday today!! 🎂🥳", from: 'Sakshi' }).catch(() => {});
  });
