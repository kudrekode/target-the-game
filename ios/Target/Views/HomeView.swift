import SwiftUI

@MainActor
struct HomeView: View {
    let model: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.extraLarge) {
            Spacer(minLength: 16)
            TargetMark().frame(width: 88, height: 88).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                Text("TARGET").font(DesignSystem.TypeStyle.brand).tracking(-3)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Rectangle().fill(DesignSystem.Palette.accent).frame(width: 48, height: 8)
                Text("Combine numbers.\nHit the target.").font(.system(.title3, design: .rounded).weight(.medium))
            }
            Spacer(minLength: 32)
            VStack(spacing: 16) {
                Button(action: model.start) {
                    HStack { Text("PLAY"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 24)
                }.buttonStyle(DesignSystem.ActionStyle()).accessibilityIdentifier("homePlay")
                Button("STATS", action: model.showStats).buttonStyle(DesignSystem.ActionStyle(primary: false))
                    .accessibilityIdentifier("homeStats")
            }
        }
    }
}

struct TargetMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(DesignSystem.Palette.ink, lineWidth: 4)
            Circle().stroke(DesignSystem.Palette.ink, lineWidth: 4).padding(20)
            Circle().fill(DesignSystem.Palette.accent).padding(36)
            Rectangle().fill(DesignSystem.Palette.paper).frame(width: 16, height: 100).rotationEffect(.degrees(45))
            Rectangle().fill(DesignSystem.Palette.accent).frame(width: 6, height: 100).rotationEffect(.degrees(45))
        }
    }
}
