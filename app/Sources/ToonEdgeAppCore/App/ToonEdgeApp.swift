import SwiftUI

public struct ToonEdgeApp: App {
    private let dependencies: AppDependencies

    public init() {
        self.dependencies = (try? AppDependencies.persistent()) ?? .mock()
    }

    public init(dependencies: AppDependencies = .mock()) {
        self.dependencies = dependencies
    }

    public var body: some Scene {
        WindowGroup {
            ToonEdgeRootView(dependencies: dependencies)
        }
    }
}

public struct ToonEdgeRootView: View {
    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .mock()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        AppShellView(dependencies: dependencies)
    }
}
