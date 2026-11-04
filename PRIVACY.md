# Privacy and trust note

1. **What stays private.** ZEC moves between shielded unified addresses (`utest1…`) in the Ironwood pool, so sender, receiver and amount are hidden on-chain and the memo is encrypted. Invoices and split requests are ZIP 321 links to a shielded address. Bitrefill gift cards are emailed by Bitrefill, so codes never pass through the chat or our logs.

2. **What Keyo reveals, and to whom.**
   - **Keyo server (us):** the other person's last message when a chat shares it, the line you type (after a pause), your contacts' names, numbers and emails (from iOS Contacts), saved Zcash addresses, your calendar events, every purchase with its invoice ID, every ZEC send with its txid, and standing orders. Phone numbers and emails are stored next to invoice IDs and txids.
   - **Google Gemini:** chat messages no rule understands, birthday and gift requests with Bitrefill's catalog, and questions sent to Keyo.
   - **Bitrefill:** each purchase, the phone number for top-ups, the recipient's email for gifts, and our account.
   - **NEAR Intents:** swap amounts, the receiving address and a refund address; ZEC refunds need a transparent address, which is public on-chain.
   - **Light-wallet server (testnet.zec.rocks):** the server wallet's IP address and sync timing.

3. **Who users must trust.** Us as the operator of the Keyo server (it holds the Aegis spending key, contacts and history), Bitrefill (fulfilment), Google (AI), NEAR Intents solvers (swaps), zec.rocks (light-wallet server) and, in Zodl mode, Zodl.

4. **What we'd fix next.**
   - Move the wallet onto the phone (spending key in the Secure Enclave) once an iOS SDK supports NU7, so the server never holds spending keys; keep only a viewing key on the server to detect payments.
   - Route light-wallet sync and broadcast through Nym.
   - Run the intent rules on the phone, so only the action you tap leaves the device.
   - Send Bitrefill and Gemini only the one person an action needs, and delete phone numbers and emails after delivery.
   - Pay Bitrefill from shielded ZEC at purchase time instead of a prepaid balance tied to one account.
