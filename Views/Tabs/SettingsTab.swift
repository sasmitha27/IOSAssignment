import SwiftUI

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
