import Charts
import SwiftUI

struct StatsTab: View {
    @EnvironmentObject private var sessionStore: GameSessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryGrid
                chartSection
                recentGames
            }
            .padding(16)
        }
        .navigationTitle("Stats")
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ScoreBadge(title: "Games", value: "\(sessionStore.sessions.count)", icon: "gamecontroller.fill", color: .blue)
            ScoreBadge(title: "Total", value: "\(sessionStore.sessions.map(\.score).reduce(0, +))", icon: "sum", color: .green)

            ForEach(GameMode.allCases) { mode in
                ScoreBadge(title: mode.title, value: "Best \(sessionStore.bestScore(for: mode))", icon: mode.icon, color: mode.color)
            }
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scores by Mode")
                .font(.headline.bold())

            if sessionStore.sessions.isEmpty {
                emptyState("Finish a game to build your chart.", icon: "chart.bar")
            } else {
                Chart(sessionStore.sessions) { session in
                    BarMark(
                        x: .value("Mode", session.mode.title),
                        y: .value("Score", session.score)
                    )
                    .foregroundStyle(by: .value("Mode", session.mode.title))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 220)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var recentGames: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Games")
                .font(.headline.bold())

            if sessionStore.sessions.isEmpty {
                emptyState("No completed sessions yet.", icon: "clock")
            } else {
                ForEach(sessionStore.sessions.prefix(8)) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.mode.icon)
                            .foregroundStyle(session.mode.color)
                            .frame(width: 34, height: 34)
                            .background(session.mode.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.mode.title)
                                .font(.headline)
                            Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(session.score)")
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyState(_ text: String, icon: String) -> some View {
        ContentUnavailableView(text, systemImage: icon)
            .frame(maxWidth: .infinity, minHeight: 140)
    }
}
