import SwiftUI

/// A WhatsApp-style chat with Mom that walks through every Keyo flow. You reply with
/// the Keyo keyboard; her next message arrives when you send.
struct ChatView: View {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let mine: Bool
        let text: String
        let time = Date()
    }

    struct Scene: Identifiable {
        let id: String
        let icon: String
        let opener: String
        let hint: String
        let thanks: String
    }

    static let scenes: [Scene] = [
        Scene(id: "Recharge", icon: "iphone.gen3", opener: "My phone balance is over 😟 I can't call your father",
              hint: "recharge mom's jio for 199", thanks: "It worked! Thank you ❤️"),
        Scene(id: "Birthday", icon: "gift", opener: "It's Priya's birthday today! Did you wish her? 🎂",
              hint: "happy birthday priya!", thanks: "So sweet of you 🥰"),
        Scene(id: "Send ZEC", icon: "shield.lefthalf.filled", opener: "Can you send me 0.01 ZEC for groceries?",
              hint: "send 0.01 zec to mom", thanks: "Got it, all private 🛡️"),
        Scene(id: "Split", icon: "arrow.down.left", opener: "Thank you for dinner! What do I owe you?",
              hint: "request 0.05 zec for dinner", thanks: "Paid! 🙏"),
        Scene(id: "eSIM", icon: "simcard", opener: "I'm landing in Dubai tomorrow ✈️ How will I get internet?",
              hint: "landing in dubai tomorrow", thanks: "Installed in one tap 😮"),
        Scene(id: "Swap", icon: "arrow.triangle.2.circlepath", opener: "How do I turn my ZEC into dollars?",
              hint: "swap 0.01 zec to usdc", thanks: "Done, so easy"),
        Scene(id: "Dinner", icon: "fork.knife", opener: "Too tired to cook tonight 😴",
              hint: "order some food", thanks: "Ordering biryani 😋"),
        Scene(id: "Approve", icon: "faceid", opener: "Can you get me a ₹2000 Flipkart card for Diwali shopping?",
              hint: "send mom a 2000 flipkart gift card", thanks: "You're the best 🪔"),
    ]

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var scene = 0
    @State private var typing = false
    @State private var sandbox = Keyo.sandbox
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            scenePicker
            ZStack {
                wallpaper
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(messages) { m in bubble(m).id(m.id) }
                            if typing { typingBubble.id("typing") }
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
                }
            }
            composer
        }
        .background(WA.wallpaper)
        .onAppear {
            sandbox = Keyo.sandbox
            if messages.isEmpty { start(0) }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xE9CC82), Color(hex: 0xB0852F)], startPoint: .top, endPoint: .bottom))
                Text("M").font(Roman.caps(18, .bold)).foregroundStyle(Color(hex: 0x4A3410))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mom").font(.system(size: 17, weight: .semibold)).foregroundStyle(WA.ink)
                Text(typing ? "typing…" : "online").font(.system(size: 12.5)).foregroundStyle(WA.faded)
            }
            Spacer()
            Button {
                sandbox.toggle()
                Keyo.sandbox = sandbox
            } label: {
                Text(sandbox ? "SANDBOX" : "LIVE")
                    .font(Roman.caps(10.5, .bold)).tracking(1.5)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(sandbox ? Roman.gold : .white)
                    .background(Capsule().fill(sandbox ? Roman.travertine : Roman.porphyry))
                    .overlay(Capsule().strokeBorder(Roman.goldSoft.opacity(sandbox ? 0.6 : 0), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            Image(systemName: "video").font(.system(size: 18)).foregroundStyle(WA.icon).padding(.leading, 6)
            Image(systemName: "phone").font(.system(size: 17)).foregroundStyle(WA.icon).padding(.leading, 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(WA.bar)
    }

    private var scenePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(Self.scenes.enumerated()), id: \.offset) { i, s in
                    Button { start(i) } label: {
                        Label(s.id, systemImage: s.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(i == scene ? Color(hex: 0x3A280A) : WA.ink)
                            .background(Capsule().fill(i == scene ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE9CC82), Color(hex: 0xC09A48)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(WA.chip)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(WA.bar)
        .overlay(alignment: .bottom) { Rectangle().fill(WA.divider).frame(height: 0.5) }
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

    private func bubble(_ m: Message) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 48) }
            VStack(alignment: .trailing, spacing: 2) {
                Text(.init(linkified(m.text)))
                    .font(.system(size: 16))
                    .foregroundStyle(WA.ink)
                    .tint(Color(hex: 0x027EB5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
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
        VStack(spacing: 6) {
            if draft.isEmpty, scene < Self.scenes.count {
                Button {
                    draft = Self.scenes[scene].hint
                    focused = true
                } label: {
                    Text(Self.scenes[scene].hint)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Roman.gold)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().strokeBorder(Roman.goldSoft.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
                .buttonStyle(.plain)
            }
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WA.bar)
    }

    // MARK: Flow

    private func start(_ i: Int) {
        scene = i
        draft = ""
        momSays(Self.scenes[i].opener, delay: 0.5)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(Message(mine: true, text: text))
        draft = ""
        // A message carrying a Keyo result finishes the scene; Mom answers and the next one starts.
        let done = ["✅", "🎁", "🛡️", "📶", "🔁", "Pay me", "zcash:"].contains { text.contains($0) }
        guard done, scene < Self.scenes.count else { return }
        let finished = scene
        momSays(Self.scenes[finished].thanks, delay: 1.0)
        if finished + 1 < Self.scenes.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                scene = finished + 1
                momSays(Self.scenes[finished + 1].opener, delay: 0.4)
            }
        }
    }

    private func momSays(_ text: String, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            typing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                typing = false
                messages.append(Message(mine: false, text: text))
            }
        }
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
