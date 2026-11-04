# Keyo

**The keyboard that pays.** Keyo is an iPhone keyboard that reads the conversation and does the errand for you: Mom says her balance ran out, and the recharge is done before you've typed a word. You only press send.

Built at Free Society Hack, Mumbai, 4 Nov 2026, for **Agentic Commerce (Bitrefill)** and **Privacy (Zcash)**.

## What it does

| Chat | They say | Keyo | Human steps |
|---|---|---|---|
| Mom | "My phone balance is over 😟" | **Autopilot** recharges her phone through Bitrefill and types the confirmation | press send |
| Mom | "Can you do this every month?" | A **standing order** that runs by itself every month, inside your limits | tap, then none |
| Sakshi | "It's my birthday today!! 🎂" | The **shopper** picks 3 cards from Bitrefill's catalog; over the $25 limit needs **Face ID**; Bitrefill emails it to her | tap |
| Rahul | "Dinner was $90 for the 3 of us. Send me your share" | Sends $30 of **shielded ZEC** from Aegis at the live price, with the explorer link | press send |
| Alex (client) | "Can we hop on a call this week?" | Free slots from the **calendar**; a tap books it and sends the invite | tap |
| Alex (client) | "Send me your invoice for the $150, happy to pay in ZEC" | A shielded `zcash:` invoice priced live | press send |
| Alex (client) | "I only hold USDC on Solana" | A NEAR Intents deposit address: his USDC lands as your ZEC | press send |
| anywhere | "zec price", "$50 in zec", any question | Live price, conversion, or an instant answer | tap |

Messages no rule knows go to Gemini, which picks the errand. The app's **Chat** tab is a WhatsApp look-alike with these four chats; Bitrefill purchases for these test contacts use the real catalog and prices but skip payment. Shielded testnet sends from Aegis are real: `ee6f137db6c90f076c1d719a8d9153c04395c077426176a918c9f57c4b889c9c` (block 4581946) and `a79c328492987dc87597d1e29e4e89ac91c46a49ae5bef990829e1d11025f3c3`.

## Agentic, not chat

Bitrefill's loop is trigger → guarantee → fulfillment → ending. Keyo covers all four without a checkout:

- **Trigger:** the other person's message (proactive chips), your own words, or a schedule (standing orders run on the server every minute/day/week/month).
- **Guarantee:** $25 per purchase and $50 per day. Above that, Face ID in the app. Autopilot only acts on a single, clear action under the limit. Every run is logged in the Ledger with its invoice ID.
- **Fulfillment:** Bitrefill's eCommerce MCP (`buy-products`, `get-invoice-by-id`, `get-balances`) paying from the account balance, plus REST v2 for the catalog (`/products`, `/products/{id}`, `/check_phone_number`, `/products/esims`).
- **Ending:** recharges land on the phone; cards, PINs and eSIM install links are typed into the chat or emailed straight to the recipient (`gift` in `buy-products`). No copy and paste.

## Bitrefill touchpoints

- **eCommerce MCP** `https://api.bitrefill.com/mcp`: `buy-products` (balance, USD sub-account, gift emails, `refill_input` for top-ups), `get-invoice-by-id` polled until `all_delivered`, `get-balances`.
- **REST v2**: US catalog for the shopper, product packages, operator lookup by phone number, eSIM catalog.
- **Built:** the keyboard, intent rules, proactive replies, Autopilot, standing orders, the Gemini shopper constrained to Bitrefill's catalog, guardrails and approvals. **Reused:** Bitrefill's catalog, payment and delivery.
- **Real purchases:** invoice `2e4d1b5e-3699-4fa7-a04a-30aec1a6975a` ($0.56 Flipkart card, delivered in 1.6 s) and `0b0b1dbf-9d76-43d0-9772-234a59810266` ($0.56 Flipkart card, bought by Keyo's own flow).

## Guardrails

- Most an agent can spend: **$25 a purchase, $50 a day** (`CAP_PER_PURCHASE_USD`, `CAP_PER_DAY_USD`).
- Above that, the phone owner approves with Face ID in Keyo; nothing is bought until then.
- Standing orders use the same limits.
- Contacts without a real number (the test chat's Mom) are never charged: their flows use Bitrefill's real catalog and prices but skip payment.
- The Bitrefill key lives only on the server.

## Zcash

- **Aegis** wallets run on the server with [zcash-devtool](https://github.com/zcash/zcash-devtool): one on **testnet (NU7)**, one on **mainnet**, both with shielded unified addresses.
- **Zodl** mode builds a ZIP 321 `zcash:` link (address, amount, base64url memo) and opens Zodl, which signs on the phone.
- Requests are shielded payment links; swaps go through NEAR Intents 1Click.

## Run it

```bash
cd server && cp .env.example .env    # BITREFILL_API_KEY, GEMINI_API_KEY, ZEC_* paths
node src/index.mjs                   # Keyo server on :8787
```

```bash
cd ios && xcodegen generate && open Keyo.xcodeproj   # run the Keyo scheme
```

On the phone: Settings › General › Keyboard › Keyboards › Add New Keyboard › Keyo › Allow Full Access. In Keyo › Vault, set the server URL (your Mac's LAN IP).

Aegis wallet: build zcash-devtool (`cargo build --release`), then `zcash-devtool wallet -w wallets/test init --name aegis-test --identity wallets/identity.txt --network test` (and `main`), and point `ZEC_DEVTOOL_BIN`, `ZEC_WALLET_DIR`, `ZEC_TEST_WALLET_DIR`, `ZEC_IDENTITY_FILE` at them.

## Which track is which

- **Bitrefill:** the keyboard, MCP purchases, shopper, Autopilot, standing orders, guardrails.
- **Zcash:** Aegis shielded wallets (testnet + mainnet), Zodl ZIP 321 hand-off, shielded requests and split bills, NEAR Intents swaps. See [PRIVACY.md](PRIVACY.md).

[FEEDBACK.md](FEEDBACK.md) has what slowed us down.
