import SwiftUI

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct ContentView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            ForumView().tag(0).tabItem { Label("Forum", systemImage: "building.columns") }
            ChatView().tag(1).tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            PeopleView().tag(2).tabItem { Label("People", systemImage: "person.2") }
            LedgerView().tag(3).tabItem { Label("Ledger", systemImage: "scroll") }
            VaultView().tag(4).tabItem { Label("Vault", systemImage: "shield.lefthalf.filled") }
        }
        .tint(Roman.gold)
    }
}

/// Screen frame: marble ground, a Roman-capitals title and a gold rule.
struct Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(Roman.caps(30, .bold))
                    .tracking(3)
                    .foregroundStyle(Roman.ink)
                    .padding(.top, 12)
                GoldRule()
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { hideKeyboard() }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Roman.marble.ignoresSafeArea().onTapGesture { hideKeyboard() })
    }
}

/// A stone tablet card.
struct Tablet<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Roman.goldSoft.opacity(0.45), lineWidth: 0.8))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Roman.caps(11, .bold)).tracking(2).foregroundStyle(Roman.gold)
    }
}

// MARK: Forum

struct ForumView: View {
    @State private var tryText = ""
    @State private var mode = Keyo.walletMode
    @State private var keyboardReady = false
    @FocusState private var focused: Bool

    private let spells = [
        ("iphone.gen3", "recharge mom's jio for 199"),
        ("gift", "happy birthday bro!"),
        ("shield.lefthalf.filled", "send 0.01 zec to rahul"),
        ("arrow.down.left", "request 0.05 zec for dinner"),
        ("arrow.triangle.2.circlepath", "swap 0.01 zec to usdc"),
        ("simcard", "landing in dubai tomorrow"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Colosseum()
                        .frame(height: 150)
                        .padding(.horizontal, 8)
                    Text("KEYO")
                        .font(Roman.caps(44, .black))
                        .tracking(14)
                        .foregroundStyle(Roman.ink)
                    Text("PECVNIA · TACITA")
                        .font(Roman.caps(11, .semibold))
                        .tracking(4)
                        .foregroundStyle(Roman.gold)
                }
                .padding(.top, 18)

                if !keyboardReady {
                    Tablet {
                        Eyebrow(text: "Raise the keyboard")
                        step("1", "Settings › General › Keyboard › Keyboards")
                        step("2", "Add New Keyboard › Keyo")
                        step("3", "Keyo › Allow Full Access")
                    }
                }

                Tablet {
                    Eyebrow(text: "Pay with")
                    HStack(spacing: 10) {
                        modeButton("zodl", title: "Zodl", icon: "iphone")
                        modeButton("server", title: "Aegis", icon: "shield.lefthalf.filled")
                    }
                }

                Tablet {
                    Eyebrow(text: "Try it")
                    TextField("Type here with Keyo", text: $tryText, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focused)
                        .padding(12)
                        .background(Roman.marble, in: RoundedRectangle(cornerRadius: 10))
                    VStack(spacing: 0) {
                        ForEach(spells, id: \.1) { icon, line in
                            Button {
                                tryText = line
                                focused = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon).frame(width: 20).foregroundStyle(Roman.gold)
                                    Text(line).font(.callout).foregroundStyle(Roman.ink)
                                    Spacer()
                                }
                                .padding(.vertical, 9)
                            }
                            if line != spells.last?.1 { Divider().overlay(Roman.stone) }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .contentShape(Rectangle())
            .onTapGesture { focused = false }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Roman.marble.ignoresSafeArea().onTapGesture { focused = false })
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        let enabled = (UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] ?? []).contains { $0.hasPrefix("com.arpit.keyo") }
        keyboardReady = enabled && Keyo.keyboardSeen != nil
        mode = Keyo.walletMode
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(n).font(Roman.caps(15, .bold)).foregroundStyle(Roman.gold).frame(width: 16)
            Text(text).font(.callout).foregroundStyle(Roman.ink)
        }
    }

    private func modeButton(_ value: String, title: String, icon: String) -> some View {
        let on = mode == value
        return Button {
            mode = value
            Keyo.walletMode = value
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                Text(title.uppercased()).font(Roman.caps(13, .bold)).tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(on ? Color(hex: 0x3A280A) : Roman.ink)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE9CC82), Color(hex: 0xC09A48)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Roman.marble))
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Roman.goldSoft.opacity(on ? 0 : 0.5), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: People

