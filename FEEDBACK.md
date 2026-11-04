# Feedback

What broke, confused us or slowed us down building Keyo in a day.

## Bitrefill

**What worked**
- The eCommerce MCP is the right surface for an agent. `buy-products` paying from the balance, then `get-invoice-by-id` until `all_delivered`, took a real gift card from order to delivered in 1.6 seconds.
- `gift` on `buy-products` emails the card straight to the recipient, so the agent never has to handle the code. That made "send a birthday gift" safe to automate.
- `get-product-details` lists every package with its price in dollars, which is exactly what an agent needs to respect a dollar spending cap.
- `check_phone_number` finds the operator from a number, so "recharge Mom" needs only her contact.

**What didn't**
- **REST and the MCP see different balances.** Our event credits sat in the account's USD sub-account. REST `GET /accounts/balance` said 0 BTC and `POST /invoices` with `payment_method: balance` failed with "Balance too low". The MCP's `get-balances` showed USD $25 and `buy-products` takes `balance_currency: USD`. We moved purchases to the MCP. A `balance_currency` on REST invoices, or one line in the builder pack, would have saved half an hour.
- **REST and the MCP list different packages.** REST `/products/airtel-india` returns two packages (500 and 1000). The MCP's `get-product-details` returns five, including the smallest (10 and 120). Our agent couldn't find the cheap top-ups until we read packages from the MCP.
- **Country restrictions show up late.** US phone refills (T-Mobile and others) appear in search, then fail at `/products/{id}` with "not available in your country (IN)". Gift cards from the same country work. A flag in search results would let an agent skip them.
- **Some listed cards can't be bought.** `amazon-usa` is in the US product list but returns "This product is not available for your account". We now check each shopper pick before offering it.
- **MCP replies mix formats.** `buy-products` returns JSON text; `get-invoice-by-id` and `get-product-details` return a YAML-like text. We parse both with regexes. One format (or `structuredContent`) would make agents more reliable, and would stop card codes leaking into logs through naive masking.
- **Search is name-only.** `search-products` matches brand names, so "gift for a coffee lover" returns nothing, even though the tool description invites broad goals. We built our own shopper: Gemini picking from the catalog list.
- **Search ignores the country for ranking.** `q=airtel&country=IN` returned Airtel Nigeria first. We filter on `country_code` ourselves.
- **Package shape differs from the docs.** Docs show `packages[].package_id`; the live response has `id`, `value`, `price` and `amount`, and for range products `amount` is missing, so the face value is only in `value`.
- **Unpaid invoices pile up.** Each failed REST attempt left an unpaid invoice in `GET /invoices`. Harmless, but confusing when checking whether a purchase went through.
- **Delivery time isn't in the catalog.** Swiggy Money takes days. A `delivery_time` field would let an agent pick instant cards for "it's her birthday today".
- **ZEC isn't a payment method.** A Zcash-first app has to swap to USDC first, and NEAR Intents needs a transparent refund address, which leaks.

## Zcash

- **Wallet tool:** `zcash-devtool wallet send` prints other transaction hashes in its output (sync logs). We first reported the faucet's txid as our send's. We now diff `list-tx` before and after the send.
- **Wallet tool:** after NU7, funds show under "Ironwood Spendable". Nothing on screen says Orchard is sealed; the builder pack was the only place that explained it.
- **SDK:** the Zcash Swift Wallet SDK 4.0 says support ends at NU7, and NU7 is live on testnet, so we kept the wallet on the server instead of the phone.
- **Wallet:** Zodl's App Store build registers `zcash:` links but has no testnet mode, so a phone can't open a testnet payment link in a real wallet.
- **Explorer:** testnet.zcashexplorer.app blocks scripted requests (403), so a server can't confirm a transaction there. Zexplorer works.
- **Faucet:** Fauzec worked first time. The Jino Labs faucet was paused for NU7.
- **Build:** zcash-devtool's first release build took a long time; worth starting before anything else.

## Tooling and docs

- GitHub returned "Internal Server Error" on every push to our first repo for a while, even for empty commits; a fresh repo worked.
- The builder pack's Notion pages only render in a browser; fetch tools see an empty page. The llms.txt files on Stadium solved that.
