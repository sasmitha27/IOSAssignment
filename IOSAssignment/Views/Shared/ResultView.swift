import SwiftUI

struct ResultView: View {
    let title: String
    let mode: GameMode
    let score: Int
    let bestText: String
    let primaryActionTitle: String
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text(title)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Text("FINAL SCORE")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(score)")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Text(bestText)
                .font(.title3.bold())
                .foregroundStyle(.yellow)

            HStack(spacing: 12) {
                ShareLink(item: mode.shareText(score: score)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: "arrow.clockwise")
                        .font(.headline.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }
}
