import Foundation

/// Settings both the app and the keyboard read, through the App Group.
enum Keyo {
    static let group = "group.com.arpit.keyo"
    static let defaults = UserDefaults(suiteName: group) ?? .standard

    #if targetEnvironment(simulator)
    static let defaultServer = "http://localhost:8787"
    #else
    static let defaultServer = "http://192.168.0.124:8787"
    #endif

    static var serverURL: String {
        get { defaults.string(forKey: "serverURL") ?? defaultServer }
        set { defaults.set(newValue, forKey: "serverURL") }
    }
    static var token: String {
        get { defaults.string(forKey: "token") ?? "" }
        set { defaults.set(newValue, forKey: "token") }
    }
    /// "zodl" opens Zodl to confirm; "server" sends from the Keyo server wallet.
    static var walletMode: String {
        get { defaults.string(forKey: "walletMode") ?? "zodl" }
        set { defaults.set(newValue, forKey: "walletMode") }
    }
    /// Sandbox runs every flow for real except the payment: test codes, test txids.
    static var sandbox: Bool {
        get { defaults.object(forKey: "sandbox") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "sandbox") }
    }
    /// The last message the other person sent, when the chat app can share it, so the
    /// keyboard can offer the reply before you type.
    static var incoming: (text: String, from: String)? {
        get {
            guard let t = defaults.string(forKey: "incomingText"),
                  let at = defaults.object(forKey: "incomingAt") as? Date, Date().timeIntervalSince(at) < 600 else { return nil }
            return (t, defaults.string(forKey: "incomingFrom") ?? "")
        }
        set {
            defaults.set(newValue?.text, forKey: "incomingText")
            defaults.set(newValue?.from, forKey: "incomingFrom")
            defaults.set(Date(), forKey: "incomingAt")
        }
    }
    /// Run the action the moment it's offered, without a tap, when it's under the limit.
    static var autopilot: Bool {
        get { defaults.object(forKey: "autopilot") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autopilot") }
    }
    /// The keyboard stamps this whenever it runs with Full Access (it can't write the group without it).
    static var keyboardSeen: Date? {
        get { defaults.object(forKey: "keyboardSeen") as? Date }
        set { defaults.set(newValue, forKey: "keyboardSeen") }
    }
    /// Text the app hands the keyboard after an approval, typed in when the keyboard comes back.
    /// An approved purchase's reply, waiting for the keyboard to type it. It goes stale after
    /// two minutes, so an old one never lands in a different chat.
    static var pendingInsert: String? {
        get {
            guard let text = defaults.string(forKey: "pendingInsert") else { return nil }
            let at = defaults.double(forKey: "pendingInsertAt")
            return Date().timeIntervalSince1970 - at < 120 ? text : nil
        }
        set {
            defaults.set(newValue, forKey: "pendingInsert")
            defaults.set(Date().timeIntervalSince1970, forKey: "pendingInsertAt")
        }
    }
}

/// A suggestion from the server. `raw` goes back unchanged when it's tapped.
struct Chip: Identifiable {
    let raw: [String: Any]
    var id: String { raw["id"] as? String ?? UUID().uuidString }
    var kind: String { raw["kind"] as? String ?? "" }
    var title: String { raw["title"] as? String ?? "" }
    var subtitle: String { raw["subtitle"] as? String ?? "" }
    var isSuggestion: Bool { raw["occasion"] != nil || kind == "esim" }
}

struct KeyoError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum API {
    static func request(_ method: String, _ path: String, body: [String: Any]? = nil, timeout: TimeInterval = 60) async throws -> [String: Any] {
        guard let url = URL(string: Keyo.serverURL.trimmingCharacters(in: .whitespaces) + path) else {
            throw KeyoError(message: "Bad server URL")
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !Keyo.token.isEmpty { req.setValue(Keyo.token, forHTTPHeaderField: "x-keyo-token") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let err = json["error"] as? String { throw KeyoError(message: err) }
        return json
    }

    static func suggest(_ text: String, incoming: (text: String, from: String)? = nil) async throws -> [Chip] {
        var body: [String: Any] = ["text": text]
        if let incoming { body["incoming"] = incoming.text; body["from"] = incoming.from }
        let j = try await request("POST", "/suggest", body: body, timeout: 20)
        return (j["chips"] as? [[String: Any]] ?? []).map(Chip.init)
    }

    static func act(_ chip: Chip) async throws -> [String: Any] {
        try await request("POST", "/act", body: ["chip": chip.raw, "mode": Keyo.walletMode, "sandbox": Keyo.sandbox], timeout: 240)
    }
}

/// Dollars as people write them: $25, $2.38.
enum Money {
    static func text(_ any: Any) -> String {
        let n = (any as? NSNumber)?.doubleValue ?? Double("\(any)") ?? 0
        return n.rounded() == n ? "$\(Int(n))" : String(format: "$%.2f", n)
    }
}
