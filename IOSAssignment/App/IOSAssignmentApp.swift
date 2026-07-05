import SwiftUI

@main
struct IOSAssignmentApp: App {
    @StateObject private var sessionStore = GameSessionStore()
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(locationService)
                .task {
                    locationService.requestPermission()
                }
        }
    }
}
