import SwiftUI

/// Apple's keyboard geometry, measured on iOS 26: 43pt keys in 54pt rows, 6.5pt side
/// margins, 6pt gaps, a 45pt suggestion strip; only key width scales with the phone.
enum KeyMetrics {
    static let strip: CGFloat = 45
    static let row: CGFloat = 54
    static let key: CGFloat = 43
    static let margin: CGFloat = 6.5
    static let gap: CGFloat = 6
    static var height: CGFloat { strip + row * 4 }
    static func keyWidth(_ w: CGFloat) -> CGFloat { (w - margin * 2 - gap * 9) / 10 }
}

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel

    private let letters = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]
    private let digits = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "₹", "&", "@", "\""],
        [".", ",", "?", "!", "'"],
    ]
    private let symbols = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "$", "€", "£", "•"],
        [".", ",", "?", "!", "'"],
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let kw = KeyMetrics.keyWidth(w)
            let rows = model.numbers ? (model.symbols ? symbols : digits) : letters
            let side = kw * 1.27 + 2
            let wide = kw * 2 + KeyMetrics.gap + 4.5
            VStack(spacing: 0) {
                Strip(model: model).frame(height: KeyMetrics.strip)
                row(rows[0], kw: kw).frame(height: KeyMetrics.row)
                row(rows[1], kw: kw).frame(height: KeyMetrics.row)
                HStack(spacing: 0) {
                    // Shift and delete sit on the margins; the letters stay centred between them.
                    if model.numbers {
                        special(model.symbols ? "123" : "#+=", icon: nil, width: side) { model.symbols.toggle() }
                    } else {
                        special(nil, icon: model.capsLock ? "capslock.fill" : (model.shift ? "shift.fill" : "shift"), width: side, lit: model.shift) {
                            model.tapShift()
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: KeyMetrics.gap) {
                        ForEach(rows[2], id: \.self) { k in letterKey(k, width: model.numbers ? kw * 1.36 : kw) }
                    }
                    Spacer(minLength: 0)
                    special(nil, icon: "delete.left", width: side, repeats: true) { model.backspace() }
                }
                .padding(.horizontal, KeyMetrics.margin)
                .frame(height: KeyMetrics.row)
                HStack(spacing: KeyMetrics.gap) {
                    if model.needsGlobe {
                        special(model.numbers ? "ABC" : "123", icon: nil, width: side) { model.toggleNumbers() }
                        special(nil, icon: "globe", width: side) { model.nextKeyboard() }
                    } else {
                        special(model.numbers ? "ABC" : "123", icon: nil, width: wide) { model.toggleNumbers() }
                    }
                    Key(label: "space", fill: Roman.key, ink: Roman.ink, fontSize: 16) { model.space() }
                    special(model.returnLabel, icon: nil, width: wide) { model.newline() }
                }
                .padding(.horizontal, KeyMetrics.margin)
                .frame(height: KeyMetrics.row)
            }
        }
        .frame(height: KeyMetrics.height)
        .background(Roman.board)
    }

    private func row(_ keys: [String], kw: CGFloat) -> some View {
        HStack(spacing: KeyMetrics.gap) {
            ForEach(keys, id: \.self) { k in letterKey(k, width: kw) }
        }
        .frame(maxWidth: .infinity)
    }

    private func letterKey(_ k: String, width: CGFloat) -> some View {
        let upper = model.shift && !model.numbers
        let shown = upper ? k.uppercased() : k
        // Apple draws capitals smaller than lowercase so both read as one size.
        return Key(label: shown, fill: Roman.key, ink: Roman.ink,
                   fontSize: model.numbers ? 22.5 : (upper ? 22 : 24.5),
                   nudge: upper ? 1 : (model.numbers ? 0 : -1)) { model.type(shown) }
            .frame(width: width)
    }

    private func special(_ label: String?, icon: String?, width: CGFloat, repeats: Bool = false, lit: Bool = false, action: @escaping () -> Void) -> some View {
        Key(label: label, icon: icon, fill: lit ? Roman.key : Roman.keySpecial, ink: Roman.ink, fontSize: 16, repeats: repeats, action: action)
            .frame(width: width)
    }
}

struct Key: View {
    var label: String?
    var icon: String? = nil
    var fill: Color
    var ink: Color
    var fontSize: CGFloat
    var nudge: CGFloat = 0
    var repeats = false
    var action: () -> Void

    @State private var pressed = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                .fill(pressed ? Roman.keySpecial : fill)
                .shadow(color: .black.opacity(0.22), radius: 0, x: 0, y: 1)
            if let icon {
                Image(systemName: icon).font(.system(size: 19, weight: .regular))
            } else if let label {
                Text(label).font(.system(size: fontSize)).offset(y: nudge)
            }
        }
        .foregroundStyle(ink)
        .frame(height: KeyMetrics.key)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle().inset(by: -3))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    action()
                    if repeats {
                        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
                            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in action() }
                        }
                    }
                }
                .onEnded { _ in
                    pressed = false
                    timer?.invalidate()
                    timer = nil
                }
        )
    }
}

struct Strip: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        HStack(spacing: 8) {
            Medallion(size: 30)
            if model.busy {
                ProgressView().scaleEffect(0.8).tint(Roman.gold)
                Text(model.status ?? "").font(.system(size: 14, weight: .medium)).foregroundStyle(Roman.ink).lineLimit(1)
                Spacer()
            } else if !model.chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.chips) { chip in
                            Button { model.tap(chip) } label: { ChipView(chip: chip) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            } else if let status = model.status {
                Text(status)
                    .font(.system(size: 14))
                    .foregroundStyle(Roman.faded)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            } else {
                WordBar(words: model.words) { model.pickWord($0) }
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Three equal slots split by hairlines, like Apple's suggestion bar.
struct WordBar: View {
    let words: [String]
    let pick: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                let w = i < words.count ? words[i] : ""
                Button { if !w.isEmpty { pick(w) } } label: {
                    Text(w).font(.system(size: 17)).foregroundStyle(Roman.ink).lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < 2 { Rectangle().fill(Roman.stone).frame(width: 1, height: 23) }
            }
        }
    }
}

struct ChipView: View {
    let chip: Chip

    var icon: String {
        switch chip.kind {
        case "topup": return "iphone.gen3"
        case "gift": return "gift.fill"
        case "esim": return "simcard.fill"
        case "swap": return "arrow.triangle.2.circlepath"
        case "zec_request": return "arrow.down.left"
        case "price": return "chart.line.uptrend.xyaxis"
        case "answer": return "sparkles"
        default: return "shield.lefthalf.filled"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Roman.gold)
            VStack(alignment: .leading, spacing: 0) {
                Text(chip.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                if !chip.subtitle.isEmpty {
                    Text(chip.subtitle).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Roman.faded).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 36)
        .background(Capsule().fill(Roman.key))
        .overlay(Capsule().strokeBorder(Roman.gold.opacity(0.7), lineWidth: 1))
        .foregroundStyle(Roman.ink)
    }
}
