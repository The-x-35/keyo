# Privacy and trust note

**What stays private.** ZEC payments go between shielded unified addresses (testnet `utest1…`, mainnet `u1…`), so sender, receiver, amount and memo are hidden on-chain. In Zodl mode Keyo never holds keys: it builds a ZIP 321 link and Zodl signs on the phone.

**What Keyo reveals, and to whom.**
- **Keyo server:** the line you're typing (after a pause, 4+ characters), the other person's last message when the chat shares it, your contacts' names, numbers and emails (synced from iOS Contacts), saved Zcash addresses, your purchases and standing orders.
- **Google Gemini:** lines the rules don't understand, open shopping requests with Bitrefill's catalog, and questions you ask Keyo.
- **Bitrefill:** each purchase (product, amount, phone number for top-ups, recipient email for gifts) under the account that owns the API key.
- **NEAR Intents:** swap amounts and both addresses. ZEC refunds need a transparent address, which is public on-chain.
- **zec.rocks light-wallet servers:** the server wallets' IP address and sync pattern.

**What users must trust.** The Keyo server operator (keys, contacts, history), Bitrefill (fulfillment), NEAR Intents solvers (swaps), Google (AI), Zodl (the phone wallet) and zec.rocks (light-wallet servers).

**Aegis.** The server wallets' spending keys are on the server, encrypted to an age identity on the same machine. Anyone who controls the server can spend them, so they hold small amounts.

**What we'd fix next.**
- Run intent rules on the phone so only tapped actions leave the device.
- Route light-wallet traffic through Nym.
- Pay Bitrefill from shielded ZEC through a swap at purchase time, instead of a prepaid balance tied to one account.
- Move Aegis to FROST 2-of-3 so the operator alone can't spend.
- Keep contacts on the phone and send only the one person an action needs.
