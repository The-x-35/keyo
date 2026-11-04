import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Keyo", systemImage: "keyboard") }
            ContactsView().tabItem { Label("People", systemImage: "person.2") }
            ActivityView().tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct HomeView: View {
    @State private var tryText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pay and buy from any chat").font(.title2.bold())
                        Text("Shielded Zcash, swaps, top-ups and gift cards, right in your keyboard.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section("Set up") {
                    Label("Settings › General › Keyboard › Keyboards › Add New Keyboard › Keyo", systemImage: "1.circle.fill")
                    Label("Tap Keyo › turn on Allow Full Access", systemImage: "2.circle.fill")
                    Label("In any chat, hold 🌐 and pick Keyo", systemImage: "3.circle.fill")
                }
                Section("Try it") {
                    TextField("recharge mom's jio for 199", text: $tryText, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Things to type") {
                    ForEach([
                        "recharge mom's jio for 199",
                        "send 0.01 zec to rahul",
                        "request 0.05 zec for dinner",
                        "swap 0.01 zec to usdc",
                        "happy birthday bro!",
                        "send mom a 100 swiggy gift card",
                        "flying to dubai tomorrow",
                    ], id: \.self) { Text($0).font(.callout.monospaced()) }
                }
            }
            .navigationTitle("Keyo")
        }
    }
}

struct Person: Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var phone = ""
    var operatorName = "jio"
    var zec = ""

    init() {}
    init(_ d: [String: Any]) {
        name = d["name"] as? String ?? ""
        phone = d["phone"] as? String ?? ""
        operatorName = d["operator"] as? String ?? "jio"
        zec = d["zec"] as? String ?? ""
        aliases = d["aliases"] as? [String] ?? []
    }
    var aliases: [String] = []

    var json: [String: Any] {
        ["name": name, "phone": phone, "operator": operatorName, "zec": zec,
         "aliases": Array(Set(aliases + [name.lowercased()]))]
    }
}

struct ContactsView: View {
    @State private var people: [Person] = []
    @State private var error: String?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                if let error { Text(error).foregroundStyle(.red) }
                ForEach($people) { $p in
                    Section(p.name.isEmpty ? "New person" : p.name) {
                        TextField("Name", text: $p.name)
                        TextField("Phone (+91…)", text: $p.phone).keyboardType(.phonePad)
                        Picker("Operator", selection: $p.operatorName) {
                            ForEach(["jio", "airtel", "vi", "bsnl"], id: \.self) { Text($0.capitalized) }
                        }
                        TextField("Zcash address (u1…)", text: $p.zec)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .font(.footnote.monospaced())
                    }
                }
                .onDelete { people.remove(atOffsets: $0) }
                Button("Add person") { people.append(Person()) }
            }
            .navigationTitle("People")
            .toolbar {
                Button(saved ? "Saved" : "Save") { Task { await save() } }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        do {
            let j = try await API.request("GET", "/contacts")
            people = (j["contacts"] as? [[String: Any]] ?? []).map(Person.init)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func save() async {
        do {
            _ = try await API.request("POST", "/contacts", body: ["contacts": people.map(\.json)])
            saved = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            saved = false
        } catch { self.error = error.localizedDescription }
    }
}

struct ActivityView: View {
    @State private var items: [[String: Any]] = []
    @State private var spent = 0
    @State private var caps: [String: Any] = [:]
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                Section("Limits") {
                    LabeledContent("Per purchase", value: "₹\(caps["perPurchase"] as? Int ?? 0)")
                    LabeledContent("Spent today", value: "₹\(spent) of ₹\(caps["perDay"] as? Int ?? 0)")
                }
                Section("Recent") {
                    ForEach(items.indices, id: \.self) { i in
                        let a = items[i]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title(a)).font(.headline)
                            if let inv = a["invoice_id"] as? String { Text("Invoice \(inv)").font(.caption.monospaced()).foregroundStyle(.secondary) }
                            if let tx = a["txid"] as? String { Text("tx \(tx.prefix(20))…").font(.caption.monospaced()).foregroundStyle(.secondary) }
                            Text(a["at"] as? String ?? "").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func title(_ a: [String: Any]) -> String {
        switch a["type"] as? String {
        case "bitrefill": return "\(a["product"] as? String ?? "") ₹\(a["inr"] ?? "")\((a["to"] as? String).map { " · " + $0 } ?? "")"
        case "zec": return "Sent \(a["amount"] ?? "") ZEC\((a["to"] as? String).map { " to " + $0 } ?? "")"
        case "swap": return "Swap \(a["amountIn"] ?? "") \(a["from"] ?? "") → \(a["amountOut"] ?? "") \(a["to"] ?? "")"
        default: return a["type"] as? String ?? ""
        }
    }

    private func load() async {
        do {
            let j = try await API.request("GET", "/activity")
            items = j["activity"] as? [[String: Any]] ?? []
            spent = j["spentToday"] as? Int ?? 0
            caps = j["caps"] as? [String: Any] ?? [:]
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct SettingsView: View {
    @State private var server = Keyo.serverURL
    @State private var token = Keyo.token
    @State private var mode = Keyo.walletMode
    @State private var health = ""
    @State private var balances = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("http://192.168.x.x:8787", text: $server)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    SecureField("Token", text: $token)
                    Button("Check connection") { Task { await check() } }
                    if !health.isEmpty { Text(health).font(.footnote) }
                }
                Section("Send ZEC with") {
                    Picker("Wallet", selection: $mode) {
                        Text("Zodl app").tag("zodl")
                        Text("Keyo server wallet").tag("server")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Balances") {
                    Button("Refresh") { Task { await loadBalances() } }
                    if !balances.isEmpty { Text(balances).font(.footnote.monospaced()) }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: server) { _, v in Keyo.serverURL = v }
            .onChange(of: token) { _, v in Keyo.token = v }
            .onChange(of: mode) { _, v in Keyo.walletMode = v }
        }
    }

    private func check() async {
        do {
            _ = try await API.request("GET", "/health", timeout: 6)
            health = "Connected ✓"
        } catch { health = error.localizedDescription }
    }

    private func loadBalances() async {
        do {
            let j = try await API.request("GET", "/balance", timeout: 120)
            var lines: [String] = []
            if let b = j["bitrefill"] as? [String: Any] { lines.append("Bitrefill: \(b["balance"] ?? "?") \(b["currency"] ?? "")") }
            if let e = j["bitrefillError"] as? String { lines.append("Bitrefill: \(e)") }
            if let z = j["zec"] as? [String: Any] { lines.append("Server wallet: \(z["spendable"] ?? z["total"] ?? "?") ZEC") }
            if let e = j["zecError"] as? String { lines.append("Server wallet: \(e)") }
            balances = lines.joined(separator: "\n")
        } catch { balances = error.localizedDescription }
    }
}
