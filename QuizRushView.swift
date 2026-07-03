import Combine
import Foundation
import SwiftUI

struct QuizQuestion: Identifiable, Equatable {
    let id = UUID()
    let question: String
    let correctAnswer: String
    let answers: [String]
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
    private let url = URL(string: "https://opentdb.com/api.php?amount=10&type=multiple")!

    func fetchQuestions() async throws -> [QuizQuestion] {
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
        case loading
        case loaded
        case failed(String)
        case finished
    }

    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var state: ViewState = .loading
    @Published private(set) var feedback: AnswerFeedback?

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

    func load() async {
        state = .loading
        feedback = nil
        currentIndex = 0
        score = 0
        streak = 0
        bestStreak = 0

        do {
            questions = try await service.fetchQuestions()
            state = questions.isEmpty ? .failed("No questions were returned. Please try again.") : .loaded
        } catch {
            questions = []
            state = .failed("Could not load trivia questions. Check your connection and try again.")
        }
    }

    func submit(answer: String) {
        guard state == .loaded, let currentQuestion else { return }

        let isCorrect = answer == currentQuestion.correctAnswer
        if isCorrect {
            streak += 1
            bestStreak = max(bestStreak, streak)
            score += 10 + max(0, streak - 1) * 2
            feedback = AnswerFeedback(isCorrect: true, message: "Correct +\(10 + max(0, streak - 1) * 2)", selectedAnswer: answer)
        } else {
            streak = 0
            score = max(0, score - 3)
            feedback = AnswerFeedback(isCorrect: false, message: "Wrong -3", selectedAnswer: answer)
        }

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch {
                return
            }
            advanceQuestion()
        }
    }

    private func advanceQuestion() {
        feedback = nil

        if currentIndex + 1 >= questions.count {
            state = .finished
        } else {
            currentIndex += 1
        }
    }
}

struct AnswerFeedback: Equatable {
    let isCorrect: Bool
    let message: String
    let selectedAnswer: String
}

struct QuizRushView: View {
    @StateObject private var viewModel = QuizRushViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.95), Color.teal.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .navigationTitle("Quiz Rush")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if viewModel.questions.isEmpty {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
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

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)

            Text("Loading trivia...")
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

            Button {
                Task {
                    await viewModel.load()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline.bold())
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(28)
    }

    private var loadedView: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                statCard(title: "SCORE", value: "\(viewModel.score)", icon: "star.fill")
                statCard(title: "STREAK", value: "\(viewModel.streak)", icon: "flame.fill")
                statCard(title: "QUESTION", value: viewModel.questionProgress, icon: "number")
            }

            ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(max(viewModel.questions.count, 1)))
                .tint(.yellow)

            Spacer(minLength: 4)

            if let question = viewModel.currentQuestion {
                VStack(spacing: 18) {
                    Text(question.question)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))

                    VStack(spacing: 12) {
                        ForEach(question.answers, id: \.self) { answer in
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    viewModel.submit(answer: answer)
                                }
                            } label: {
                                Text(answer)
                                    .font(.headline.bold())
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .padding(.horizontal, 14)
                                    .background(answerBackground(answer: answer), in: RoundedRectangle(cornerRadius: 18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.feedback != nil)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            Text(viewModel.feedback?.message ?? "Choose the correct answer")
                .font(.headline.bold())
                .foregroundStyle(viewModel.feedback?.isCorrect == false ? .red : .yellow)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.black.opacity(0.18), in: Capsule())
                .offset(x: viewModel.feedback?.isCorrect == false ? -6 : 0)
                .animation(.default.repeatCount(viewModel.feedback?.isCorrect == false ? 3 : 0, autoreverses: true), value: viewModel.feedback)
        }
        .padding(20)
    }

    private var resultsView: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("ROUND COMPLETE")
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

            Text("Best streak: \(viewModel.bestStreak)")
                .font(.title3.bold())
                .foregroundStyle(.yellow)

            Button {
                Task {
                    await viewModel.load()
                }
            } label: {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.title3.bold())
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(30)
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
}
