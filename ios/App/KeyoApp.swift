import LocalAuthentication
import SwiftUI

@main
struct KeyoApp: App {
    @State private var approvalID: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Roman.gold)
                .onOpenURL { url in
                    guard url.scheme == "keyo", url.host == "approve" else { return }
                    approvalID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "id" })?.value
                }
                .sheet(item: Binding(get: { approvalID.map(IDBox.init) }, set: { approvalID = $0?.id })) { box in
                    ApproveView(id: box.id)
                }
        }
    }
}

struct IDBox: Identifiable { let id: String }

/// Purchases over the limit wait here for Face ID.
struct ApproveView: View {
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var request: [String: Any] = [:]
    @State private var state = "loading"
    @State private var result: String?

    var body: some View {
        VStack(spacing: 20) {
            Medallion(size: 72).padding(.top, 36)
            Text("APPROVE").font(Roman.caps(26, .black)).tracking(6).foregroundStyle(Roman.ink)
            GoldRule().padding(.horizontal, 40)
            if let inr = request["inr"] {
                let chip = request["chip"] as? [String: Any] ?? [:]
                VStack(spacing: 6) {
                    Text("₹\(String(describing: inr))").font(Roman.caps(44, .bold)).foregroundStyle(Roman.ink)
                    Text(chip["title"] as? String ?? (request["product"] as? String ?? ""))
                        .font(.headline).foregroundStyle(Roman.faded).multilineTextAlignment(.center)
                }
            }
            Spacer()
            if let result {
                Text(result).font(.callout).foregroundStyle(Roman.ink).multilineTextAlignment(.center)
                    .padding(16).frame(maxWidth: .infinity)
                    .background(Roman.travertine, in: RoundedRectangle(cornerRadius: 14))
                Button("Done") { dismiss() }.font(Roman.caps(16, .bold)).foregroundStyle(Roman.gold).padding(.bottom, 20)
            } else if state == "working" {
                ProgressView().tint(Roman.gold).padding(.bottom, 40)
            } else {
                Button { Task { await approve() } } label: {
                    Label("Approve", systemImage: "faceid")
                        .font(Roman.caps(17, .bold)).tracking(2)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .foregroundStyle(Color(hex: 0x3A280A))
                        .background(LinearGradient(colors: [Color(hex: 0xE9CC82), Color(hex: 0xC09A48)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 14))
                }
                Button("Decline") { Task { await decline() } }
                    .font(Roman.caps(14, .bold)).foregroundStyle(Roman.porphyry).padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Roman.marble.ignoresSafeArea())
        .task { await load() }
    }

    private func load() async {
        request = (try? await API.request("GET", "/approval?id=\(id)")) ?? [:]
        state = "ready"
    }

    private func approve() async {
        let ctx = LAContext()
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            guard (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Approve this purchase")) == true else { return }
        }
        state = "working"
        do {
            let out = try await API.request("POST", "/approve", body: ["id": id, "approve": true], timeout: 90)
            if let text = out["text"] as? String {
                Keyo.pendingInsert = text
                result = text
            } else {
                result = out["message"] as? String ?? "Approved"
            }
        } catch {
            result = error.localizedDescription
        }
    }

    private func decline() async {
        _ = try? await API.request("POST", "/approve", body: ["id": id, "approve": false])
        dismiss()
    }
}
