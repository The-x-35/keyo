# Feedback

Notes from building Keyo in a day. Kept honest and short.

## Bitrefill
- `GET /products/search` without a key answers `{"message":"Authorization token not found"}`. A read-only, keyless catalog would let a team design the product mapping before they have credits.
- Phone top-ups vs plan renewals (Jio talktime vs Jio Bundles) aren't obvious from search results; we had to read the builder pack to learn that talktime adds balance, not validity.
- ZEC isn't a payment method, so a Zcash-first app has to swap to USDC first, and the documented route (NEAR Intents 1Click) needs a transparent refund address, which leaks.

## Zcash
- The Swift wallet SDK 4.0 says support ends when NU7 activates, and NU7 is live on testnet, so an on-phone wallet on testnet looked risky; we used Zodl links and a server wallet instead.
- Zodl's App Store build handles `zcash:` links; the testnet build in source doesn't register the scheme.

## Event
- The builder pack's Notion pages render only in a browser; fetch tools see an empty page.