struct Person: Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var phone = ""
    var operatorName = "jio"
    var zec = ""
    var email = ""
    var aliases: [String] = []

    init() {}
    init(_ d: [String: Any]) {
        name = d["name"] as? String ?? ""
        phone = d["phone"] as? String ?? ""
        operatorName = d["operator"] as? String ?? "jio"
        zec = d["zec"] as? String ?? ""
        email = d["email"] as? String ?? ""
        aliases = d["aliases"] as? [String] ?? []
    }

    var json: [String: Any] {
        ["name": name, "phone": phone, "operator": operatorName, "zec": zec, "email": email,
         "aliases": Array(Set(aliases + [name.lowercased()]))]
    }
}

struct PeopleView: View {
    @State private var people: [Person] = []
    @State private var editing: Person?
    @State private var error: String?
    @State private var query = ""
    @State private var syncing = false

    private var shown: [Person] {
        let q = query.lowercased()
        let list = q.isEmpty ? people : people.filter { $0.name.lowercased().contains(q) || $0.phone.contains(q) }
        return list.sorted { a, b in
            let rank = { (p: Person) in p.name == "Me" ? 0 : (!p.zec.isEmpty ? 1 : 2) }
            return rank(a) != rank(b) ? rank(a) < rank(b) : a.name < b.name
        }
    }

    var body: some View {
        Page(title: "People") {
            if let error { Text(error).font(.footnote).foregroundStyle(Roman.porphyry) }
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Roman.faded)
                    TextField("Search", text: $query).autocorrectionDisabled()
                }
                .padding(10)
                .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 12))
                Button { Task { await sync() } } label: {
                    Image(systemName: syncing ? "hourglass" : "person.crop.circle.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(Roman.gold)
                        .frame(width: 44, height: 44)
                        .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            VStack(spacing: 10) {
                ForEach(shown) { p in
                    Button { editing = p } label: { row(p) }.buttonStyle(.plain)
                }
                Button { editing = Person() } label: {
                    Label("Add person", systemImage: "plus")
                        .font(Roman.caps(14, .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Roman.gold)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Roman.goldSoft.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }
            }
        }
        .task {
            if ContactsSync.authorized || people.isEmpty { await sync() } else { await load() }
        }
        .refreshable { await sync() }
        .sheet(item: $editing) { p in
            PersonEditor(person: p) { updated in
                if let i = people.firstIndex(where: { $0.id == updated.id }) { people[i] = updated } else { people.append(updated) }
                Task { await save() }
            } onDelete: {
                people.removeAll { $0.id == p.id }
                Task { await save() }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func sync() async {
        syncing = true
        defer { syncing = false }
        do { _ = try await ContactsSync.requestAndSync() } catch { self.error = error.localizedDescription }
        await load()
    }

    private func row(_ p: Person) -> some View {
        HStack(spacing: 14) {
            Text(String(p.name.prefix(1)).uppercased())
                .font(Roman.caps(20, .bold))
                .foregroundStyle(Roman.gold)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Roman.marble))
                .overlay(Circle().strokeBorder(Roman.goldSoft.opacity(0.6), lineWidth: 0.8))
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.headline).foregroundStyle(Roman.ink)
                HStack(spacing: 10) {
                    if !p.phone.isEmpty { Label("\(p.operatorName.capitalized) · \(p.phone)", systemImage: "iphone.gen3") }
                    if !p.zec.isEmpty { Label("ZEC", systemImage: "shield.lefthalf.filled") }
                }
                .font(.caption)
                .foregroundStyle(Roman.faded)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Roman.faded)
        }
        .padding(12)
        .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        } catch { self.error = error.localizedDescription }
    }
}

