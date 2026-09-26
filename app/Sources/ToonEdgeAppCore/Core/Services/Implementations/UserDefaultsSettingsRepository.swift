import Foundation

public final class UserDefaultsSettingsRepository: SettingsManaging, @unchecked Sendable {
    public enum Key {
        public static let readerCanvas = "reader-settings.canvas"
        public static let displayMode = "reader-settings.display-mode"
        public static let pageSpacing = "reader-settings.page-spacing"
        public static let brightnessAid = "reader-settings.brightness-aid"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func currentSettings() -> ReaderSettings {
        lock.withLock {
            let defaults = ReaderSettings.default
            let canvas = userDefaults.string(forKey: Key.readerCanvas)
                .flatMap(ReaderCanvas.init(rawValue:)) ?? defaults.readerCanvas
            let displayMode = userDefaults.string(forKey: Key.displayMode)
                .flatMap(ReaderDisplayMode.init(rawValue:)) ?? defaults.displayMode
            let pageSpacing = userDefaults.object(forKey: Key.pageSpacing) == nil
                ? defaults.isPageSpacingEnabled
                : userDefaults.bool(forKey: Key.pageSpacing)
            let storedBrightness = userDefaults.object(forKey: Key.brightnessAid) == nil
                ? defaults.brightnessAid
                : userDefaults.double(forKey: Key.brightnessAid)
            let brightness = (0...0.75).contains(storedBrightness)
                ? storedBrightness
                : defaults.brightnessAid

            return ReaderSettings(
                readerCanvas: canvas,
                displayMode: displayMode,
                isPageSpacingEnabled: pageSpacing,
                brightnessAid: brightness
            )
        }
    }

    public func updateSettings(_ settings: ReaderSettings) async {
        lock.withLock {
            userDefaults.set(settings.readerCanvas.rawValue, forKey: Key.readerCanvas)
            userDefaults.set(settings.displayMode.rawValue, forKey: Key.displayMode)
            userDefaults.set(settings.isPageSpacingEnabled, forKey: Key.pageSpacing)
            userDefaults.set(settings.brightnessAid.clamped(to: 0...0.75), forKey: Key.brightnessAid)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
