import AudioToolbox
import Combine
import Foundation
import SwiftUI
import UIKit

struct QuizQuestion: Identifiable, Equatable {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let answers: [String]
}

enum QuizGenre: String, CaseIterable, Identifiable {
    case any
    case generalKnowledge
    case science
    case sports
    case history
    case entertainment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .generalKnowledge: "General"
        case .science: "Science"
        case .sports: "Sports"
        case .history: "History"
        case .entertainment: "Movies"
        }
    }

    var subtitle: String {
        switch self {
        case .any: "Mixed trivia"
        case .generalKnowledge: "Everyday facts"
        case .science: "Nature and tech"
        case .sports: "Teams and games"
        case .history: "People and eras"
        case .entertainment: "Film questions"
        }
    }

    var icon: String {
        switch self {
        case .any: "shuffle"
        case .generalKnowledge: "lightbulb.fill"
        case .science: "atom"
        case .sports: "sportscourt.fill"
        case .history: "building.columns.fill"
        case .entertainment: "movieclapper.fill"
        }
    }

    var apiCategoryID: Int? {
        switch self {
        case .any: nil
        case .generalKnowledge: 9
        case .science: 17
        case .sports: 21
        case .history: 23
        case .entertainment: 11
        }
    }
}

enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var points: Int {
        switch self {
        case .easy: 8
        case .medium: 12
        case .hard: 16
        }
    }

    var missPenalty: Int {
        switch self {
        case .easy: 2
        case .medium: 4
        case .hard: 6
        }
    }

    var color: Color {
        switch self {
        case .easy: .green
        case .medium: .orange
        case .hard: .red
        }
    }

    var apiValue: String { rawValue }
}

enum QuizMomentum: Equatable {
    case calm
    case heating
    case rush
    case danger

    var title: String {
        switch self {
        case .calm: "Build momentum"
        case .heating: "Heating up"
        case .rush: "Quiz rush"
        case .danger: "Recover fast"
        }
    }

    var icon: String {
        switch self {
        case .calm: "sparkles"
        case .heating: "flame.fill"
        case .rush: "bolt.fill"
        case .danger: "exclamationmark.triangle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .calm: [.indigo.opacity(0.95), .teal.opacity(0.8)]
        case .heating: [.blue.opacity(0.95), .mint.opacity(0.85), .yellow.opacity(0.55)]
        case .rush: [.black.opacity(0.95), .orange.opacity(0.9), .pink.opacity(0.75)]
        case .danger: [.black.opacity(0.95), .red.opacity(0.78), .purple.opacity(0.72)]
        }
    }

    var accentColor: Color {
        switch self {
        case .calm: .mint
        case .heating: .yellow
        case .rush: .orange
        case .danger: .red
        }
    }
}

private struct TriviaResponse: Decodable {
    let results: [TriviaQuestion]
}

private struct TriviaQuestion: Decodable {
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
    }

    func quizQuestion() -> QuizQuestion {
        let decodedCorrectAnswer = correctAnswer.htmlDecoded
        let decodedIncorrectAnswers = incorrectAnswers.map(\.htmlDecoded)
        let allAnswers = (decodedIncorrectAnswers + [decodedCorrectAnswer]).shuffled()

        return QuizQuestion(
            question: question.htmlDecoded,
            correctAnswer: decodedCorrectAnswer,
            answers: allAnswers
        )
    }
}

struct TriviaService {
    func fetchQuestions(genre: QuizGenre, difficulty: QuizDifficulty) async throws -> [QuizQuestion] {
        var components = URLComponents(string: "https://opentdb.com/api.php")!
        var queryItems = [
            URLQueryItem(name: "amount", value: "10"),
            URLQueryItem(name: "type", value: "multiple"),
            URLQueryItem(name: "difficulty", value: difficulty.apiValue)
        ]

        if let categoryID = genre.apiCategoryID {
            queryItems.append(URLQueryItem(name: "category", value: String(categoryID)))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let triviaResponse = try JSONDecoder().decode(TriviaResponse.self, from: data)
        return triviaResponse.results.map { $0.quizQuestion() }
    }
}

@MainActor
final class QuizRushViewModel: ObservableObject {
    enum ViewState: Equatable {
        case setup
        case loading
        case loaded
        case failed(String)
        case finished
    }

