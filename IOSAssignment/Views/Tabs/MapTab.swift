import CoreLocation
import MapKit
import SwiftUI

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
