import SwiftUI

@MainActor
struct ResultView: View {
    let model: GameViewModel
    let result: RoundResult
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var celebrate = false

    private var emphasis: Color {
        result.exact ? DesignSystem.Palette.success : result.distance <= 10 ? DesignSystem.Palette.accent : DesignSystem.Palette.ink
    }

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(home: model.home)
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Image(systemName: result.exact ? "scope" : "equal")
                            .font(.system(size: 48, weight: .medium)).foregroundStyle(emphasis)
                            .scaleEffect(celebrate ? 1 : 0.9)
                        if result.exact, !reduceMotion { ExactParticles(expanded: celebrate) }
                    }.frame(height: 80).padding(.top, 24).accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Caption(result.exact ? "RIGHT ON THE NUMBER" : result.seconds == 0 ? "TIME’S UP" : "ALL TILES COMBINED")
                        Text(result.title).font(DesignSystem.TypeStyle.title).tracking(-1)
                            .foregroundStyle(emphasis).lineLimit(1).minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("resultTitle")
                    }
                    HStack {
                        value("TARGET", result.target)
                        Rectangle().fill(DesignSystem.Palette.line).frame(width: 1, height: 56)
                        value("CLOSEST", result.closest)
                    }.padding(.vertical, 16)
                        .overlay(alignment: .top) { Rectangle().fill(DesignSystem.Palette.line).frame(height: 1) }
                        .overlay(alignment: .bottom) { Rectangle().fill(DesignSystem.Palette.line).frame(height: 1) }
                    HStack(spacing: 16) {
                        Caption("OFF BY")
                        Text("\(result.distance)")
                            .font(.system(size: result.distance <= 1 ? 48 : 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(emphasis)
                        if result.exact { Image(systemName: "checkmark").foregroundStyle(emphasis) }
                    }.accessibilityElement(children: .combine)
                    VStack(spacing: 8) {
                        Caption("ROUND SCORE")
                        Text("+\(result.score.total.formatted())").font(DesignSystem.TypeStyle.score)
                            .foregroundStyle(emphasis).lineLimit(1).minimumScaleFactor(0.5)
                        VStack(spacing: 8) {
                            breakdown("Closeness", "\(result.score.base)")
                            breakdown("Time bonus", "+\(result.score.time)")
                            if result.score.efficiency > 0 { breakdown("Efficiency", "+\(result.score.efficiency)") }
                            if result.score.factor > 1 { breakdown("Streak", "×\(result.score.factor.formatted(.number.precision(.fractionLength(1))))") }
                        }.frame(maxWidth: 256).padding(.top, 8)
                    }
                    HStack(spacing: 8) {
                        detail("REMAINING", "\(Int(result.seconds))s")
                        detail("OPERATIONS", "\(result.operations)")
                        detail("STREAK", "\(result.streak)")
                    }.padding(.top, 8)
                }.padding(.bottom, 16)
            }.scrollIndicators(.hidden)
            Button(action: model.start) {
                HStack { Text("NEXT ROUND"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 24)
            }.buttonStyle(DesignSystem.ActionStyle()).accessibilityIdentifier("nextRound")
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.celebration) { celebrate = true }
        }
    }

    private func value(_ label: String, _ number: Int) -> some View {
        VStack(spacing: 8) {
            Caption(label)
            Text(number.formatted()).font(.system(size: 36, weight: .bold, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
        }.frame(maxWidth: .infinity)
    }

    private func breakdown(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(DesignSystem.Palette.muted); Spacer(); Text(value).bold() }.font(.footnote)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(spacing: 8) {
            Text(value).font(.system(.title3, design: .rounded).weight(.bold))
            Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(DesignSystem.Palette.muted)
        }.frame(maxWidth: .infinity)
    }
}

private struct ExactParticles: View {
    let expanded: Bool
    var body: some View {
        ZStack {
            ForEach(0..<12) { index in
                Rectangle().fill(index.isMultiple(of: 3) ? DesignSystem.Palette.accent : DesignSystem.Palette.success)
                    .frame(width: 4, height: 8)
                    .offset(y: expanded ? -80 : -24)
                    .rotationEffect(.degrees(Double(index) * 30))
                    .opacity(expanded ? 0 : 1)
            }
        }.allowsHitTesting(false)
    }
}
