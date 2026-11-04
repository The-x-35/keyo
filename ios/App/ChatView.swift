import SwiftUI

/// WhatsApp-style chats with the people Keyo helps. Each chat walks through its own
/// errands: they write, you reply with the Keyo keyboard, and their next message arrives.
struct ChatView: View {
    @StateObject private var store = ChatStore()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.threads) { t in
                    // WhatsApp rows have no disclosure chevron.
                    ChatRow(thread: t, store: store)
                        .background(NavigationLink(value: t.id) { EmptyView() }.opacity(0))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chats")
            .navigationDestination(for: String.self) { id in
                if let t = store.threads.first(where: { $0.id == id }) { ThreadView(thread: t, store: store) }
            }
        }
    }
}

struct ChatThread: Identifiable {
    struct Line {
        let from: String
        let text: String
    }
    struct Scene {
        let opener: Line
        let thanks: Line
    }

    let id: String
    let name: String
    let avatar: String
    let tint: Color
    let members: [String]
    let scenes: [Scene]
    var isGroup: Bool { !members.isEmpty }

    static func say(_ from: String, _ text: String) -> Line { Line(from: from, text: text) }

    static let all: [ChatThread] = [
        ChatThread(id: "mom", name: "Mom", avatar: "M", tint: Color(hex: 0xC9A04A), members: [], scenes: [
            Scene(opener: say("Mom", "My phone balance is over 😟 I can't call your father"), thanks: say("Mom", "It worked! Thank you ❤️")),
            Scene(opener: say("Mom", "The TV stopped working, it says recharge Tata Play 📺"), thanks: say("Mom", "Channels are back 😄")),
            Scene(opener: say("Mom", "Can you recharge my phone every month so I don't have to ask? 🙈"), thanks: say("Mom", "No more asking 😄")),
        ]),
        ChatThread(id: "rahul", name: "Rahul", avatar: "R", tint: Color(hex: 0x3A7BD5), members: [], scenes: [
            Scene(opener: say("Rahul", "Dinner was ₹2,400 for the 3 of us. Send me your share when you can 🙏"), thanks: say("Rahul", "Got it bro, and nobody can see it 🛡️")),
            Scene(opener: say("Rahul", "Valorant tonight? I'm out of points 😭"), thanks: say("Rahul", "LET'S GO 🔥")),
            Scene(opener: say("Rahul", "Can you lend me some money till Friday? Like 500"), thanks: say("Rahul", "Lifesaver 🙏 paying you back Friday")),
        ]),
        ChatThread(id: "priya", name: "Priya", avatar: "P", tint: Color(hex: 0xD45D8A), members: [], scenes: [
            Scene(opener: say("Priya", "Just landed in London ✈️ no data and the airport wifi is awful 😩"), thanks: say("Priya", "Installed in one tap, I'm online!! 😮")),
            Scene(opener: say("Priya", "Btw it's my birthday today 🎂🥳"), thanks: say("Priya", "Aww just got the email 🥹 thank you!!")),
            Scene(opener: say("Priya", "My laptop charger died and I have a presentation tomorrow 😭"), thanks: say("Priya", "Ordering one now, you're the best")),
        ]),
        ChatThread(id: "alex", name: "Alex (Client)", avatar: "A", tint: Color(hex: 0x2E9E7A), members: [], scenes: [
            Scene(opener: say("Alex", "The logo is perfect! 🙌 Send me your invoice, $150. Happy to pay in ZEC"), thanks: say("Alex", "Paying now 👍")),
            Scene(opener: say("Alex", "Actually I only hold USDC on Solana. Can I pay the $150 in that?"), thanks: say("Alex", "Sent ✅ pleasure working with you")),
        ]),
        ChatThread(id: "goa", name: "Goa Trip 🏖️", avatar: "G", tint: Color(hex: 0xE08A2E), members: ["Neha", "Rahul"], scenes: [
            Scene(opener: say("Neha", "Villa came to ₹16,000 for the 4 of us. Arpit, how much each?"), thanks: say("Rahul", "Paying mine now 🙌")),
            Scene(opener: say("Rahul", "What time is sunset in Goa today?"), thanks: say("Neha", "Perfect, beach at 5 then 🌅")),
        ]),
        ChatThread(id: "team", name: "Design Team", avatar: "D", tint: Color(hex: 0x7A5AC8), members: ["Karan", "Ananya"], scenes: [
            Scene(opener: say("Karan", "It's Ananya's last day 🥲 Let's get her something nice, under ₹2000"), thanks: say("Karan", "She's going to love it ❤️")),
            Scene(opener: say("Karan", "Lunch on the team today? 🍕"), thanks: say("Karan", "Pizza party 🍕🍕")),
        ]),
    ]
}

