public enum InteractionFeedbackEvent: Equatable, Sendable {
    case selectionChanged
    case operationSucceeded
    case chapterTransitioned
    case userActionWarning
}

public enum InteractionFeedbackOutcomePolicy {
    public static func cacheEvent(for result: CacheActionResult) -> InteractionFeedbackEvent? {
        switch result {
        case .retained, .removed:
            .operationSucceeded
        case .recent, .unchanged, .notFound:
            nil
        }
    }

    public static func updateEvent(
        for result: LibraryUpdateRefreshResult,
        userInitiated: Bool
    ) -> InteractionFeedbackEvent? {
        userInitiated && result.updatedCount > 0 ? .operationSucceeded : nil
    }

    public static func selectionEvent(valueChanged: Bool) -> InteractionFeedbackEvent? {
        valueChanged ? .selectionChanged : nil
    }

    public static func invalidInputEvent(validationIsVisible: Bool) -> InteractionFeedbackEvent? {
        validationIsVisible ? .userActionWarning : nil
    }
}

@MainActor
public protocol InteractionFeedbackProviding: AnyObject, Sendable {
    func emit(_ event: InteractionFeedbackEvent)
}

@MainActor
public protocol InteractionPreferencesManaging: AnyObject, Sendable {
    func isHapticFeedbackEnabled() -> Bool
    func setHapticFeedbackEnabled(_ enabled: Bool)
}
