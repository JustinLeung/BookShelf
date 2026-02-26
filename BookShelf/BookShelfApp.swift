import SwiftUI
import SwiftData

@main
struct BookShelfApp: App {
    static let isTesting = NSClassFromString("XCTestCase") != nil

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            ReadingProgressEntry.self,
            ReadingGoal.self,
            ReadingChallenge.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isTesting
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if Self.isTesting {
                Color.clear
            } else {
                ContentView()
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
