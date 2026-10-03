import SwiftUI

@MainActor
struct StatsView: View {
    let model: GameViewModel

    var body: some View {
        VStack(spacing: 24) {
            ScreenHeader(home: model.home)
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("Your numbers.").font(DesignSystem.TypeStyle.title).tracking(-1)
                        .accessibilityAddTraits(.isHeader).padding(.top, 32)
                        .accessibilityIdentifier("statsTitle")
                    VStack(alignment: .leading, spacing: 8) {
                        Caption("TOTAL SCORE")
                        Text(model.stats.totalScore.formatted()).font(DesignSystem.TypeStyle.score)
                            .foregroundStyle(DesignSystem.Palette.accent).lineLimit(1).minimumScaleFactor(0.5)
                    }
                    VStack(spacing: 0) {
                        row("Rounds played", model.stats.roundsPlayed)
                        row("Exact solutions", model.stats.exactSolutions)
                        row("Best streak", model.stats.bestStreak)
                        row("Best round score", model.stats.bestScore)
                    }
                    Caption("SAVED ON THIS IPHONE")
                }
            }.scrollIndicators(.hidden)
            Button("PLAY", action: model.start).buttonStyle(DesignSystem.ActionStyle())
        }
    }

    private func row(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(DesignSystem.Palette.line).frame(height: 1)
            HStack {
                Text(label).font(DesignSystem.TypeStyle.body)
                Spacer()
                Text(value.formatted()).font(.system(.title2, design: .rounded).weight(.bold))
            }.padding(.vertical, 24)
        }.accessibilityElement(children: .combine)
            .accessibilityIdentifier(label == "Rounds played" ? "roundsPlayedValue" : "stat\(label)")
    }
}