/// Messages and progress for every chat; lives as long as the tab.
final class ChatStore: ObservableObject {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let from: String?
        let text: String
        let time = Date()
        var mine: Bool { from == nil }
    }

    let threads = ChatThread.all
    @Published var messages: [String: [Message]] = [:]
    @Published var scene: [String: Int] = [:]
    @Published var unread: [String: Int] = [:]
    @Published var typing: [String: String] = [:]

    init() {
        // Each chat opens with its first message already waiting.
        for t in threads {
            messages[t.id] = [Message(from: t.scenes[0].opener.from, text: t.scenes[0].opener.text)]
            scene[t.id] = 0
            unread[t.id] = 1
        }
    }

    func last(_ t: ChatThread) -> Message? { messages[t.id]?.last }

    /// Shares the chat's latest incoming message with the keyboard, like a reply suggestion.
    func share(_ t: ChatThread) {
        if let m = messages[t.id]?.last(where: { !$0.mine }), let from = m.from { Keyo.incoming = (m.text, from) }
        unread[t.id] = 0
    }

    func send(_ text: String, in t: ChatThread) {
        messages[t.id, default: []].append(Message(from: nil, text: text))
        let i = scene[t.id] ?? 0
        guard i < t.scenes.count else { return }
        say(t.scenes[i].thanks, in: t, after: 1.0)
        let next = (i + 1) % t.scenes.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            self.scene[t.id] = next
            self.say(t.scenes[next].opener, in: t, after: 0.4)
        }
    }

    func restart(_ t: ChatThread) {
        messages[t.id] = []
        scene[t.id] = 0
        say(t.scenes[0].opener, in: t, after: 0.3)
    }

    private func say(_ line: ChatThread.Line, in t: ChatThread, after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.typing[t.id] = line.from
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.typing[t.id] = nil
                self.messages[t.id, default: []].append(Message(from: line.from, text: line.text))
                Keyo.incoming = (line.text, line.from)
            }
        }
    }
}

struct Avatar: View {
    let thread: ChatThread
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [thread.tint.opacity(0.75), thread.tint], startPoint: .top, endPoint: .bottom))
            if thread.isGroup {
                Image(systemName: "person.2.fill").font(.system(size: size * 0.38)).foregroundStyle(.white)
            } else {
                Text(thread.avatar).font(Roman.caps(size * 0.42, .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ChatRow: View {
    let thread: ChatThread
    @ObservedObject var store: ChatStore

    var body: some View {
        HStack(spacing: 12) {
            Avatar(thread: thread)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(WA.ink).lineLimit(1)
                    Spacer()
                    if let m = store.last(thread) {
                        Text(m.time.formatted(date: .omitted, time: .shortened)).font(.system(size: 13))
                            .foregroundStyle((store.unread[thread.id] ?? 0) > 0 ? WA.green : WA.faded)
                    }
                }
                HStack(spacing: 4) {
                    if let who = store.typing[thread.id] {
                        Text(thread.isGroup ? "\(who) is typing…" : "typing…").foregroundStyle(WA.green)
                    } else if let m = store.last(thread) {
                        if m.mine { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x53BDEB)) }
                        Text(preview(m)).foregroundStyle(WA.faded)
                    }
                    Spacer()
                    if let n = store.unread[thread.id], n > 0 {
                        Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20).background(Circle().fill(WA.green))
                    }
                }
                .font(.system(size: 15))
                .lineLimit(2)
            }
        }
    }

    private func preview(_ m: ChatStore.Message) -> String {
        let text = m.text.replacingOccurrences(of: "\n", with: " ")
        if thread.isGroup, let from = m.from { return "\(from): \(text)" }
        return text
    }
}

