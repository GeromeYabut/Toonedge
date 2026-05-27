import SwiftUI

@main
struct ToonEdgeAppEntry: App {
    var body: some Scene {
        WindowGroup {
            ToonEdgeRootView(
                dependencies: (try? AppDependencies.persistent()) ?? .mock()
            )
        }
    }
}
