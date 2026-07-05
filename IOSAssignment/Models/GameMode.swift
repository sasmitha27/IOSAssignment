import SwiftUI

/// The playable modes used by session history, stats, map pins, and sharing.
enum GameMode: String, CaseIterable, Codable, Identifiable {
    case tapFrenzy
    case lightItUp
    case quizRush

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tapFrenzy: "Tap Frenzy"
        case .lightItUp: "Light It Up"
        case .quizRush: "Quiz Rush"
        }
    }

    var icon: String {
        switch self {
        case .tapFrenzy: "hand.tap.fill"
        case .lightItUp: "lightbulb.max.fill"
        case .quizRush: "questionmark.bubble.fill"
        }
    }

    var color: Color {
        switch self {
        case .tapFrenzy: .cyan
        case .lightItUp: .yellow
        case .quizRush: .mint
        }
    }

    func shareText(score: Int) -> String {
        "I just scored \(score) on \(title) - beat that"
    }
}
