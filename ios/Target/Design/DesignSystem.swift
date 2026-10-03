import SwiftUI

enum DesignSystem {
    enum Space {
        static let unit: CGFloat = 8
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
    enum Radius {
        static let key: CGFloat = 8
        static let panel: CGFloat = 16
    }
    enum Palette {
        static let paper = Color(red: 0.96, green: 0.94, blue: 0.88)
        static let ink = Color(red: 0.10, green: 0.15, blue: 0.19)
        static let muted = Color(red: 0.35, green: 0.39, blue: 0.40)
        static let line = Color(red: 0.77, green: 0.78, blue: 0.74)
        static let tile = Color(red: 1.0, green: 0.99, blue: 0.96)
        static let keyBase = Color(red: 0.66, green: 0.68, blue: 0.65)
        static let accent = Color(red: 0.91, green: 0.28, blue: 0.13)
        static let success = Color(red: 0.13, green: 0.39, blue: 0.29)
    }
    enum TypeStyle {
        static let brand = Font.system(size: 64, weight: .black, design: .rounded)
        static let target = Font.system(size: 112, weight: .heavy, design: .rounded)
        static let key = Font.system(size: 36, weight: .bold, design: .rounded)
        static let title = Font.system(size: 40, weight: .black, design: .rounded)
        static let score = Font.system(size: 56, weight: .heavy, design: .rounded)
        static let label = Font.system(.caption, design: .monospaced).weight(.semibold)
        static let body = Font.system(.body, design: .rounded).weight(.medium)
    }
    enum Motion {
        static let press = Animation.easeOut(duration: 0.08)
        static let merge = Animation.spring(duration: 0.17, bounce: 0.12)
        static let spring = Animation.spring(duration: 0.28, bounce: 0.22)
        static let celebration = Animation.spring(duration: 0.55, bounce: 0.25)
    }

    struct ActionStyle: ButtonStyle {
        var primary = true
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(primary ? Palette.paper : Palette.ink)
                .background(primary ? Palette.ink : Color.clear, in: RoundedRectangle(cornerRadius: Radius.key))
                .overlay(RoundedRectangle(cornerRadius: Radius.key).stroke(Palette.ink, lineWidth: primary ? 0 : 1.5))
                .opacity(enabled ? 1 : 0.35)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
        }
    }

    struct TileStyle: ButtonStyle {
        var selected = false
        var result = false
        var operatorKey = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func makeBody(configuration: Configuration) -> some View {
            let face = selected ? Palette.accent : result ? Palette.success : operatorKey ? Palette.ink : Palette.tile
            let depth: CGFloat = configuration.isPressed ? 1 : 4
            configuration.label
                .font(TypeStyle.key)
                .foregroundStyle(selected || result || operatorKey ? Palette.paper : Palette.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: Radius.key).fill(Palette.keyBase).offset(y: 4)
                    RoundedRectangle(cornerRadius: Radius.key).fill(face).offset(y: 4 - depth)
                }
                .overlay(alignment: .bottom) {
                    if selected {
                        Capsule().fill(Palette.paper).frame(width: 24, height: 3).padding(.bottom, 8)
                    }
                }
                .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
                .opacity(enabled || !operatorKey ? 1 : 0.4)
                .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(progress * .pi * 6) * 5, y: 0))
    }
}
