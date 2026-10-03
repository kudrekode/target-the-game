import SwiftUI

@MainActor
struct GameView: View {
    let model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 660
            ScrollView {
                VStack(spacing: compact ? 8 : 16) {
                    header
                    target(compact: compact)
                    TimerView(seconds: model.seconds)
                    expression.frame(minHeight: 32)
                    NumberBoard(model: model).frame(height: compact ? 152 : 192)
                    HStack(spacing: 8) {
                        ForEach(Operation.allCases, id: \.self) { operation in
                            Button(operation.rawValue) { model.selectOperation(operation) }
                                .buttonStyle(DesignSystem.TileStyle(selected: model.operation == operation, operatorKey: true))
                                .disabled(model.firstID == nil || model.busy || !model.active)
                                .accessibilityLabel(operation.name)
                                .accessibilityAddTraits(model.operation == operation ? .isSelected : [])
                        }
                    }.frame(height: compact ? 56 : 64)
                    Text(model.message).font(.system(.footnote, design: .rounded))
                        .foregroundStyle(DesignSystem.Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("gameMessage")
                    HStack(spacing: 16) {
                        Button(action: { withAnimation(reduceMotion ? nil : DesignSystem.Motion.spring) { model.undo() } }) {
                            Label("UNDO", systemImage: "arrow.uturn.backward")
                        }.disabled(!model.canUndo).accessibilityIdentifier("undoButton")
                        Button(action: model.hint) { Label("HINT", systemImage: "lightbulb") }
                            .disabled(model.busy || !model.active)
                            .accessibilityIdentifier("hintButton")
                    }.buttonStyle(DesignSystem.ActionStyle(primary: false))
                }
                .frame(minHeight: geometry.size.height, alignment: .center)
            }.scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Text("TARGET").font(.system(.headline, design: .rounded).weight(.black)).tracking(2)
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Rectangle().fill(index < (model.game?.round.difficulty.intensity ?? 1) ? DesignSystem.Palette.accent : DesignSystem.Palette.line)
                        .frame(width: 4, height: CGFloat(8 + index * 4))
                }
            }.accessibilityLabel("Challenge level \(model.game?.round.difficulty.intensity ?? 1) of 3")
            Text("STREAK \(model.streak)").font(DesignSystem.TypeStyle.label).padding(.leading, 8)
        }.frame(minHeight: 32)
    }

    private func target(compact: Bool) -> some View {
        VStack(spacing: 0) {
            Caption("TARGET")
            Text("\(model.game?.round.target ?? 0)")
                .font(compact ? .system(size: 88, weight: .heavy, design: .rounded) : DesignSystem.TypeStyle.target)
                .tracking(-4).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(model.result?.exact == true ? DesignSystem.Palette.success : DesignSystem.Palette.ink)
                .accessibilityLabel("Target \(model.game?.round.target ?? 0)")
            HStack {
                if let game = model.game {
                    Text("Closest \(game.closest.value) · off \(abs(game.closest.value - game.round.target))")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(DesignSystem.Palette.muted)
                }
                Spacer(minLength: 8)
                Text("SCORE \(model.liveScore)").font(DesignSystem.TypeStyle.label)
            }
            Rectangle().fill(DesignSystem.Palette.line).frame(height: 1).padding(.top, 8)
        }
    }

    private var expression: some View {
        Group {
            if let first = model.first {
                HStack(spacing: 8) {
                    Text("\(first.value) \(model.operation?.rawValue ?? "?")").font(.system(.title3, design: .rounded).weight(.bold))
                    Text(model.operation == nil ? "Choose an operator" : "Choose a number").font(.caption)
                }
            } else { Caption("BUILD YOUR WAY TO THE TARGET") }
        }
    }
}

@MainActor
private struct NumberBoard: View {
    let model: GameViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 8
            let width = (geometry.size.width - 2 * gap) / 3
            let height = (geometry.size.height - gap - 4) / 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<6) { slot in
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.key)
                        .strokeBorder(DesignSystem.Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: width, height: height)
                        .offset(x: CGFloat(slot % 3) * (width + gap), y: CGFloat(slot / 3) * (height + gap))
                        .accessibilityHidden(true)
                }
                ForEach(model.tiles) { tile in
                    let destination = destinationSlot(tile)
                    Button { model.selectTile(tile.id) } label: {
                        Text("\(tile.value)").lineLimit(1).minimumScaleFactor(0.2).padding(.horizontal, 8)
                    }
                    .buttonStyle(DesignSystem.TileStyle(selected: model.firstID == tile.id,
                                                       result: model.newTileID == tile.id))
                    .frame(width: width, height: height)
                    .scaleEffect(merging(tile) ? 0.55 : 1)
                    .opacity(merging(tile) ? 0 : 1)
                    .modifier(ShakeEffect(progress: reduceMotion || !model.rejectedIDs.contains(tile.id) ? 0 : CGFloat(model.rejection)))
                    .offset(x: CGFloat(destination % 3) * (width + gap), y: CGFloat(destination / 3) * (height + gap))
                    .zIndex(model.merge?.first.id == tile.id || model.merge?.second.id == tile.id ? 1 : 0)
                    .transition(reduceMotion ? .identity : .scale(scale: 0.55).combined(with: .opacity))
                    .disabled(model.busy || !model.active)
                    .accessibilityLabel("Number \(tile.value)")
                    .accessibilityAddTraits(model.firstID == tile.id ? .isSelected : [])
                    .accessibilityIdentifier("numberSlot\(tile.slot)")
                }
            }
        }
    }

    private func merging(_ tile: Tile) -> Bool {
        guard let merge = model.merge, merge.converged else { return false }
        return tile.id == merge.first.id || tile.id == merge.second.id
    }

    private func destinationSlot(_ tile: Tile) -> Int {
        guard merging(tile), let merge = model.merge else { return tile.slot }
        return merge.first.slot
    }
}

private struct TimerView: View {
    let seconds: TimeInterval
    private var colour: Color {
        seconds <= 3 ? DesignSystem.Palette.accent : seconds <= 10 ? DesignSystem.Palette.accent : DesignSystem.Palette.ink
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .leading) {
                Rectangle().fill(DesignSystem.Palette.line).frame(height: 4)
                GeometryReader { geometry in
                    Rectangle().fill(colour).frame(width: geometry.size.width * min(1, seconds / Balance.seconds), height: 4)
                }.frame(height: 4)
            }.accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if seconds <= 3 { Image(systemName: "exclamationmark").font(.caption.bold()) }
                Text("\(Int(ceil(seconds)))").font(.system(size: 28, weight: seconds <= 3 ? .black : .bold, design: .monospaced))
                Text("s").font(.caption)
            }.foregroundStyle(colour).monospacedDigit().frame(minWidth: 64, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("roundTimer")
        .accessibilityLabel("Time remaining")
        .accessibilityValue("\(Int(ceil(seconds))) seconds")
    }
}
