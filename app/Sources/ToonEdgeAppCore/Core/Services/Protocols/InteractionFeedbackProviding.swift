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

@MainActor
public final class InteractionFeedbackOutcomeReporter {
    private let feedback: any InteractionFeedbackProviding

    public init(feedback: any InteractionFeedbackProviding) {
        self.feedback = feedback
    }

    public func reportUserInitiatedUpdate(_ result: LibraryUpdateRefreshResult) {
        emit(InteractionFeedbackOutcomePolicy.updateEvent(for: result, userInitiated: true))
    }

    public func reportBackgroundUpdate(_ result: LibraryUpdateRefreshResult) {
        emit(InteractionFeedbackOutcomePolicy.updateEvent(for: result, userInitiated: false))
    }

    public func reportSelectionChange<Value: Equatable>(from previous: Value, to current: Value) {
        emit(InteractionFeedbackOutcomePolicy.selectionEvent(valueChanged: previous != current))
    }

    public func reportInvalidInput(validationIsVisible: Bool) {
        emit(InteractionFeedbackOutcomePolicy.invalidInputEvent(validationIsVisible: validationIsVisible))
    }

    private func emit(_ event: InteractionFeedbackEvent?) {
        guard let event else { return }
        feedback.emit(event)
    }
}
