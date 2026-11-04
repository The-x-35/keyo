import SwiftUI

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    @Environment(\.colorScheme) private var scheme

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

    var body: some View {
        VStack(spacing: 0) {
            Strip(model: model)
                .frame(height: 48)
            VStack(spacing: 11) {
                let rows = model.numbers ? digits : letters
                row(rows[0])
                row(rows[1]).padding(.horizontal, model.numbers ? 0 : 18)
                HStack(spacing: 6) {
                    special(model.numbers ? "#+=" : nil, icon: model.numbers ? nil : (model.shift ? "shift.fill" : "shift"), width: 44) {
                        if !model.numbers { model.shift.toggle() }
                    }
                    Spacer(minLength: 4)
                    row(rows[2])
                    Spacer(minLength: 4)
                    special(nil, icon: "delete.left", width: 44, repeats: true) { model.backspace() }
                }
                HStack(spacing: 6) {
                    special(model.numbers ? "ABC" : "123", icon: nil, width: 46) { model.numbers.toggle() }
                    if model.needsGlobe {
                        special(nil, icon: "globe", width: 40) { model.nextKeyboard() }
                    }
                    Key(label: "space", fill: keyFill, ink: ink, fontSize: 16) { model.space() }
                    special("return", icon: nil, width: 92) { model.newline() }
                }
            }
            .padding(.horizontal, 3)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .background(board)
    }

    private func row(_ keys: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { k in
                let shown = model.shift && !model.numbers ? k.uppercased() : k
                Key(label: shown, fill: keyFill, ink: ink, fontSize: 23) { model.type(shown) }
            }
        }
    }

    private func special(_ label: String?, icon: String?, width: CGFloat, repeats: Bool = false, action: @escaping () -> Void) -> some View {
        Key(label: label, icon: icon, fill: specialFill, ink: ink, fontSize: 15, repeats: repeats, action: action)
            .frame(width: width)
    }

    private var board: Color { Roman.board }
    private var keyFill: Color { Roman.key }
    private var specialFill: Color { Roman.keySpecial }
    private var ink: Color { Roman.ink }
}

struct Key: View {
    var label: String?
    var icon: String? = nil
    var fill: Color
    var ink: Color
    var fontSize: CGFloat
    var repeats = false
    var action: () -> Void

    @State private var pressed = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(pressed ? fill.opacity(0.6) : fill)
                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            if let icon {
                Image(systemName: icon).font(.system(size: 18, weight: .regular))
            } else if let label {
                Text(label).font(.system(size: fontSize))
            }
        }
        .foregroundStyle(ink)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            Medallion(size: 30)
            if model.busy {
                ProgressView().scaleEffect(0.8).tint(Roman.gold)
                Text(model.status ?? "Working…").font(.system(size: 14, weight: .medium)).foregroundStyle(Roman.ink).lineLimit(1)
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
            } else {
                Text(model.status ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Roman.faded)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }
}

struct ChipView: View {
    let chip: Chip
    @Environment(\.colorScheme) private var scheme

    var icon: String {
        switch chip.kind {
        case "topup": return "iphone.gen3"
        case "gift": return "gift.fill"
        case "esim": return "simcard.fill"
        case "swap": return "arrow.triangle.2.circlepath"
        case "zec_request": return "arrow.down.left"
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
        .frame(height: 38)
        .background(Capsule().fill(Roman.key))
        .overlay(Capsule().strokeBorder(Roman.gold.opacity(0.7), lineWidth: 1))
        .foregroundStyle(Roman.ink)
    }
}
