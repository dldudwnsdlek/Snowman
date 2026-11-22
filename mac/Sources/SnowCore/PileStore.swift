import CoreGraphics
import Foundation

public struct DroppedPile {
    public let spec: LedgeSpec
    public let pile: SnowPile
}

public struct LedgeMove: Equatable {
    public let kind: LedgeKind
    public let dx: CGFloat
    public let dy: CGFloat
}

public struct SyncResult {
    /// Ledges that went away for good: their snow should fall ("우수수").
    public var dropped: [DroppedPile] = []
    /// Ledges that are still here but moved since the last sync.
    public var moved: [LedgeMove] = []
}

/// Owns the snow piles of one screen and keeps them matched to the current ledges.
public final class PileStore {
    public var piles: [LedgeKind: SnowPile] = [:]
    public private(set) var specs: [LedgeKind: LedgeSpec] = [:]
    /// Piles whose ledge disappeared temporarily (Space switch, Dock auto-hide).
    public private(set) var stash: [LedgeKind: SnowPile] = [:]

    public init() {}

    /// Current ledges in a stable order (windows front-to-back, then Dock, then ground).
    public private(set) var orderedKinds: [LedgeKind] = []

    public func sync(_ newSpecs: [LedgeSpec], now: TimeInterval, graceUntil: TimeInterval) -> SyncResult {
        var result = SyncResult()
        let newKinds = Set(newSpecs.map(\.kind))

        for kind in specs.keys where !newKinds.contains(kind) {
            guard let pile = piles.removeValue(forKey: kind), let oldSpec = specs[kind] else { continue }
            if kind == .dock || now < graceUntil {
                stash[kind] = pile
            } else if !pile.isEmpty {
                result.dropped.append(DroppedPile(spec: oldSpec, pile: pile))
            }
        }

        var newSpecMap: [LedgeKind: LedgeSpec] = [:]
        for spec in newSpecs {
            newSpecMap[spec.kind] = spec
            if var pile = piles[spec.kind] ?? stash.removeValue(forKey: spec.kind) {
                if let old = specs[spec.kind] {
                    let dx = spec.x0 - old.x0
                    let dy = spec.y - old.y
                    if dx != 0 || dy != 0 { result.moved.append(LedgeMove(kind: spec.kind, dx: dx, dy: dy)) }
                }
                if abs(pile.width - spec.width) > 0.5 { pile.resample(toWidth: spec.width) }
                if pile.maxHeight != spec.maxHeight { pile.maxHeight = spec.maxHeight }
                piles[spec.kind] = pile
            } else {
                piles[spec.kind] = SnowPile(width: spec.width, maxHeight: spec.maxHeight)
            }
        }
        specs = newSpecMap
        orderedKinds = newSpecs.map(\.kind)
        return result
    }

    /// Removes snow everywhere, including stashed piles.
    public func clearAll() {
        for key in piles.keys { piles[key]?.clear() }
        stash.removeAll()
    }

    /// Clears a stashed pile (e.g. the hidden Dock's snow when the plow runs).
    public func clearStash(_ kind: LedgeKind) {
        stash[kind] = nil
    }
}
