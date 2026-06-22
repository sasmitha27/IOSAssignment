import SwiftUI

struct LightCard: Identifiable {
    let id = UUID()
    var isLit = false
}

struct LightItUpView: View {
    private let roundDuration = 60

    @AppStorage("lightItUpHighScore") private var highScore = 0

    @State private var score = 0
    @State private var remainingTime = 60
    @State private var cards = LightItUpLevel.one.makeCards()
    @State private var isPlaying = true
    @State private var roundID = UUID()
    @State private var level = LightItUpLevel.one
    @State private var feedbackText = "Tap the glowing card"
    @State private var feedbackColor = Color.white
    @State private var showLevelFlash = false

    var body: some View {
        ZStack {
            background

            if isPlaying {
                gameView
                    .transition(.opacity)
            } else {
                gameOverView
                    .transition(.scale.combined(with: .opacity))
            }

            if showLevelFlash {
                levelFlash
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .navigationTitle("Light It Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: roundID) {
            await runRoundTimer()
        }
        .task(id: roundID) {
            await runLightCycle()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.black, level.glowColor.opacity(0.45), Color.indigo.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: level)
    }

    private var gameView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                statCard(title: "SCORE", value: "\(score)", icon: "star.fill")
                statCard(title: "TIME", value: "\(remainingTime)s", icon: "timer")
                statCard(title: "BEST", value: "\(highScore)", icon: "trophy.fill")
            }

            HStack {
                Label("LEVEL \(level.rawValue)", systemImage: "bolt.fill")
                    .font(.headline.bold())
                    .foregroundStyle(level.glowColor)

                Spacer()

                Text(level.description)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(value: Double(roundDuration - remainingTime), total: Double(roundDuration))
                .tint(level.glowColor)

            Spacer(minLength: 4)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(cards.indices, id: \.self) { index in
                    Button {
                        handleTap(at: index)
                    } label: {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(cards[index].isLit ? level.glowColor.gradient : Color.white.opacity(0.12).gradient)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: cards[index].isLit ? "lightbulb.max.fill" : "circle.fill")
                                    .font(.system(size: cardIconSize, weight: .bold))
                                    .foregroundStyle(cards[index].isLit ? .white : .white.opacity(0.12))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(
                                        cards[index].isLit ? Color.white : Color.white.opacity(0.12),
                                        lineWidth: cards[index].isLit ? 4 : 1
                                    )
                            }
                            .shadow(
                                color: cards[index].isLit ? level.glowColor.opacity(0.9) : .clear,
                                radius: cards[index].isLit ? 22 : 0
                            )
                            .scaleEffect(cards[index].isLit ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cards[index].isLit ? "Lit card" : "Dim card")
                }
            }
            .animation(.spring(duration: 0.25), value: cards.map(\.isLit))

            Spacer(minLength: 4)

            Text(feedbackText)
                .font(.headline.bold())
                .foregroundStyle(feedbackColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.black.opacity(0.2), in: Capsule())
        }
        .padding(20)
    }

    private var gameOverView: some View {
        VStack(spacing: 22) {
            Image(systemName: score >= highScore && score > 0 ? "trophy.fill" : "lightbulb.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("TIME'S UP")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("FINAL SCORE")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(score)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(score == highScore && score > 0 ? "New high score!" : "High score: \(highScore)")
                .font(.title3.bold())
                .foregroundStyle(.yellow)

            Button(action: startNewRound) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.title3.bold())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }

    private var levelFlash: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 52))
            Text("LEVEL \(level.rawValue)")
                .font(.system(size: 40, weight: .black, design: .rounded))
            Text(level.description)
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(30)
        .background(level.glowColor.opacity(0.92), in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: level.glowColor, radius: 30)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: level.columnCount)
    }

    private var cardIconSize: CGFloat {
        level.columnCount == 1 ? 44 : 32
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
    }

    private func handleTap(at index: Int) {
        guard isPlaying, cards.indices.contains(index) else { return }

        if cards[index].isLit {
            score += 1
            cards[index].isLit = false
            feedbackText = "+1 Great tap!"
            feedbackColor = level.glowColor
        } else {
            applyPenalty(message: "Wrong card! −1")
        }
    }

    @MainActor
    private func runRoundTimer() async {
        while isPlaying && remainingTime > 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard isPlaying else { return }
            remainingTime -= 1

            let nextLevel = LightItUpLevel.level(elapsedSeconds: roundDuration - remainingTime)
            if nextLevel != level && remainingTime > 0 {
                level = nextLevel
                cards = nextLevel.makeCards()
                feedbackText = "Faster now!"
                feedbackColor = nextLevel.glowColor
                await showLevelUpFlash()
            }
        }

        guard remainingTime == 0 else { return }
        cards.indices.forEach { cards[$0].isLit = false }
        highScore = max(highScore, score)
        isPlaying = false
    }

    @MainActor
    private func runLightCycle() async {
        lightRandomCards()

        while isPlaying && remainingTime > 0 {
            let interval = level.litWindow
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }

            guard isPlaying, remainingTime > 0 else { return }

            if cards.contains(where: \.isLit) {
                applyPenalty(message: "Missed it! −1")
            }
            lightRandomCards()
        }
    }

    private func lightRandomCards() {
        cards.indices.forEach { cards[$0].isLit = false }
        let litIndices = cards.indices.shuffled().prefix(level.litCardCount)
        for index in litIndices {
            cards[index].isLit = true
        }
    }

    private func applyPenalty(message: String) {
        score = max(0, score - 1)
        feedbackText = message
        feedbackColor = .red
    }

    @MainActor
    private func showLevelUpFlash() async {
        withAnimation(.spring(duration: 0.25)) {
            showLevelFlash = true
        }

        do {
            try await Task.sleep(for: .seconds(0.7))
        } catch {
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            showLevelFlash = false
        }
    }

    private func startNewRound() {
        score = 0
        remainingTime = roundDuration
        level = .one
        cards = LightItUpLevel.one.makeCards()
        feedbackText = "Tap the glowing card"
        feedbackColor = .white
        showLevelFlash = false
        isPlaying = true
        roundID = UUID()
    }
}

private enum LightItUpLevel: Int, Equatable {
    case one = 1
    case two
    case three
    case four

    var cardCount: Int {
        switch self {
        case .one: 3
        case .two: 4
        case .three: 6
        case .four: 9
        }
    }

    var columnCount: Int {
        switch self {
        case .one: 3
        case .two: 2
        case .three, .four: 3
        }
    }

    var litWindow: Double {
        switch self {
        case .one: 1.5
        case .two: 1.2
        case .three: 1.0
        case .four: 0.8
        }
    }

    var litCardCount: Int {
        self == .four ? 2 : 1
    }

    var glowColor: Color {
        switch self {
        case .one: .cyan
        case .two: .green
        case .three: .orange
        case .four: .pink
        }
    }

    var description: String {
        "\(cardCount) cards • \(litWindow.formatted(.number.precision(.fractionLength(1))))s"
    }

    func makeCards() -> [LightCard] {
        Array(repeating: LightCard(), count: cardCount)
    }

    static func level(elapsedSeconds: Int) -> LightItUpLevel {
        switch elapsedSeconds {
        case 0..<15: .one
        case 15..<30: .two
        case 30..<45: .three
        default: .four
        }
    }
}

#Preview {
    NavigationStack {
        LightItUpView()
    }
}
