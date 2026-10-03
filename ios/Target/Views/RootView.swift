import SwiftUI

@MainActor
struct RootView: View {
    @State private var model = GameViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DesignSystem.Palette.paper.ignoresSafeArea()
            Group {
                switch model.screen {
                case .home: HomeView(model: model)
                case .game: GameView(model: model)
                case .result:
                    if let result = model.result { ResultView(model: model, result: result) }
                case .stats: StatsView(model: model)
                }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, DesignSystem.Space.large)
            .padding(.vertical, DesignSystem.Space.medium)
        }
        .foregroundStyle(DesignSystem.Palette.ink)
        .tint(DesignSystem.Palette.accent)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in model.sceneChanged(active: phase == .active) }
        .onChange(of: reduceMotion, initial: true) { _, value in model.reduceMotion = value }
        .task {
            model.sceneChanged(active: scenePhase == .active)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { break }
                if scenePhase == .active { model.tick() }
            }
        }
    }
}

@MainActor
struct ScreenHeader: View {
    let home: () -> Void
    var body: some View {
        HStack {
            Text("TARGET").font(.system(.headline, design: .rounded).weight(.black)).tracking(2)
            Spacer()
            Button(action: home) { Image(systemName: "house").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")
                .accessibilityIdentifier("homeButton")
        }
    }
}

struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(DesignSystem.TypeStyle.label).tracking(1.5).foregroundStyle(DesignSystem.Palette.muted)
    }
}