    @Published var selectedGenre: QuizGenre = .any
    @Published var selectedDifficulty: QuizDifficulty = .medium
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var wrongAnswers = 0
    @Published private(set) var state: ViewState = .setup
    @Published private(set) var feedback: AnswerFeedback?
    @Published private(set) var momentum: QuizMomentum = .calm
    @Published private(set) var milestoneMessage: String?

    private let service: TriviaService

    init() {
        self.service = TriviaService()
    }

    init(service: TriviaService) {
        self.service = service
    }

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var questionProgress: String {
        "\(min(currentIndex + 1, questions.count)) of \(questions.count)"
    }

    var accuracy: Double {
        guard currentIndex > 0 || feedback != nil else { return 1 }
        let answeredCount = currentIndex + (feedback == nil ? 0 : 1)
        guard answeredCount > 0 else { return 1 }
        return Double(answeredCount - wrongAnswers) / Double(answeredCount)
    }

    var accuracyText: String {
        "\(Int((accuracy * 100).rounded()))%"
    }

    func startGame() async {
        state = .loading
        feedback = nil
        milestoneMessage = nil
        currentIndex = 0
        score = 0
        streak = 0
        bestStreak = 0
        wrongAnswers = 0
        momentum = .calm

        do {
            questions = try await service.fetchQuestions(genre: selectedGenre, difficulty: selectedDifficulty)
            state = questions.isEmpty ? .failed("No questions matched those filters. Try another genre or difficulty.") : .loaded
        } catch {
            questions = []
            state = .failed("Could not load trivia questions. Check your connection and try again.")
        }
    }

    func returnToSetup() {
        questions = []
        feedback = nil
        milestoneMessage = nil
        state = .setup
        momentum = .calm
    }

    func submit(answer: String) {
        guard state == .loaded, feedback == nil, let currentQuestion else { return }

        let isCorrect = answer == currentQuestion.correctAnswer
        if isCorrect {
            streak += 1
            bestStreak = max(bestStreak, streak)
            let points = selectedDifficulty.points + max(0, streak - 1) * 3
            score += points
            feedback = AnswerFeedback(isCorrect: true, message: "Correct +\(points)", selectedAnswer: answer)
            playSound(.correct)
        } else {
            streak = 0
            wrongAnswers += 1
            score = max(0, score - selectedDifficulty.missPenalty)
            feedback = AnswerFeedback(isCorrect: false, message: "Wrong -\(selectedDifficulty.missPenalty)", selectedAnswer: answer)
            playSound(.wrong)
        }

        updateMomentum(isCorrect: isCorrect)

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return
            }
            advanceQuestion()
        }
    }

    private func updateMomentum(isCorrect: Bool) {
        if !isCorrect {
            milestoneMessage = wrongAnswers >= 3 ? "Pressure is rising" : "Shake it off"
            momentum = .danger
            return
        }

        if streak >= 5 {
            milestoneMessage = "Rush mode unlocked"
            momentum = .rush
        } else if streak >= 3 {
            milestoneMessage = "Streak bonus active"
            momentum = .heating
        } else if accuracy < 0.6 {
            milestoneMessage = "Climb back with the next one"
            momentum = .danger
        } else {
            milestoneMessage = "Keep the streak alive"
            momentum = .calm
        }
    }

    private func advanceQuestion() {
        feedback = nil

        if currentIndex + 1 >= questions.count {
            state = .finished
            playSound(score > 0 && accuracy >= 0.7 ? .finishStrong : .finish)
        } else {
            currentIndex += 1
        }
    }

    private func playSound(_ sound: QuizSound) {
        AudioServicesPlaySystemSound(sound.id)
        UIImpactFeedbackGenerator(style: sound.hapticStyle).impactOccurred()
    }
}

struct AnswerFeedback: Equatable {
    let isCorrect: Bool
    let message: String
    let selectedAnswer: String
}

private enum QuizSound {
    case correct
    case wrong
    case finish
    case finishStrong

    var id: SystemSoundID {
        switch self {
        case .correct: 1057
        case .wrong: 1053
        case .finish: 1104
        case .finishStrong: 1025
        }
    }

    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .correct, .finishStrong: .medium
        case .wrong: .heavy
        case .finish: .light
        }
    }
}

