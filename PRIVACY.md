# Privacy and trust note

**What stays private.** ZEC payments go between shielded unified addresses, so sender, receiver, amount and memo are hidden on-chain. In Zodl mode Keyo never holds keys: it only builds a ZIP 321 link, and Zodl signs on the phone.

**What Keyo reveals, and to whom.**
- The keyboard sends the line you're typing to the Keyo server only when you have paused and the line is 4+ characters. It never reads the other person's messages.
- The Keyo server sees those lines, your contacts' names, phone numbers, operators and Zcash addresses, and what you bought.
- With `GEMINI_API_KEY` set, lines the rules don't understand go to Google's Gemini API.
- Bitrefill sees each purchase (product, amount, phone number for top-ups) under the account that owns the API key.
- NEAR Intents sees swap amounts and both addresses. ZEC refunds need a transparent address, which is public on-chain.
- The light-wallet server (zec.rocks) sees the server wallet's IP and sync pattern.

**What users must trust.** The Keyo server operator (keys, contacts, purchase history), Bitrefill (fulfillment), NEAR Intents solvers (swap execution), Google (if AI is on), Zodl (wallet app), and zec.rocks (light-wallet server).

**Server wallet mode.** The spending key sits on the server. It is a demo convenience; anyone who controls the server can spend it. Keep small amounts there.

**What we'd fix next.**
- Run intent rules on the phone so only tapped actions leave the device.
- Route the server wallet's light-wallet traffic through Nym.
- Pay Bitrefill invoices from shielded ZEC via a swap instead of a prepaid balance, so purchases aren't tied to one account.
- Move the server wallet to a FROST 2-of-3 so the operator alone can't spend.
