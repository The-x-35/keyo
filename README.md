# Keyo

**An iPhone keyboard that pays and buys for you inside any chat.** Type "recharge mom's jio for 199" in WhatsApp and the recharge is done before you hit send. Type "happy birthday bro" and Keyo offers a Swiggy card; one tap buys it on Bitrefill and types the code into the chat. "Send 0.1 zec to rahul" opens Zodl with a shielded payment filled in, or sends it straight from Keyo's server wallet.

Built at Free Society Hack, Mumbai, 4 Nov 2026, for both tracks: **Agentic Commerce (Bitrefill)** and **Privacy (Zcash)**.

## What it does

| You type (anywhere) | Keyo does |
|---|---|
| `recharge mom's jio for 199` | Finds Mom's number and operator, buys the ₹199 Jio plan on Bitrefill from balance, replaces your text with "✅ Recharged +91 98•••••210…" |
| `my data is over yaar` | Offers a ₹199 recharge for your own number |
| `happy birthday bro!` | Offers ₹100 Swiggy / Amazon cards; one tap buys and types the code below your message |
| `send mom a 500 swiggy gift card` | Buys it and types the card into the chat. Over your limit, it asks for Face ID first |
| `flying to dubai tomorrow` | Offers a Bitrefill eSIM for the trip |
| `send 0.1 zec to rahul` | Opens **Zodl** with a ZIP 321 shielded payment (address, amount, memo) or sends from the **Keyo server wallet** |
| `request 0.05 zec for dinner` | Types a shielded `zcash:` payment link to your address |
| `swap 0.01 zec to usdc` | Quotes NEAR Intents 1Click, then pays the deposit address from Zodl or the server wallet |

No checkout, no copy and paste: the trigger is your own conversation, the guarantee is a spending limit with Face ID above it, and the ending is the result typed back into the chat (or the balance landing on the phone).

## How it works

```
iPhone keyboard (Keyo)  ──reads the line you're typing──▶  Keyo server
  strip shows chips                                     ├─ rules + Gemini → chips
  tap → /act                                            ├─ Bitrefill REST v2 (search, invoice auto_pay, order)
  result typed into chat                                ├─ NEAR Intents 1Click (swap quotes, deposit addresses)
  zcash: link → Zodl                                    └─ zcash-devtool server wallet (shielded sends)
Keyo app: people (phone, operator, ZEC address), activity with invoice IDs, limits, Face ID approvals, wallet mode
```

## Bitrefill touchpoints

- **REST API v2**: `GET /products/search`, `GET /products/{id}`, `GET /check_phone_number`, `POST /invoices` with `payment_method: balance` and `auto_pay: true`, `GET /invoices/{id}`, `GET /orders/{id}` polled until delivered, `GET /accounts/balance`.
- Built: the keyboard, intent detection, product and package resolution (copies package values, never retypes them), guardrails, approvals, result formatting. Reused: Bitrefill's catalog, invoicing and fulfillment.

## Guardrails

- **Most an agent can spend:** ₹500 a purchase and ₹1,000 a day (`CAP_PER_PURCHASE_INR`, `CAP_PER_DAY_INR`).
- **Above that:** the purchase waits; the keyboard opens Keyo and the phone owner approves with Face ID. Declined requests are dropped.
- The API key lives only on the server. Codes are typed into the chat you chose and not logged by the server.

## Run it (under 15 minutes)

```bash
cd server && cp .env.example .env   # add BITREFILL_API_KEY, USER_ZEC_ADDRESS, optional GEMINI_API_KEY
node src/index.mjs                  # Keyo server on :8787
```

```bash
cd ios && xcodegen generate && open Keyo.xcodeproj   # run the Keyo scheme
```

On the phone: Settings › General › Keyboard › Keyboards › Add New Keyboard › Keyo › Allow Full Access. In the Keyo app, set the server URL (your Mac's LAN IP or a tunnel), add people, pick Zodl or server wallet.

Server wallet (optional): build [zcash-devtool](https://github.com/zcash/zcash-devtool), create a wallet, and set `ZEC_DEVTOOL_BIN`, `ZEC_WALLET_DIR`, `ZEC_IDENTITY_FILE`.

## Evidence

- Bitrefill invoice ID: _to fill after the demo purchase_
- Zcash transaction: _to fill_

See [PRIVACY.md](PRIVACY.md) for the privacy and trust note and [FEEDBACK.md](FEEDBACK.md) for what slowed us down.
