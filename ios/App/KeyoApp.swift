import LocalAuthentication
import SwiftUI

@main
struct KeyoApp: App {
    @State private var approvalID: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color(red: 0.93, green: 0.5, blue: 0.1))
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
        VStack(spacing: 18) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Approve purchase").font(.title2.bold())
            if let inr = request["inr"] {
                let chip = request["chip"] as? [String: Any] ?? [:]
                Text("\(chip["title"] as? String ?? (request["product"] as? String ?? ""))")
                    .font(.headline)
                Text("₹\(String(describing: inr)) is over your limit").foregroundStyle(.secondary)
            }
            if let result {
                Text(result).font(.callout).multilineTextAlignment(.center).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                Text("Go back to the chat: Keyo types it in.").font(.footnote).foregroundStyle(.secondary)
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            } else if state == "working" {
                ProgressView("Buying through Bitrefill…")
            } else {
                Button { Task { await approve() } } label: {
                    Label("Approve with Face ID", systemImage: "faceid").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Decline", role: .destructive) { Task { await decline() } }
            }
            Spacer()
        }
        .padding(28)
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
