#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class SystemInteractionFeedback: InteractionFeedbackProviding {
    private let preferences: any InteractionPreferencesManaging

    public init(preferences: any InteractionPreferencesManaging) {
        self.preferences = preferences
    }

    public func emit(_ event: InteractionFeedbackEvent) {
        guard preferences.isHapticFeedbackEnabled() else { return }

        #if canImport(UIKit)
        switch event {
        case .selectionChanged:
            UISelectionFeedbackGenerator().selectionChanged()
        case .operationSucceeded:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .chapterTransitioned:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .userActionWarning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        #endif
    }
}

@MainActor
public final class SilentInteractionFeedback: InteractionFeedbackProviding {
    public init() {}

    public func emit(_ event: InteractionFeedbackEvent) {}
}
