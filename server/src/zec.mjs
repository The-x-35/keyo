// Server wallet: a shielded Zcash wallet driven through zcash-devtool, so the
// keyboard can send without opening Zodl. Keys stay on this machine.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const run = promisify(execFile);

function cfg() {
  const bin = process.env.ZEC_DEVTOOL_BIN;
  const wallet = process.env.ZEC_WALLET_DIR;
  const identity = process.env.ZEC_IDENTITY_FILE;
  if (!bin || !wallet) throw new Error('Server wallet is not set up (ZEC_DEVTOOL_BIN, ZEC_WALLET_DIR in server/.env)');
  return { bin, wallet, identity, server: process.env.ZEC_LIGHTWALLETD || 'zecrocks' };
}

async function devtool(args, timeout = 180_000) {
  const { bin } = cfg();
  const { stdout, stderr } = await run(bin, args, { timeout, maxBuffer: 8 << 20 });
  return `${stdout}\n${stderr}`;
}

export async function sync() {
  const c = cfg();
  return devtool(['wallet', '-w', c.wallet, 'sync', '--server', c.server, '--connection', 'direct'], 300_000);
}

export async function balance() {
  const c = cfg();
  const out = await devtool(['wallet', '-w', c.wallet, 'balance']);
  const spendable = out.match(/Spendable[^\d]*([\d.]+)/i)?.[1];
  const total = out.match(/Balance[^\d]*([\d.]+)/i)?.[1];
  return { total: total ? Number(total) : null, spendable: spendable ? Number(spendable) : null, raw: out.trim().slice(0, 600) };
}

export async function send(address, amountZec, memo) {
  const c = cfg();
  await sync().catch(() => {});
  const zats = Math.round(Number(amountZec) * 1e8);
  const args = ['wallet', '-w', c.wallet, 'send', '--address', address, '--value', String(zats), '--server', c.server, '--connection', 'direct'];
  if (c.identity) args.push('--identity', c.identity);
  if (memo) args.push('--memo', memo);
  const out = await devtool(args);
  const txid = out.match(/\b[0-9a-f]{64}\b/)?.[0];
  if (!txid) throw new Error(`Send failed: ${out.trim().slice(-300)}`);
  return { txid };
}