struct ThreadView: View {
    let thread: ChatThread
    @ObservedObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var messages: [ChatStore.Message] { store.messages[thread.id] ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                wallpaper
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                            if store.typing[thread.id] != nil { typingBubble.id("typing") }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture { focused = false }
                    .onChange(of: messages) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                    .onChange(of: focused) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                    .onAppear { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            composer
        }
        .background(WA.wallpaper)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { store.share(thread) }
        .onChange(of: messages) { _, _ in store.unread[thread.id] = 0 }
        .onLongPressGesture(minimumDuration: 1.2) { store.restart(thread) }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(WA.icon)
            }
            .buttonStyle(.plain)
            Avatar(thread: thread, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(thread.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(WA.ink).lineLimit(1)
                Text(status).font(.system(size: 12.5)).foregroundStyle(WA.faded).lineLimit(1)
            }
            Spacer()
            Image(systemName: "video").font(.system(size: 19)).foregroundStyle(WA.icon)
            Image(systemName: "phone").font(.system(size: 18)).foregroundStyle(WA.icon).padding(.leading, 16)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(WA.bar)
    }

    private var status: String {
        if let who = store.typing[thread.id] { return thread.isGroup ? "\(who) is typing…" : "typing…" }
        return thread.isGroup ? (thread.members + ["You"]).joined(separator: ", ") : "online"
    }

    private var wallpaper: some View {
        WA.wallpaper.overlay(
            Colosseum(color: Roman.goldSoft)
                .frame(height: 120)
                .opacity(0.25)
                .padding(.horizontal, 40),
            alignment: .center
        )
        .onTapGesture { focused = false }
    }

    private func bubble(_ m: ChatStore.Message) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 2) {
                if thread.isGroup, let from = m.from {
                    Text(from).font(.system(size: 13, weight: .semibold)).foregroundStyle(senderColor(from))
                }
                Text(.init(linkified(m.text)))
                    .font(.system(size: 16))
                    .foregroundStyle(WA.ink)
                    .tint(Color(hex: 0x027EB5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
                    Spacer(minLength: 0)
                    Text(m.time.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).foregroundStyle(WA.faded)
                    if m.mine { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0x53BDEB)) }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(m.mine ? WA.mine : WA.theirs))
            .shadow(color: .black.opacity(0.08), radius: 0.5, y: 1)
            .frame(maxWidth: 300, alignment: m.mine ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            if !m.mine { Spacer(minLength: 48) }
        }
    }

    private func senderColor(_ name: String) -> Color {
        let palette: [UInt32] = [0xD45D8A, 0x3A7BD5, 0x2E9E7A, 0xE08A2E, 0x7A5AC8]
        let i = name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return Color(hex: palette[i])
    }

    private var typingBubble: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in Circle().fill(WA.faded).frame(width: 7, height: 7) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(WA.theirs))
            Spacer()
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "plus").font(.system(size: 20)).foregroundStyle(WA.icon).padding(.bottom, 9)
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 20).fill(WA.field))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(WA.divider, lineWidth: 0.5))
            Button(action: send) {
                Image(systemName: draft.isEmpty ? "mic.fill" : "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(WA.green))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WA.bar)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        store.send(text, in: thread)
    }

    private func linkified(_ s: String) -> String {
        // Markdown links make install and payment links tappable in the bubble.
        s.split(separator: " ", omittingEmptySubsequences: false).map { w in
            let t = String(w)
            if t.hasPrefix("https://") { return "[\(t.count > 40 ? String(t.prefix(38)) + "…" : t)](\(t))" }
            if t.hasPrefix("zcash:") { return "[zcash payment link](\(t))" }
            return t.replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "_", with: "\\_")
        }.joined(separator: " ")
    }
}

/// WhatsApp's palette, light and dark.
enum WA {
    static let wallpaper = Roman.dyn(0xEFEAE2, 0x0B141A)
    static let bar = Roman.dyn(0xF6F5F3, 0x1F2C34)
    static let mine = Roman.dyn(0xD9FDD3, 0x005C4B)
    static let theirs = Roman.dyn(0xFFFFFF, 0x202C33)
    static let field = Roman.dyn(0xFFFFFF, 0x2A3942)
    static let chip = Roman.dyn(0xFFFFFF, 0x2A3942)
    static let ink = Roman.dyn(0x111B21, 0xE9EDEF)
    static let faded = Roman.dyn(0x667781, 0x8696A0)
    static let icon = Roman.dyn(0x54656F, 0xAEBAC1)
    static let divider = Roman.dyn(0xD1D7DB, 0x2A3942)
    static let green = Color(hex: 0x25D366)
}
