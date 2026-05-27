import SwiftUI

public struct SettingsView: View {
    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        let settings = dependencies.settingsService.currentSettings()

        NavigationStack {
            VStack(alignment: .leading, spacing: ToonEdgeSpacing.large) {
                TEBanner(
                    title: "Settings scaffold",
                    message: "Reader preferences, storage, update checks, and app info belong here.",
                    systemImage: "gearshape"
                )

                TECard {
                    VStack(spacing: ToonEdgeSpacing.medium) {
                        TEListRow(
                            title: "Reader Canvas",
                            subtitle: settings.readerCanvas.title,
                            systemImage: "rectangle.fill"
                        )
                        TEListRow(
                            title: "Reader Fit",
                            subtitle: settings.displayMode.title,
                            systemImage: "arrow.up.left.and.arrow.down.right"
                        )
                    }
                }

                Spacer()
            }
            .padding(ToonEdgeSpacing.large)
            .navigationTitle("Settings")
            .toonEdgeScreen()
        }
    }
}