struct PersonEditor: View {
    @State var person: Person
    var onSave: (Person) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $person.name)
                Section("Phone") {
                    TextField("+91", text: $person.phone).keyboardType(.phonePad)
                    Picker("Operator", selection: $person.operatorName) {
                        ForEach(["jio", "airtel", "vi", "bsnl"], id: \.self) { Text($0.capitalized) }
                    }
                }
                Section("Email") {
                    TextField("For gift cards", text: $person.email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Zcash") {
                    TextField("u1…", text: $person.zec, axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.footnote.monospaced())
                }
                if !person.name.isEmpty {
                    Button("Remove", role: .destructive) { onDelete(); dismiss() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Roman.marble)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(person); dismiss() }.disabled(person.name.isEmpty)
                }
            }
        }
        .tint(Roman.gold)
    }
}

// MARK: Ledger

struct LedgerView: View {
    @State private var items: [[String: Any]] = []
    @State private var spent = 0
    @State private var perDay = 0
    @State private var perPurchase = 0
    @State private var error: String?

    var body: some View {
        Page(title: "Ledger") {
            if let error { Text(error).font(.footnote).foregroundStyle(Roman.porphyry) }
            Tablet {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "Today")
                        Text("₹\(spent)").font(Roman.caps(34, .bold)).foregroundStyle(Roman.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("of ₹\(perDay)").font(.callout).foregroundStyle(Roman.faded)
                        Text("₹\(perPurchase) each").font(.caption).foregroundStyle(Roman.faded)
                    }
                }
                ProgressView(value: Double(min(spent, max(perDay, 1))), total: Double(max(perDay, 1)))
                    .tint(Roman.gold)
            }
            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    entry(items[i])
                    if i < items.count - 1 { Divider().overlay(Roman.stone) }
                }
            }
            if items.isEmpty && error == nil {
                Text("Nothing yet").font(Roman.caps(14)).foregroundStyle(Roman.faded).frame(maxWidth: .infinity).padding(.top, 30)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func entry(_ a: [String: Any]) -> some View {
        let (icon, title) = describe(a)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Roman.gold).frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Roman.ink)
                if let inv = a["invoice_id"] as? String { Text(inv).font(.caption2.monospaced()).foregroundStyle(Roman.faded).textSelection(.enabled) }
                if let tx = a["txid"] as? String { Text(tx).font(.caption2.monospaced()).foregroundStyle(Roman.faded).lineLimit(1).truncationMode(.middle).textSelection(.enabled) }
            }
            Spacer()
            Text(time(a["at"] as? String)).font(.caption).foregroundStyle(Roman.faded)
        }
        .padding(.vertical, 12)
    }

    private func describe(_ a: [String: Any]) -> (String, String) {
        let to = (a["to"] as? String).map { " · " + $0.capitalized } ?? ""
        switch a["type"] as? String {
        case "bitrefill":
            let icon = a["kind"] as? String == "topup" ? "iphone.gen3" : a["kind"] as? String == "esim" ? "simcard" : "gift"
            return (icon, "\(a["product"] as? String ?? "") ₹\(a["inr"] ?? "")\(to)")
        case "zec": return ("shield.lefthalf.filled", "\(a["amount"] ?? "") ZEC sent\(to)")
        case "swap": return ("arrow.triangle.2.circlepath", "\(a["amountIn"] ?? "") \(a["from"] ?? "") → \(a["amountOut"] ?? "") \(a["to"] ?? "")")
        default: return ("circle", a["type"] as? String ?? "")
        }
    }

    private func time(_ iso: String?) -> String {
        guard let iso, let d = ISO8601DateFormatter.withFraction.date(from: iso) else { return "" }
        return d.formatted(date: .omitted, time: .shortened)
    }

    private func load() async {
        do {
            let j = try await API.request("GET", "/activity")
            items = j["activity"] as? [[String: Any]] ?? []
            spent = j["spentToday"] as? Int ?? 0
            let caps = j["caps"] as? [String: Any] ?? [:]
            perDay = caps["perDay"] as? Int ?? 0
            perPurchase = caps["perPurchase"] as? Int ?? 0
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

extension ISO8601DateFormatter {
    static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: Vault

struct VaultView: View {
    @State private var autopilot = Keyo.autopilot
    @State private var test = "—"
    @State private var testAddress: String?
    @State private var server = Keyo.serverURL
    @State private var token = Keyo.token
    @State private var status = ""
    @State private var bitrefill = "—"
    @State private var aegis = "—"
    @State private var aegisAddress: String?

    var body: some View {
        Page(title: "Vault") {
            HStack(spacing: 10) {
                balance("Bitrefill", bitrefill, icon: "gift")
                balance("Aegis", aegis, icon: "shield.lefthalf.filled")
            }
            Tablet {
                Toggle(isOn: $autopilot) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AUTOPILOT").font(Roman.caps(15, .bold)).tracking(2).foregroundStyle(Roman.gold)
                        Text("Under your limit, no tap").font(.caption).foregroundStyle(Roman.faded)
                    }
                }
                .tint(Roman.gold)
            }
            if let aegisAddress { addressCard("Aegis · mainnet", aegisAddress) }
            if let testAddress { addressCard("Aegis · testnet · \(test)", testAddress) }
            Tablet {
                Eyebrow(text: "Server")
                TextField("http://192.168.1.10:8787", text: $server)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .padding(12).background(Roman.marble, in: RoundedRectangle(cornerRadius: 10))
                SecureField("Token", text: $token)
                    .padding(12).background(Roman.marble, in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Button("Connect") { Task { await load() } }
                        .font(Roman.caps(14, .bold)).foregroundStyle(Roman.gold)
                    Spacer()
                    Text(status).font(.caption).foregroundStyle(Roman.faded)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: server) { _, v in Keyo.serverURL = v }
        .onChange(of: token) { _, v in Keyo.token = v }
        .onChange(of: autopilot) { _, v in Keyo.autopilot = v }
        .onAppear { autopilot = Keyo.autopilot; Keyo.sandbox = false }
    }

    private func addressCard(_ title: String, _ address: String) -> some View {
        Tablet {
            HStack {
                Eyebrow(text: title)
                Spacer()
                Button { UIPasteboard.general.string = address } label: {
                    Image(systemName: "doc.on.doc").foregroundStyle(Roman.gold)
                }
            }
            Text(address).font(.caption2.monospaced()).foregroundStyle(Roman.ink).lineLimit(3).truncationMode(.middle).textSelection(.enabled)
        }
    }

    private func balance(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Roman.gold)
            Text(value).font(Roman.caps(20, .bold)).foregroundStyle(Roman.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(title.uppercased()).font(Roman.caps(10, .bold)).tracking(2).foregroundStyle(Roman.faded)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() async {
        status = "…"
        do {
            let j = try await API.request("GET", "/balance", timeout: 120)
            if let b = j["bitrefill"] as? [String: Any] {
                bitrefill = "\(b["balance"] ?? 0) \(b["currency"] ?? "")"
            } else { bitrefill = "—" }
            if let z = j["zec"] as? [String: Any] {
                aegis = "\(z["total"] ?? 0) ZEC"
                aegisAddress = z["unified"] as? String
            } else { aegis = "Off" }
            if let z = j["zecTest"] as? [String: Any] {
                test = "\(z["total"] ?? 0) TAZ"
                testAddress = z["unified"] as? String
            }
            status = "Connected"
        } catch { status = error.localizedDescription }
    }
}
