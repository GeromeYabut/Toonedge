public enum InteractionFeedbackEvent: Equatable, Sendable {
    case selectionChanged
    case operationSucceeded
    case chapterTransitioned
    case userActionWarning
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
