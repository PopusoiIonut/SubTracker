import SwiftUI
import SwiftData

@main
struct SmartSubTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SubscriptionItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If schema migration fails during development, we can catch it here.
            // In a real app, you'd perform a migration, but for now we'll print the error.
            print("ModelContainer error: \(error.localizedDescription)")
            // Fallback to in-memory for this session to prevent crash if data is corrupt
            do {
                let tempConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [tempConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
