import Foundation

/// Settings both the app and the keyboard read, through the App Group.
enum Keyo {
    static let group = "group.com.arpit.keyo"
    static let defaults = UserDefaults(suiteName: group) ?? .standard

    static var serverURL: String {
        get { defaults.string(forKey: "serverURL") ?? "http://localhost:8787" }
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
    /// Text the app hands the keyboard after an approval, typed in when the keyboard comes back.
    static var pendingInsert: String? {
        get { defaults.string(forKey: "pendingInsert") }
        set { defaults.set(newValue, forKey: "pendingInsert") }
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

    static func suggest(_ text: String) async throws -> [Chip] {
        let j = try await request("POST", "/suggest", body: ["text": text], timeout: 8)
        return (j["chips"] as? [[String: Any]] ?? []).map(Chip.init)
    }

    static func act(_ chip: Chip) async throws -> [String: Any] {
        try await request("POST", "/act", body: ["chip": chip.raw, "mode": Keyo.walletMode], timeout: 90)
    }
}
