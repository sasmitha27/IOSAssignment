import CoreLocation
import Foundation

@MainActor
final class GameSessionStore: ObservableObject {
    @Published private(set) var sessions: [GameSession] = []

    private let storageKey = "gameSessions"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func addSession(mode: GameMode, score: Int, coordinate: CLLocationCoordinate2D?) {
        sessions.insert(GameSession(mode: mode, score: score, coordinate: coordinate), at: 0)
        save()
    }

    func reset() {
        sessions = []
        userDefaults.removeObject(forKey: storageKey)
    }

    func bestScore(for mode: GameMode) -> Int {
        sessions.filter { $0.mode == mode }.map(\.score).max() ?? 0
    }

    func totalScore(for mode: GameMode) -> Int {
        sessions.filter { $0.mode == mode }.map(\.score).reduce(0, +)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            sessions = try JSONDecoder().decode([GameSession].self, from: data)
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Could not save game sessions: \(error.localizedDescription)")
        }
    }
}
