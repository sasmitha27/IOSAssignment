//
//  ContentView.swift
//  IOSAssignment
//
//  Created by Sasmitha Vishvadinu on 2026-06-22.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("tapFrenzyHighScore") private var tapFrenzyHighScore = 0
    @AppStorage("lightItUpHighScore") private var lightItUpHighScore = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.indigo, Color.blue.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 58))
                                .foregroundStyle(.yellow)

                            Text("ARCADE RUSH")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Choose a game mode")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.bottom, 12)

                        NavigationLink {
                            TapFrenzyView()
                        } label: {
                            gameCard(
                                title: "Tap Frenzy",
                                subtitle: "Tap fast. Build combos. Beat the clock.",
                                icon: "hand.tap.fill",
                                color: .cyan,
                                highScore: tapFrenzyHighScore
                            )
                        }

                        NavigationLink {
                            LightItUpView()
                        } label: {
                            gameCard(
                                title: "Light It Up",
                                subtitle: "Find the glow before it disappears.",
                                icon: "lightbulb.max.fill",
                                color: .yellow,
                                highScore: lightItUpHighScore
                            )
                        }

                        NavigationLink {
                            QuizRushView()
                        } label: {
                            gameCard(
                                title: "Quiz Rush",
                                subtitle: "Answer live trivia from Open Trivia DB.",
                                icon: "questionmark.bubble.fill",
                                color: .mint,
                                badgeText: "Live API",
                                badgeIcon: "network"
                            )
                        }
                    }
                    .padding(24)
                    .padding(.top, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func gameCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        highScore: Int? = nil,
        badgeText: String? = nil,
        badgeIcon: String = "trophy.fill"
    ) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundStyle(color)
                .frame(width: 72, height: 72)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.leading)

                if let badge = highScore.map({ "Best: \($0)" }) ?? badgeText {
                    Label(badge, systemImage: badgeIcon)
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

#Preview {
    ContentView()
}
