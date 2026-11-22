import Foundation
import SnowCore

/// User preferences, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()
    static let didChange = Notification.Name("SnowmanSettingsDidChange")

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "amount": SnowAmount.normal.rawValue,
            "paused": false,
            "accumulateOnWindows": true,
            "soundOn": true,
        ])
    }

    var amount: SnowAmount {
        get { SnowAmount(rawValue: defaults.string(forKey: "amount") ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: "amount"); changed() }
    }

    var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        set { defaults.set(newValue, forKey: "paused"); changed() }
    }

    var accumulateOnWindows: Bool {
        get { defaults.bool(forKey: "accumulateOnWindows") }
        set { defaults.set(newValue, forKey: "accumulateOnWindows"); changed() }
    }

    var soundOn: Bool {
        get { defaults.bool(forKey: "soundOn") }
        set { defaults.set(newValue, forKey: "soundOn"); changed() }
    }

    var currentWallpaper: Int? {
        get { defaults.object(forKey: "currentWallpaper") as? Int }
        set {
            if let v = newValue { defaults.set(v, forKey: "currentWallpaper") } else { defaults.removeObject(forKey: "currentWallpaper") }
            changed()
        }
    }

    private func changed() {
        NotificationCenter.default.post(name: Settings.didChange, object: self)
    }
}
