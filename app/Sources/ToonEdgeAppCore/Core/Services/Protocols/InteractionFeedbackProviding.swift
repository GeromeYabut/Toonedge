public enum InteractionFeedbackEvent: Equatable, Sendable {
    case selectionChanged
    case operationSucceeded
    case chapterTransitioned
    case userActionWarning
}

@MainActor
public protocol InteractionFeedbackProviding: AnyObject {
    func emit(_ event: InteractionFeedbackEvent)
}

@MainActor
public protocol InteractionPreferencesManaging: AnyObject {
    func isHapticFeedbackEnabled() -> Bool
    func setHapticFeedbackEnabled(_ enabled: Bool)
}
