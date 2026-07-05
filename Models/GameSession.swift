import Foundation
import CoreLocation

struct GameSession: Identifiable, Codable, Equatable {
    let id: UUID
    let mode: GameMode
    let score: Int
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?

    init(
        id: UUID = UUID(),
        mode: GameMode,
        score: Int,
        timestamp: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.mode = mode
        self.score = score
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }

    init(mode: GameMode, score: Int, coordinate: CLLocationCoordinate2D?) {
        self.init(
            mode: mode,
            score: score,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var shareText: String {
        mode.shareText(score: score)
    }
}
