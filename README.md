# IOSAssignment

Arcade Rush is a SwiftUI mini-game app with three modes: Tap Frenzy, Light It Up, and Quiz Rush.

## Architecture

- `IOSAssignment/App`: app entry point and tab shell.
- `IOSAssignment/Models`: game mode and game session data models.
- `IOSAssignment/Services`: session persistence, location, and notification helpers.
- `IOSAssignment/Views/Tabs`: Home, Stats, Map, and Settings screens.
- `IOSAssignment/Views/Games`: the three game views.
- `IOSAssignment/Views/Shared`: reusable result and score UI.

## Features

- Four-tab app shell using `TabView`.
- Completed games append a `GameSession` and save JSON in `UserDefaults`.
- Stats tab shows totals, personal bests, recent sessions, and a Swift Charts bar chart.
- Result screens include `ShareLink` for score sharing.
- Map tab is ready to show completed-session pins with scores.
- Settings supports daily challenge notification scheduling and reset-all-stats confirmation.

## Known Limitations

- Xcode must include `NSLocationWhenInUseUsageDescription` in the generated Info settings before location permission can be requested. Until then, the app safely skips requesting location and map pins will not be recorded.
- Quiz Rush depends on Open Trivia DB, so it requires network access.

## Reflection

This version turns the three individual games into a structured app shell with shared session history and platform features. The main tradeoff is keeping the implementation stable while working with an Xcode project that uses generated project settings.
