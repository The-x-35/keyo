import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private var host: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        model.controller = self
        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.heightAnchor.constraint(equalToConstant: 292),
        ])
        host.didMove(toParent: self)
        self.host = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasFullAccess { Keyo.keyboardSeen = Date() }
        model.flushPendingInsert()
        model.contextChanged()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        model.flushPendingInsert()
        model.contextChanged()
    }

    /// Keyboards can't call UIApplication.shared, so walk the responder chain to it.
    func open(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
        extensionContext?.open(url, completionHandler: nil)
    }
}

@MainActor
final class KeyboardModel: ObservableObject {
    weak var controller: KeyboardViewController?

    @Published var chips: [Chip] = []
    @Published var status: String?
    @Published var busy = false
    @Published var shift = true
    @Published var numbers = false

    private var suggestTask: Task<Void, Never>?
    private var lastContext = ""

    var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }

    func type(_ s: String) {
        proxy?.insertText(s)
        if shift && !numbers { shift = false }
        contextChanged()
    }

    func space() {
        proxy?.insertText(" ")
        contextChanged()
    }

    func backspace() {
        proxy?.deleteBackward()
        contextChanged()
    }

    func newline() {
        proxy?.insertText("\n")
        shift = true
        contextChanged()
    }

    func flushPendingInsert() {
        if let text = Keyo.pendingInsert, !text.isEmpty {
            Keyo.pendingInsert = nil
            proxy?.insertText(text)
            status = "Typed in after approval ✓"
        }
    }

    /// Asks the server for chips once typing pauses.
    func contextChanged() {
        let ctx = proxy?.documentContextBeforeInput ?? ""
        if ctx.isEmpty { shift = true }
        guard ctx != lastContext else { return }
        lastContext = ctx
        suggestTask?.cancel()
        let line = ctx.components(separatedBy: "\n").last ?? ctx
        guard line.trimmingCharacters(in: .whitespaces).count >= 4 else {
            if !busy { chips = [] }
            return
        }
        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            guard hasFullAccess else {
                status = "Turn on Allow Full Access for Keyo"
                return
            }
            if let found = try? await API.suggest(line), !Task.isCancelled {
                chips = found
                if !found.isEmpty { status = nil }
            }
        }
    }

    func tap(_ chip: Chip) {
        guard !busy else { return }
        busy = true
        status = working(chip)
        Task {
            defer { busy = false }
            do {
                let out = try await API.act(chip)
                handle(out, chip)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func working(_ chip: Chip) -> String {
        switch chip.kind {
        case "topup": return "Recharging through Bitrefill…"
        case "gift", "esim": return "Buying through Bitrefill…"
        case "swap": return "Getting a swap quote…"
        case "zec_send": return Keyo.walletMode == "server" ? "Sending shielded ZEC…" : "Opening Zodl…"
        default: return "Working…"
        }
    }

    private func handle(_ out: [String: Any], _ chip: Chip) {
        let state = out["status"] as? String ?? ""
        if let text = out["text"] as? String {
            // A typed command gets replaced by its result; a suggestion adds below what you wrote.
            if chip.isSuggestion {
                proxy?.insertText("\n" + text)
            } else {
                replaceCurrentLine(with: text)
            }
            chips = []
            status = state == "done" ? "Done ✓" : nil
        } else if let msg = out["message"] as? String {
            status = msg
        }
        if let open = out["open"] as? String, let url = URL(string: open) {
            controller?.open(url)
        }
    }

    private func replaceCurrentLine(with text: String) {
        guard let proxy else { return }
        let ctx = proxy.documentContextBeforeInput ?? ""
        let line = ctx.components(separatedBy: "\n").last ?? ""
        for _ in 0..<line.count { proxy.deleteBackward() }
        proxy.insertText(text)
        lastContext = proxy.documentContextBeforeInput ?? ""
    }

    func nextKeyboard() {
        controller?.advanceToNextInputMode()
    }
}
