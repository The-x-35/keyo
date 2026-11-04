# Feedback

What broke, confused us or slowed us down, building Keyo in a day.

## Bitrefill

- **REST and MCP see different balances.** Our event credits landed in the account's USD sub-account. REST `GET /accounts/balance` returned `0 BTC` (the primary sub-account) and `POST /invoices` with `payment_method: balance` failed with "Balance too low". The MCP's `get-balances` showed all three (BTC, EUR, USD $25) and `buy-products` takes `balance_currency: USD`. We moved purchases to the MCP. A `balance_currency` on REST invoices, or a note in the builder pack, would have saved half an hour.
- **Unpaid invoices pile up.** Each failed REST attempt left an unpaid invoice in `GET /invoices`. Harmless (they expire), but confusing when you're checking whether a purchase went through.
- **MCP replies mix formats.** `buy-products` returns JSON text; `get-invoice-by-id` returns a YAML-like text. We parse both with regexes. One format (or `structuredContent`) would make agents more reliable, and would stop card codes leaking into logs from naive masking.
- **Search is name-only.** `search-products` is full text on brand names, so "gift for a movie lover" returns nothing, even though the tool description invites broad goals. We built our own shopper over the catalog list. A semantic or category search would help agents a lot.
- **Search ignores the country for ranking.** `q=airtel&country=IN` returned Airtel Nigeria first. We filter on `country_code` ourselves.
- **Package shape differs from the docs.** Docs show `packages[].package_id`; the live response has `id`, `value`, `price` (in the account currency) and `amount` (in the product currency). `amount` is what you need for "₹199".
- **Jio plans are named, not priced.** "recharge for 199" has to match `amount`, since `value` is "2GB/Day 5G Plan – 14 Days".
- **Swiggy Money takes 5–6 working days.** Bad for instant gifts; we steer gift suggestions to Flipkart and Zomato. A `delivery_time` field would let agents choose well.
- **ZEC isn't a payment method.** A Zcash-first app has to swap to USDC first, and NEAR Intents needs a transparent refund address, which leaks.

## Zcash

- The Swift wallet SDK 4.0 says support ends when NU7 activates, and NU7 is live on testnet, so we kept wallets on the server (zcash-devtool) and hand off to Zodl on the phone.
- Zodl's App Store build registers `zcash:` links; its testnet build in the source doesn't.

## Tooling

- GitHub returned "Internal Server Error / commit_refs_rules" on every push to our first repo for a while, even for empty commits; a fresh repo worked.
- The builder pack's Notion pages only render in a browser; fetch tools see an empty page.
