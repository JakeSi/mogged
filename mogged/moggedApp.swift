import SwiftUI
import SwiftData
import FirebaseCore

@main
struct moggedApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    @State private var gcManager = GameCenterManager()

    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: ScanResult.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
#if targetEnvironment(simulator)
            ScanViewPreview()
#else
            AppRoot()
                .preferredColorScheme(.dark)
                .environment(gcManager)
                .onAppear { gcManager.authenticate() }
#endif
        }
        .modelContainer(modelContainer)
    }
}
