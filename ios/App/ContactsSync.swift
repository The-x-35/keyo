import Contacts
import Foundation

/// Reads the phone's contacts and hands names, numbers and emails to the Keyo server,
/// keeping any Zcash address or operator already saved for a person.
enum ContactsSync {
    static var authorized: Bool { CNContactStore.authorizationStatus(for: .contacts) == .authorized }

    static func requestAndSync() async throws -> Int {
        let store = CNContactStore()
        if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
            guard try await store.requestAccess(for: .contacts) else { return 0 }
        }
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey,
                    CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        var found: [[String: Any]] = []
        let req = CNContactFetchRequest(keysToFetch: keys)
        try store.enumerateContacts(with: req) { c, _ in
            let name = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty, let phone = c.phoneNumbers.first?.value.stringValue else { return }
            var aliases = Set([name.lowercased(), c.givenName.lowercased()])
            if !c.nickname.isEmpty { aliases.insert(c.nickname.lowercased()) }
            // Family names people type: "mom", "dad", "bro"…
            for (key, words) in family where words.contains(where: { aliases.contains($0) }) { aliases.insert(key) }
            found.append([
                "name": name,
                "aliases": Array(aliases.filter { !$0.isEmpty }),
                "phone": e164(phone),
                "email": c.emailAddresses.first.map { String($0.value) } ?? "",
                "source": "contacts",
            ])
        }

        let current = (try? await API.request("GET", "/contacts"))?["contacts"] as? [[String: Any]] ?? []
        var byName: [String: [String: Any]] = [:]
        for c in current { byName[(c["name"] as? String ?? "").lowercased()] = c }
        for var c in found {
            let key = (c["name"] as? String ?? "").lowercased()
            // The chats' people keep their own number and email; the phone's contacts never replace them.
            if byName[key]?["pinned"] as? Bool == true { continue }
            // A phone contact never takes a chat person's family alias ("mom").
            if let aliases = c["aliases"] as? [String] {
                let taken = Set(current.filter { $0["pinned"] as? Bool == true }.flatMap { ($0["aliases"] as? [String] ?? []) + [($0["name"] as? String ?? "").lowercased()] })
                c["aliases"] = aliases.filter { !taken.contains($0) }
            }
            if let old = byName[key] {
                c["zec"] = old["zec"] ?? ""
                c["operator"] = old["operator"] ?? guessOperator()
            } else {
                c["zec"] = ""
                c["operator"] = guessOperator()
            }
            byName[key] = c
        }
        _ = try await API.request("POST", "/contacts", body: ["contacts": Array(byName.values)])
        return found.count
    }

    private static let family: [String: [String]] = [
        "mom": ["mom", "mum", "mummy", "mommy", "maa", "mother", "amma", "ma"],
        "dad": ["dad", "papa", "daddy", "father", "pa"],
        "bro": ["bro", "brother", "bhai"],
        "sis": ["sis", "sister", "didi"],
    ]

    private static func guessOperator() -> String { "jio" }

    /// Indian numbers without a country code get +91.
    static func e164(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        if digits.hasPrefix("+") { return digits }
        let d = digits.filter(\.isNumber)
        if d.count == 10 { return "+91" + d }
        if d.count == 12, d.hasPrefix("91") { return "+" + d }
        return "+" + d
    }
}
