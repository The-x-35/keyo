import SwiftUI
import UIKit

/// Keyo's look: marble and travertine by day, basalt at night, gold leaf, Roman capitals.
enum Roman {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    static let marble = dyn(0xF4F0E8, 0x15120F)
    static let travertine = dyn(0xE8DFCF, 0x211D19)
    static let stone = dyn(0xD9CDB8, 0x2E2924)
    static let ink = dyn(0x1F1A15, 0xF1E9DA)
    static let faded = dyn(0x7A6E5E, 0x9A8F7E)
    static let gold = dyn(0xA67C2E, 0xD4AF5F)
    static let goldSoft = dyn(0xC9A55A, 0x8C7238)
    static let porphyry = dyn(0x5E2A48, 0xB77A9C)
    static let key = dyn(0xFFFDF8, 0x3A342E)
    static let keySpecial = dyn(0xCFC3AE, 0x27231F)
    static let board = dyn(0xDDD3C2, 0x161310)

    static func caps(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .custom("Cinzel-Regular", size: size).weight(weight)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Gold medallion with a laurel-ringed K, the brand mark.
struct Medallion: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xE9CC82), Color(hex: 0xB0852F)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Color(hex: 0x7C5A1C).opacity(0.55), lineWidth: max(1, size * 0.04))
                .padding(size * 0.1)
            Laurel().stroke(Color(hex: 0x7C5A1C).opacity(0.6), lineWidth: max(0.8, size * 0.03))
                .padding(size * 0.13)
            Text("K")
                .font(.custom("Cinzel-Regular", size: size * 0.5).weight(.black))
                .foregroundStyle(Color(hex: 0x4A3410))
                .offset(y: size * 0.01)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}

/// Two arcs of leaves, open at the top, like a victor's wreath.
struct Laurel: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) / 2
        for side in [-1.0, 1.0] {
            for i in 0..<6 {
                let a = (Double.pi / 2) + side * (0.45 + Double(i) * 0.38)
                let pt = CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a))
                let tilt = a + side * 0.9
                let len = rad * 0.28
                p.move(to: pt)
                p.addQuadCurve(to: CGPoint(x: pt.x + len * cos(tilt), y: pt.y + len * sin(tilt)),
                               control: CGPoint(x: pt.x + len * 0.6 * cos(tilt - 0.6), y: pt.y + len * 0.6 * sin(tilt - 0.6)))
            }
        }
        return p
    }
}

/// The ruined Colosseum: three arcaded tiers and an attic, broken away on the right.
struct Colosseum: View {
    var color: Color = Roman.gold

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let ground = h * 0.96
            let tierH = h * 0.24
            // Silhouette of what's still standing: full height on the left, stepping down to the right.
            var ruin = Path()
            ruin.move(to: CGPoint(x: 0, y: ground))
            ruin.addLine(to: CGPoint(x: 0, y: ground - tierH * 3.55))
            ruin.addLine(to: CGPoint(x: w * 0.46, y: ground - tierH * 3.55))
            ruin.addLine(to: CGPoint(x: w * 0.5, y: ground - tierH * 3.2))
            ruin.addLine(to: CGPoint(x: w * 0.55, y: ground - tierH * 3.3))
            ruin.addLine(to: CGPoint(x: w * 0.6, y: ground - tierH * 2.75))
            ruin.addLine(to: CGPoint(x: w * 0.67, y: ground - tierH * 2.9))
            ruin.addLine(to: CGPoint(x: w * 0.73, y: ground - tierH * 2.1))
            ruin.addLine(to: CGPoint(x: w * 0.8, y: ground - tierH * 2.2))
            ruin.addLine(to: CGPoint(x: w * 0.86, y: ground - tierH * 1.35))
            ruin.addLine(to: CGPoint(x: w * 0.93, y: ground - tierH * 1.45))
            ruin.addLine(to: CGPoint(x: w, y: ground - tierH * 0.7))
            ruin.addLine(to: CGPoint(x: w, y: ground))
            ruin.closeSubpath()

            var art = Path()
            let cols = 9
            let bay = w / CGFloat(cols)
            for tier in 0..<3 {
                let bottom = ground - CGFloat(tier) * tierH
                let top = bottom - tierH
                art.move(to: CGPoint(x: 0, y: top)); art.addLine(to: CGPoint(x: w, y: top))
                art.move(to: CGPoint(x: 0, y: top + tierH * 0.1)); art.addLine(to: CGPoint(x: w, y: top + tierH * 0.1))
                for i in 0..<cols {
                    let x0 = CGFloat(i) * bay
                    let openW = bay * 0.56
                    let ox = x0 + (bay - openW) / 2
                    let springY = bottom - tierH * 0.42
                    var arch = Path()
                    arch.move(to: CGPoint(x: ox, y: bottom))
                    arch.addLine(to: CGPoint(x: ox, y: springY))
                    arch.addArc(center: CGPoint(x: ox + openW / 2, y: springY), radius: openW / 2,
                                startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    arch.addLine(to: CGPoint(x: ox + openW, y: bottom))
                    art.addPath(arch)
                    // Half-columns between the bays.
                    art.move(to: CGPoint(x: x0, y: bottom)); art.addLine(to: CGPoint(x: x0, y: top + tierH * 0.1))
                }
            }
            // Attic storey with small windows.
            let atticBottom = ground - tierH * 3
            for i in 0..<cols where i % 2 == 0 {
                let x = CGFloat(i) * bay + bay * 0.38
                art.addRect(CGRect(x: x, y: atticBottom - tierH * 0.38, width: bay * 0.24, height: tierH * 0.2))
            }

            ctx.clip(to: ruin)
            ctx.fill(ruin, with: .color(color.opacity(0.07)))
            ctx.stroke(art, with: .color(color.opacity(0.85)), lineWidth: 1.1)
            ctx.stroke(ruin, with: .color(color), lineWidth: 1.6)
        }
        .overlay(alignment: .bottomTrailing) {
            // Fallen blocks.
            Canvas { ctx, size in
                for (x, y, s) in [(0.9, 0.93, 0.03), (0.95, 0.95, 0.022), (0.84, 0.95, 0.018)] {
                    let r = CGRect(x: size.width * x, y: size.height * y, width: size.width * s * 1.6, height: size.width * s)
                    ctx.stroke(Path(r), with: .color(color.opacity(0.8)), lineWidth: 1)
                }
            }
        }
    }
}

/// A thin gold rule with a small diamond in the middle.
struct GoldRule: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Roman.goldSoft).frame(height: 0.8)
            Rectangle().fill(Roman.gold).frame(width: 6, height: 6).rotationEffect(.degrees(45))
            Rectangle().fill(Roman.goldSoft).frame(height: 0.8)
        }
    }
}