struct QuizRushView: View {
    @StateObject private var viewModel = QuizRushViewModel()
    @EnvironmentObject private var sessionStore: GameSessionStore
    @EnvironmentObject private var locationService: LocationService
    @State private var didRecordSession = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: viewModel.momentum.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: viewModel.momentum)

            content
        }
        .navigationTitle("Quiz Rush")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: viewModel.state) { _, newState in
            if newState == .finished {
                recordFinishedSession()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .setup:
            setupView
        case .loading:
            loadingView
        case .loaded:
            loadedView
        case .failed(let message):
            errorView(message: message)
        case .finished:
            resultsView
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "questionmark.bubble.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(.yellow)

                    Text("QUIZ RUSH")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Pick your lane and chase a streak")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                selectorSection(title: "Genre", icon: "square.grid.2x2.fill") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(QuizGenre.allCases) { genre in
                            selectionTile(
                                title: genre.title,
                                subtitle: genre.subtitle,
                                icon: genre.icon,
                                isSelected: viewModel.selectedGenre == genre,
                                accentColor: .mint
                            ) {
                                withAnimation(.spring(duration: 0.2)) {
                                    viewModel.selectedGenre = genre
                                }
                            }
                        }
                    }
                }

                selectorSection(title: "Difficulty", icon: "slider.horizontal.3") {
                    HStack(spacing: 10) {
                        ForEach(QuizDifficulty.allCases) { difficulty in
                            selectionTile(
                                title: difficulty.title,
                                subtitle: "+\(difficulty.points)",
                                icon: difficulty == .easy ? "leaf.fill" : difficulty == .medium ? "flame.fill" : "bolt.fill",
                                isSelected: viewModel.selectedDifficulty == difficulty,
                                accentColor: difficulty.color
                            ) {
                                withAnimation(.spring(duration: 0.2)) {
                                    viewModel.selectedDifficulty = difficulty
                                }
                            }
                        }
                    }
                }

                Button {
                    startGame()
                } label: {
                    Label("Start Rush", systemImage: "play.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .padding(.top, 16)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.visible)
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)

            Text("Loading \(viewModel.selectedGenre.title.lowercased()) trivia...")
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .padding(28)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 58))
                .foregroundStyle(.yellow)

            Text("Question fetch failed")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 12) {
                Button {
                    viewModel.returnToSetup()
                } label: {
                    Label("Change", systemImage: "slider.horizontal.3")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                Button {
                    startGame()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.headline.bold())
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(28)
    }

    private var loadedView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    statCard(title: "SCORE", value: "\(viewModel.score)", icon: "star.fill")
                    statCard(title: "STREAK", value: "\(viewModel.streak)", icon: "flame.fill")
                    statCard(title: "ACCURACY", value: viewModel.accuracyText, icon: "scope")
                }

                VStack(spacing: 8) {
                    HStack {
                        Label(viewModel.momentum.title, systemImage: viewModel.momentum.icon)
                            .font(.headline.bold())
                            .foregroundStyle(viewModel.momentum.accentColor)

                        Spacer()

                        Text(viewModel.questionProgress)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(max(viewModel.questions.count, 1)))
                        .tint(viewModel.momentum.accentColor)
                }

                if let message = viewModel.milestoneMessage {
                    Text(message)
                        .font(.subheadline.bold())
                        .foregroundStyle(.black.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(viewModel.momentum.accentColor, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                if let question = viewModel.currentQuestion {
                    VStack(spacing: 18) {
                        Text(question.question)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.72)
                            .padding(20)
                            .frame(maxWidth: .infinity, minHeight: 152)
                            .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(viewModel.momentum.accentColor.opacity(0.45), lineWidth: 1.5)
                            }

                        VStack(spacing: 12) {
                            ForEach(question.answers, id: \.self) { answer in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        viewModel.submit(answer: answer)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: answerIcon(answer: answer))
                                            .font(.headline.bold())
                                            .frame(width: 24)
                                        Text(answer)
                                            .font(.headline.bold())
                                            .multilineTextAlignment(.leading)
                                            .minimumScaleFactor(0.7)
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .padding(.horizontal, 14)
                                    .background(answerBackground(answer: answer), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.feedback != nil)
                            }
                        }
                    }
                }

                Text(viewModel.feedback?.message ?? "Choose the correct answer")
                    .font(.headline.bold())
                    .foregroundStyle(viewModel.feedback?.isCorrect == false ? .red : viewModel.momentum.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.22), in: Capsule())
                    .offset(x: viewModel.feedback?.isCorrect == false ? -6 : 0)
                    .animation(.default.repeatCount(viewModel.feedback?.isCorrect == false ? 3 : 0, autoreverses: true), value: viewModel.feedback)
            }
            .padding(20)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.visible)
    }

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: viewModel.accuracy >= 0.7 ? "checkmark.seal.fill" : "flag.checkered")
                    .font(.system(size: 64))
                    .foregroundStyle(viewModel.accuracy >= 0.7 ? .yellow : .white.opacity(0.85))

                Text(viewModel.accuracy >= 0.7 ? "STRONG RUN" : "ROUND COMPLETE")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("FINAL SCORE")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(viewModel.score)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    resultPill(title: "Best streak", value: "\(viewModel.bestStreak)", icon: "flame.fill")
                    resultPill(title: "Accuracy", value: viewModel.accuracyText, icon: "scope")
                }

                HStack(spacing: 12) {
                    ShareLink(item: GameMode.quizRush.shareText(score: viewModel.score)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.16), in: Capsule())
                    }

                    Button {
                        viewModel.returnToSetup()
                    } label: {
                        Label("Change", systemImage: "slider.horizontal.3")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.16), in: Capsule())
                    }

                    Button {
                        startGame()
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                            .font(.headline.bold())
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .background(.white, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(30)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.visible)
    }

    private func startGame() {
        didRecordSession = false
        Task {
            await viewModel.startGame()
        }
    }

    private func recordFinishedSession() {
        guard !didRecordSession else { return }
        didRecordSession = true
        sessionStore.addSession(mode: .quizRush, score: viewModel.score, coordinate: locationService.currentCoordinate)
    }

    private func selectorSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline.bold())
                .foregroundStyle(.white)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionTile(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? .black.opacity(0.72) : accentColor)

                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(isSelected ? .black.opacity(0.82) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .black.opacity(0.56) : .white.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 98)
            .padding(.horizontal, 8)
            .background(isSelected ? accentColor : .white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .white.opacity(0.55) : .white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultPill(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private func answerBackground(answer: String) -> Color {
        guard let feedback = viewModel.feedback,
              let question = viewModel.currentQuestion else {
            return .white.opacity(0.16)
        }

        if answer == question.correctAnswer {
            return .green.opacity(0.88)
        }

        if !feedback.isCorrect && answer == feedback.selectedAnswer {
            return .red.opacity(0.72)
        }

        return .white.opacity(0.16)
    }

    private func answerIcon(answer: String) -> String {
        guard let feedback = viewModel.feedback,
              let question = viewModel.currentQuestion else {
            return "circle"
        }

        if answer == question.correctAnswer {
            return "checkmark.circle.fill"
        }

        if !feedback.isCorrect && answer == feedback.selectedAnswer {
            return "xmark.circle.fill"
        }

        return "circle"
    }
}

private extension String {
    var htmlDecoded: String {
        var output = ""
        var currentIndex = startIndex

        while currentIndex < endIndex {
            if self[currentIndex] == "&",
               let semicolonIndex = self[currentIndex...].firstIndex(of: ";") {
                let entity = String(self[index(after: currentIndex)..<semicolonIndex])
                if let decodedEntity = decodeHTMLEntity(entity) {
                    output.append(decodedEntity)
                    currentIndex = index(after: semicolonIndex)
                    continue
                }
            }

            output.append(self[currentIndex])
            currentIndex = index(after: currentIndex)
        }

        return output
    }

    private func decodeHTMLEntity(_ entity: String) -> Character? {
        switch entity {
        case "amp": return "&"
        case "quot": return "\""
        case "apos", "#039": return "'"
        case "lt": return "<"
        case "gt": return ">"
        default:
            if entity.hasPrefix("#x"),
               let value = UInt32(entity.dropFirst(2), radix: 16),
               let scalar = UnicodeScalar(value) {
                return Character(scalar)
            }

            if entity.hasPrefix("#"),
               let value = UInt32(entity.dropFirst()),
               let scalar = UnicodeScalar(value) {
                return Character(scalar)
            }

            return nil
        }
    }
}

#Preview {
    NavigationStack {
        QuizRushView()
    }
    .environmentObject(GameSessionStore())
    .environmentObject(LocationService())
}
