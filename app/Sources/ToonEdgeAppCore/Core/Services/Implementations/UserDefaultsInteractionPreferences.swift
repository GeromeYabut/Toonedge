import Foundation
import CoreFoundation

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
        guard let storedValue = defaults.object(forKey: Self.hapticFeedbackEnabledKey),
              CFGetTypeID(storedValue as CFTypeRef) == CFBooleanGetTypeID() else {
            return true
        }
        return defaults.bool(forKey: Self.hapticFeedbackEnabledKey)
    }

    public func setHapticFeedbackEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.hapticFeedbackEnabledKey)
    }
}
