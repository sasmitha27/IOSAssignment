import SwiftUI

struct TapFrenzyView: View {
    private let roundDuration = 10
    private let comboWindow = 0.5

    @AppStorage("tapFrenzyHighScore") private var highScore = 0
    @EnvironmentObject private var sessionStore: GameSessionStore
    @EnvironmentObject private var locationService: LocationService

    @State private var score = 0
    @State private var remainingTime = 10
    @State private var isPlaying = true
    @State private var comboMultiplier = 1
    @State private var lastTapTime: Date?
    @State private var buttonMode: ButtonMode = .normal
    @State private var roundID = UUID()
    @State private var tapScale = 1.0

    private enum ButtonMode {
        case normal
        case bonus
        case penalty

        var color: Color {
            switch self {
            case .normal: .blue
            case .bonus: .green
            case .penalty: .gray
            }
        }

        var label: String {
            switch self {
            case .normal: "TAP"
            case .bonus: "BONUS\n+2"
            case .penalty: "TRAP\n-1"
            }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.9), Color.blue.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if isPlaying {
                gameView
                    .transition(.opacity)
            } else {
                gameOverView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .navigationTitle("Tap Frenzy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: roundID) {
            await runCountdown()
        }
    }

    private var gameView: some View {
        VStack(spacing: 24) {
            Text("TAP FRENZY")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                statCard(title: "SCORE", value: "\(score)", icon: "star.fill")
                statCard(title: "TIME", value: "\(remainingTime)s", icon: "timer")
                statCard(title: "BEST", value: "\(highScore)", icon: "trophy.fill")
            }

            if comboMultiplier > 1 {
                Text("COMBO ×\(comboMultiplier)")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("Tap quickly to build a combo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Button(action: registerTap) {
                Text(buttonMode.label)
                    .font(.system(size: buttonMode == .normal ? 38 : 29, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle()
                            .fill(buttonMode.color.gradient)
                            .shadow(color: buttonMode.color.opacity(0.65), radius: 22)
                    )
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 5)
                    }
                    .scaleEffect(tapScale)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tap button")
            .accessibilityHint(buttonMode == .penalty ? "Subtracts one point" : "Adds points")

            Spacer()

            HStack(spacing: 18) {
                legend(color: .blue, text: "+1")
                legend(color: .green, text: "+2")
                legend(color: .gray, text: "−1")
            }
        }
        .padding(24)
    }

    private var gameOverView: some View {
        ResultView(
            title: "GAME OVER",
            mode: .tapFrenzy,
            score: score,
            bestText: score == highScore && score > 0 ? "New high score!" : "High score: \(highScore)",
            primaryActionTitle: "Play Again",
            primaryAction: startNewRound
        )
    }

    private var buttonSize: CGFloat {
        let progress = CGFloat(remainingTime) / CGFloat(roundDuration)
        return 115 + (85 * progress)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }

    private func registerTap() {
        guard isPlaying else { return }

        let now = Date()
        if let lastTapTime, now.timeIntervalSince(lastTapTime) <= comboWindow {
            comboMultiplier = min(comboMultiplier + 1, 5)
        } else {
            comboMultiplier = 1
        }
        lastTapTime = now

        switch buttonMode {
        case .normal:
            score += comboMultiplier
        case .bonus:
            score += 2 * comboMultiplier
        case .penalty:
            score = max(0, score - 1)
            comboMultiplier = 1
        }

        withAnimation(.spring(duration: 0.12)) {
            tapScale = 0.88
        } completion: {
            withAnimation(.spring(duration: 0.16)) {
                tapScale = 1.0
            }
        }
    }

    @MainActor
    private func runCountdown() async {
        while isPlaying && remainingTime > 0 {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard isPlaying else { return }
            remainingTime -= 1

            if remainingTime > 0 && remainingTime.isMultiple(of: 2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    buttonMode = mode(for: remainingTime)
                }
            }
        }

        guard remainingTime == 0 else { return }
        highScore = max(highScore, score)
        sessionStore.addSession(mode: .tapFrenzy, score: score, coordinate: locationService.currentCoordinate)
        isPlaying = false
        buttonMode = .normal
    }

    private func mode(for time: Int) -> ButtonMode {
        switch time {
        case 8, 4: .bonus
        case 6, 2: .penalty
        default: .normal
        }
    }

    private func startNewRound() {
        score = 0
        remainingTime = roundDuration
        comboMultiplier = 1
        lastTapTime = nil
        buttonMode = .normal
        tapScale = 1.0
        isPlaying = true
        roundID = UUID()
    }
}

#Preview {
    NavigationStack {
        TapFrenzyView()
    }
    .environmentObject(GameSessionStore())
    .environmentObject(LocationService())
}
