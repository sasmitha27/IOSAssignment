import Charts
import CoreLocation
import MapKit
import SwiftUI
import UserNotifications

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

@MainActor
final class GameSessionStore: ObservableObject {
    @Published private(set) var sessions: [GameSession] = []

    private let storageKey = "gameSessions"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func addSession(mode: GameMode, score: Int, coordinate: CLLocationCoordinate2D?) {
        sessions.insert(GameSession(mode: mode, score: score, coordinate: coordinate), at: 0)
        save()
    }

    func reset() {
        sessions = []
        userDefaults.removeObject(forKey: storageKey)
    }

    func bestScore(for mode: GameMode) -> Int {
        sessions.filter { $0.mode == mode }.map(\.score).max() ?? 0
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            sessions = try JSONDecoder().decode([GameSession].self, from: data)
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Could not save game sessions: \(error.localizedDescription)")
        }
    }
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            currentCoordinate = coordinate
        }
    }
}

struct NotificationService {
    static let dailyChallengeIdentifier = "dailyChallenge"

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyChallenge(at date: Date) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyChallengeIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge"
        content.body = "Play a quick round and beat yesterday's score."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyChallengeIdentifier, content: content, trigger: trigger)

        try await center.add(request)
    }

    func cancelDailyChallenge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyChallengeIdentifier])
    }
}

struct ScoreBadge: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

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

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeTab() }
                .tabItem { Label("Home", systemImage: "gamecontroller") }

            NavigationStack { StatsTab() }
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            NavigationStack { MapTab() }
                .tabItem { Label("Map", systemImage: "map") }

            NavigationStack { SettingsTab() }
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

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
                ContentUnavailableView("Finish a game to build your chart.", systemImage: "chart.bar")
                    .frame(maxWidth: .infinity, minHeight: 140)
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
                ContentUnavailableView("No completed sessions yet.", systemImage: "clock")
                    .frame(maxWidth: .infinity, minHeight: 140)
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
}

struct MapTab: View {
    @EnvironmentObject private var sessionStore: GameSessionStore
    @EnvironmentObject private var locationService: LocationService
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedSession: GameSession?

    private var locatedSessions: [GameSession] {
        sessionStore.sessions.filter(\.hasLocation)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if locatedSessions.isEmpty {
                ContentUnavailableView(
                    "No Game Locations",
                    systemImage: "map",
                    description: Text("Complete a game after location permission is allowed to add pins.")
                )
            } else {
                Map(position: $position) {
                    ForEach(locatedSessions) { session in
                        if let latitude = session.latitude, let longitude = session.longitude {
                            Annotation(session.mode.title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                                Button {
                                    selectedSession = session
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: session.mode.icon)
                                            .font(.headline.bold())
                                        Text("\(session.score)")
                                            .font(.caption2.bold())
                                    }
                                    .foregroundStyle(.white)
                                    .padding(9)
                                    .background(session.mode.color, in: RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            }
        }
        .navigationTitle("Map")
        .onAppear {
            locationService.requestPermission()
        }
        .sheet(item: $selectedSession) { session in
            VStack(spacing: 14) {
                Image(systemName: session.mode.icon)
                    .font(.system(size: 46))
                    .foregroundStyle(session.mode.color)
                Text(session.mode.title)
                    .font(.title.bold())
                Text("Score \(session.score)")
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(session.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ShareLink(item: session.shareText)
                    .font(.headline)
            }
            .padding(28)
            .presentationDetents([.medium])
        }
    }
}

struct SettingsTab: View {
    @EnvironmentObject private var sessionStore: GameSessionStore
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("dailyChallengeTime") private var dailyChallengeTime = Date.now.timeIntervalSinceReferenceDate
    @State private var showResetConfirmation = false
    @State private var notificationStatusText = ""

    private let notificationService = NotificationService()

    private var challengeDate: Binding<Date> {
        Binding {
            Date(timeIntervalSinceReferenceDate: dailyChallengeTime)
        } set: { newValue in
            dailyChallengeTime = newValue.timeIntervalSinceReferenceDate
            if notificationsEnabled {
                Task { await scheduleNotification(for: newValue) }
            }
        }
    }

    var body: some View {
        Form {
            Section("Daily Challenge") {
                Toggle("Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, isEnabled in
                        Task {
                            if isEnabled {
                                await enableNotifications()
                            } else {
                                notificationService.cancelDailyChallenge()
                                notificationStatusText = "Daily reminder cancelled."
                            }
                        }
                    }

                DatePicker("Time", selection: challengeDate, displayedComponents: .hourAndMinute)

                if !notificationStatusText.isEmpty {
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Stats") {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset All Stats", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Reset all game history?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset All Stats", role: .destructive) {
                sessionStore.reset()
                UserDefaults.standard.removeObject(forKey: "tapFrenzyHighScore")
                UserDefaults.standard.removeObject(forKey: "lightItUpHighScore")
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func enableNotifications() async {
        let granted = await notificationService.requestPermission()
        guard granted else {
            notificationsEnabled = false
            notificationStatusText = "Notification permission was not granted."
            return
        }

        await scheduleNotification(for: challengeDate.wrappedValue)
    }

    private func scheduleNotification(for date: Date) async {
        do {
            try await notificationService.scheduleDailyChallenge(at: date)
            notificationStatusText = "Daily reminder scheduled."
        } catch {
            notificationsEnabled = false
            notificationStatusText = "Could not schedule the reminder."
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameSessionStore())
        .environmentObject(LocationService())
}
