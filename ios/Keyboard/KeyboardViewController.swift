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
            host.view.heightAnchor.constraint(equalToConstant: KeyMetrics.height),
        ])
        host.didMove(toParent: self)
        self.host = host
    }

    private var watch: Timer?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.resetContext()
        if hasFullAccess { Keyo.keyboardSeen = Date() }
        model.flushPendingInsert()
        model.contextChanged()
        // A new message can arrive while the keyboard is up with an empty box; check for it.
        watch?.invalidate()
        watch = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, (self.textDocumentProxy.documentContextBeforeInput ?? "").isEmpty else { return }
            self.model.contextChanged()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        watch?.invalidate()
        watch = nil
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
    @Published var capsLock = false
    @Published var numbers = false
    @Published var symbols = false
    @Published var words: [String] = []

    private var lastShiftTap = Date.distantPast
    private let checker = UITextChecker()

    private var suggestTask: Task<Void, Never>?
    private var lastAutopilot: String?
    private var lastContext = ""

    var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    var hasFullAccess: Bool { controller?.hasFullAccess ?? false }

    func type(_ s: String) {
        proxy?.insertText(s)
        if shift && !numbers && !capsLock { shift = false }
        // Apple's number layer drops back to letters after an apostrophe.
        if numbers && s == "'" { numbers = false; symbols = false }
        contextChanged()
    }

    func space() {
        // Double space types a period, like Apple's keyboard.
        let ctx = proxy?.documentContextBeforeInput ?? ""
        if ctx.hasSuffix(" "), let c = ctx.dropLast().last, c.isLetter || c.isNumber {
            proxy?.deleteBackward()
            proxy?.insertText(". ")
        } else {
            proxy?.insertText(" ")
        }
        if numbers { numbers = false; symbols = false }
        contextChanged()
    }

    func tapShift() {
        if Date().timeIntervalSince(lastShiftTap) < 0.3 {
            capsLock = true
            shift = true
        } else {
            capsLock = false
            shift.toggle()
        }
        lastShiftTap = Date()
    }

    func toggleNumbers() {
        numbers.toggle()
        symbols = false
    }

    var returnLabel: String {
        switch proxy?.returnKeyType {
        case .send: return "send"
        case .go: return "go"
        case .search, .google, .yahoo: return "search"
        case .done: return "done"
        case .next: return "next"
        case .join: return "join"
        default: return "return"
        }
    }

    func pickWord(_ w: String) {
        guard let proxy else { return }
        let w = w.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let ctx = proxy.documentContextBeforeInput ?? ""
        let partial = ctx.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        for _ in 0..<partial.count { proxy.deleteBackward() }
        proxy.insertText(w + " ")
        contextChanged()
    }

    /// Completions for the word being typed, from the system dictionary.
    private func updateWords(_ ctx: String) {
        let partial = ctx.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        guard partial.count >= 1, partial.allSatisfy({ $0.isLetter || $0 == "'" }) else { words = []; return }
        let range = NSRange(location: 0, length: (partial as NSString).length)
        var out = [partial]
        let misspelled = checker.rangeOfMisspelledWord(in: partial, range: range, startingAt: 0, wrap: false, language: "en_US")
        if misspelled.location != NSNotFound, let fix = checker.guesses(forWordRange: range, in: partial, language: "en_US")?.first {
            out = ["\"\(partial)\"", fix]
        }
        for c in checker.completions(forPartialWordRange: range, in: partial, language: "en_US") ?? [] where out.count < 3 && c.lowercased() != partial.lowercased() {
            out.append(c)
        }
        words = Array(out.prefix(3))
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

    func resetContext() { lastContext = "\u{0}" }

    func flushPendingInsert() {
        if let text = Keyo.pendingInsert, !text.isEmpty {
            Keyo.pendingInsert = nil
            proxy?.insertText(text)
            status = "Done ✓"
        }
    }

    /// Asks the server for chips once typing pauses.
    func contextChanged() {
        let ctx = proxy?.documentContextBeforeInput ?? ""
        let trimmed = ctx.replacingOccurrences(of: " ", with: "")
        if !capsLock {
            shift = ctx.isEmpty || ctx.hasSuffix("\n") || (ctx.hasSuffix(" ") && [".", "!", "?"].contains(trimmed.last.map(String.init) ?? ""))
        }
        updateWords(ctx)
        let incoming = Keyo.incoming
        let empty = ctx.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // An empty box looks unchanged, so a new incoming message has to count as a change.
        let key = empty ? "incoming:\(incoming?.text ?? "")" : ctx
        guard key != lastContext else { return }
        lastContext = key
        suggestTask?.cancel()
        let line = ctx.components(separatedBy: "\n").last ?? ctx
        if empty, let incoming {
            // Empty reply box: offer what the other person just asked for.
            suggestTask = Task {
                guard hasFullAccess, let found = try? await API.suggest("", incoming: incoming), !Task.isCancelled else { return }
                chips = found
                status = nil
                // One clear action for a fresh message: Autopilot runs it, you just hit send.
                if Keyo.autopilot, found.count == 1, let chip = found.first,
                   ["topup", "zec_send", "zec_request", "esim", "gift", "swap", "swap_in"].contains(chip.kind),
                   lastAutopilot != incoming.text {
                    lastAutopilot = incoming.text
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    if !Task.isCancelled { tap(chip, auto: true) }
                }
            }
            return
        }
        guard line.trimmingCharacters(in: .whitespaces).count >= 4 else {
            if !busy { chips = []; status = nil }
            return
        }
        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            guard hasFullAccess else {
                status = "Turn on Allow Full Access for Keyo"
                return
            }
            if let found = try? await API.suggest(line, incoming: incoming), !Task.isCancelled {
                chips = found
                status = nil
            }
        }
    }

    func tap(_ chip: Chip, auto: Bool = false) {
        guard !busy else { return }
        busy = true
        status = (auto ? "Autopilot · " : "") + working(chip)
        Task {
            defer { busy = false }
            do {
                let out = try await API.act(chip)
                handle(out, chip)
            } catch {
                chips = []
                status = error.localizedDescription
            }
        }
    }

    private func working(_ chip: Chip) -> String {
        switch chip.kind {
        case "topup": return "Recharging…"
        case "gift", "esim": return "Buying the gift card…"
        case "swap": return "Checking the price…"
        case "zec_send": return Keyo.walletMode == "server" || Keyo.sandbox ? "Sending ZEC privately…" : "Opening Zodl…"
        case "zec_request": return chip.raw["usd"] != nil ? "Making the invoice…" : "Making a payment link…"
        case "meet": return "Booking it…"
        case "swap_in": return "Making a payment address…"
        case "schedule": return "Setting it to repeat…"
        case "answer": return "Thinking…"
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
            chips = []
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

    var needsGlobe: Bool { controller?.needsInputModeSwitchKey ?? true }

    func nextKeyboard() {
        controller?.advanceToNextInputMode()
    }
}
