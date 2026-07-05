import SwiftUI

struct HomeTab: View {
    @EnvironmentObject private var sessionStore: GameSessionStore
    @AppStorage("tapFrenzyHighScore") private var tapFrenzyHighScore = 0
    @AppStorage("lightItUpHighScore") private var lightItUpHighScore = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo, Color.blue.opacity(0.72), Color.black.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    NavigationLink { TapFrenzyView() } label: {
                        gameCard(
                            title: GameMode.tapFrenzy.title,
                            subtitle: "Tap fast. Build combos. Beat the clock.",
                            icon: GameMode.tapFrenzy.icon,
                            color: GameMode.tapFrenzy.color,
                            bestScore: max(tapFrenzyHighScore, sessionStore.bestScore(for: .tapFrenzy))
                        )
                    }

                    NavigationLink { LightItUpView() } label: {
                        gameCard(
                            title: GameMode.lightItUp.title,
                            subtitle: "Find the glow before it disappears.",
                            icon: GameMode.lightItUp.icon,
                            color: GameMode.lightItUp.color,
                            bestScore: max(lightItUpHighScore, sessionStore.bestScore(for: .lightItUp))
                        )
                    }

                    NavigationLink { QuizRushView() } label: {
                        gameCard(
                            title: GameMode.quizRush.title,
                            subtitle: "Answer live trivia from Open Trivia DB.",
                            icon: GameMode.quizRush.icon,
                            color: GameMode.quizRush.color,
                            bestScore: sessionStore.bestScore(for: .quizRush)
                        )
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)

            Text("ARCADE RUSH")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Choose a game mode")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.vertical, 12)
    }

    private func gameCard(title: String, subtitle: String, icon: String, color: Color, bestScore: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(color)
                .frame(width: 66, height: 66)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.leading)
                Label("Best: \(bestScore)", systemImage: "trophy.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(18)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}
