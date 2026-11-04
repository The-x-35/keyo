# Keyo

**The keyboard that pays.** Keyo is an iPhone keyboard that reads the conversation and does the errand for you: Mom says her balance ran out, and the recharge is done before you've typed a word. You only press send.

Built at Free Society Hack, Mumbai, 4 Nov 2026, for **Agentic Commerce (Bitrefill)** and **Privacy (Zcash)**.

## What it does

| In the chat | Keyo | Human steps |
|---|---|---|
| Mom: "My phone balance is over 😟" | **Autopilot** recharges Mom's Jio ₹199 through Bitrefill and types the confirmation | press send |
| Mom: "Can you recharge my phone every month so I don't have to ask?" | Sets a **standing order** that runs by itself every month, inside your limits | press send, then none |
| Mom: "Papa's anniversary gift ideas? Under ₹1000" | The **shopper** picks 3 real cards from Bitrefill's India catalog (The Man Company, Fastrack, Zomato…) | tap one |
| "happy birthday priya!" | Offers Flipkart / Zomato cards; one tap buys and types the card under your wish, or emails it to her if she's in your contacts | tap |
| Mom: "I'm landing in Dubai tomorrow ✈️" | Buys a Bitrefill UAE eSIM and types Apple's one-tap install link | press send |
| Mom: "Can you send me 0.01 ZEC for groceries?" | Shielded ZEC from **Aegis** (Keyo's server wallet) or a ZIP 321 link that opens **Zodl** | press send (Aegis) |
| Mom: "What do I owe you?" / "dinner was ₹1200 split between 4" | A shielded `zcash:` request for her share, priced live | press send |
| Mom: "How do I turn my ZEC into dollars?" | Swaps through **NEAR Intents** 1Click | press send |
| Mom: "Get me a ₹2000 Flipkart card" | Over your ₹500 limit: waits for **Face ID** in Keyo, then types the card in | Face ID |
| "zec price", "₹500 in zec", any question | Live price, conversion, or an instant answer | tap |

The test chat with Mom lives in the app's **Chat** tab, a WhatsApp look-alike. It shares Mom's latest message with the keyboard the way a messaging integration would.

## Agentic, not chat

Bitrefill's loop is trigger → guarantee → fulfillment → ending. Keyo covers all four without a checkout:

- **Trigger:** the other person's message (proactive chips), your own words, or a schedule (standing orders run on the server every minute/day/week/month).
- **Guarantee:** ₹500 per purchase and ₹1,000 per day. Above that, Face ID in the app. Autopilot only acts on a single, clear action under the limit. Every run is logged in the Ledger with its invoice ID.
- **Fulfillment:** Bitrefill's eCommerce MCP (`buy-products`, `get-invoice-by-id`, `get-balances`) paying from the account balance, plus REST v2 for the catalog (`/products`, `/products/{id}`, `/check_phone_number`, `/products/esims`).
- **Ending:** recharges land on the phone; cards, PINs and eSIM install links are typed into the chat or emailed straight to the recipient (`gift` in `buy-products`). No copy and paste.

## Bitrefill touchpoints

- **eCommerce MCP** `https://api.bitrefill.com/mcp`: `buy-products` (balance, USD sub-account, gift emails, `refill_input` for top-ups), `get-invoice-by-id` polled until `all_delivered`, `get-balances`.
- **REST v2**: India catalog for the shopper (153 products), product packages, operator lookup by phone number, eSIM catalog.
- **Built:** the keyboard, intent rules, proactive replies, Autopilot, standing orders, the Gemini shopper constrained to Bitrefill's catalog, guardrails and approvals. **Reused:** Bitrefill's catalog, payment and delivery.
- **Real purchases:** invoice `2e4d1b5e-3699-4fa7-a04a-30aec1a6975a` (₹50 Flipkart, $0.56 from balance, delivered in 1.6 s) and `0b0b1dbf-9d76-43d0-9772-234a59810266` (₹50 Flipkart, bought by Keyo's own flow).

## Guardrails

- Most an agent can spend: **₹500 a purchase, ₹1,000 a day** (`CAP_PER_PURCHASE_INR`, `CAP_PER_DAY_INR`).
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
