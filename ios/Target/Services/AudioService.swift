import AVFoundation

@MainActor
final class AudioService {
    enum Sound: String, CaseIterable { case tile, merge, invalid, exact, countdown }
    private var players: [Sound: AVAudioPlayer] = [:]
    private var prepared = false

    func play(_ sound: Sound) {
        if !prepared { prepare() }
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    func stop() { players.values.forEach { $0.stop() } }

    private func prepare() {
        prepared = true
        // Respect the silent switch and other audio. No background audio entitlement.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.volume = sound == .countdown ? 0.22 : 0.45
            player.prepareToPlay()
            players[sound] = player
        }
    }
}
