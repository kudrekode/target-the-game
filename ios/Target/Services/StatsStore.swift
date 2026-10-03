import Foundation

struct StatsStore {
    let defaults: UserDefaults
    private let key = "target.stats.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Stats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data), stats.isValid else { return Stats() }
        return stats
    }

    func save(_ stats: Stats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: key)
    }
}
