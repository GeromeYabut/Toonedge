import Foundation

@MainActor
public final class UserDefaultsInteractionPreferences: InteractionPreferencesManaging {
    public static let hapticFeedbackEnabledKey = "toonedge.interaction.hapticFeedbackEnabled"

    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            defaults = suiteDefaults
        } else {
            defaults = .standard
        }
    }

    public func isHapticFeedbackEnabled() -> Bool {
        guard let enabled = defaults.object(forKey: Self.hapticFeedbackEnabledKey) as? Bool else {
            return true
        }
        return enabled
    }

    public func setHapticFeedbackEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.hapticFeedbackEnabledKey)
    }
}
