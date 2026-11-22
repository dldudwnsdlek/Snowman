import AppKit

/// Short system sounds, gated by the 효과음 setting and throttled.
enum Sound {
    enum Effect: String {
        case pop = "Pop"
        case whoosh = "Blow"
        case crash = "Glass"
        case thud = "Bottle"
        case horn = "Submarine"
        case done = "Hero"
        case tink = "Tink"
    }

    static var enabled = true
    private static var cache: [Effect: NSSound] = [:]
    private static var lastPlayed: [Effect: TimeInterval] = [:]

    static func play(_ effect: Effect, volume: Float = 0.35) {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlayed[effect], now - last < 0.18 { return }
        lastPlayed[effect] = now
        let sound: NSSound
        if let cached = cache[effect] {
            sound = cached
        } else {
            guard let s = NSSound(named: NSSound.Name(effect.rawValue)) else { return }
            cache[effect] = s
            sound = s
        }
        sound.stop()
        sound.volume = volume
        sound.play()
    }
}
