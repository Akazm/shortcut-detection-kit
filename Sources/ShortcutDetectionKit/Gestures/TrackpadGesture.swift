import CoreGraphics
import Foundation

/// A trackpad gesture: how many fingers, what they do, and which modifier keys are held while they do it.
///
/// The counterpart of ``KeystrokeSequence`` for trackpads. Like a keystroke sequence it is a value to anticipate, compare and
/// store, with ``flags`` kept free of the overhead bits macOS adds (see ``KeystrokeSequence/ignoredFlags``).
public struct TrackpadGesture: Sendable, Hashable, Codable {

    public enum Direction: String, Sendable, Hashable, Codable, CaseIterable {
        case up, down, left, right
    }

    public enum Pinch: String, Sendable, Hashable, Codable, CaseIterable {
        /// Fingers moving together
        case closing
        /// Fingers spreading apart
        case opening
    }

    public enum Rotation: String, Sendable, Hashable, Codable, CaseIterable {
        case clockwise, counterclockwise
    }

    public enum Kind: Sendable, Hashable, Codable {
        /// All fingers moving the same way
        case swipe(Direction)
        /// Fingers moving towards or away from each other
        case pinch(Pinch)
        /// Fingers turning around their common centre
        case rotate(Rotation)
        /// Fingers landing and lifting without moving
        case tap
    }

    /// How many fingers take part, 2 to 5
    public let fingers: Int
    public let kind: Kind
    /// The raw modifier flags held throughout, overhead bits removed
    public let flags: UInt64

    public init(fingers: Int, kind: Kind, flags: CGEventFlags = .empty) {
        self.fingers = fingers
        self.kind = kind
        self.flags = flags.subtracting(KeystrokeSequence.ignoredFlags).rawValue
    }

    public init(fingers: Int, kind: Kind, flags: UInt64) {
        self.init(fingers: fingers, kind: kind, flags: CGEventFlags(rawValue: flags))
    }

    public static func swipe(_ direction: Direction, fingers: Int, flags: CGEventFlags = .empty) -> Self {
        .init(fingers: fingers, kind: .swipe(direction), flags: flags)
    }

    public static func pinch(_ pinch: Pinch, fingers: Int, flags: CGEventFlags = .empty) -> Self {
        .init(fingers: fingers, kind: .pinch(pinch), flags: flags)
    }

    public static func rotate(_ rotation: Rotation, fingers: Int, flags: CGEventFlags = .empty) -> Self {
        .init(fingers: fingers, kind: .rotate(rotation), flags: flags)
    }

    public static func tap(fingers: Int, flags: CGEventFlags = .empty) -> Self {
        .init(fingers: fingers, kind: .tap, flags: flags)
    }

    /// The modifier flags as `CGEventFlags`
    public var eventFlags: CGEventFlags {
        CGEventFlags(rawValue: flags)
    }

    /// The same gesture with other modifier keys
    public func with(flags: CGEventFlags) -> Self {
        .init(fingers: fingers, kind: kind, flags: flags)
    }

    /// Whether the gesture is performed with exactly these modifier keys held, overhead bits aside
    public func isPerformed(withFlags flags: CGEventFlags) -> Bool {
        flags.subtracting(KeystrokeSequence.ignoredFlags).rawValue == self.flags
    }
}

extension TrackpadGesture: CustomDebugStringConvertible {
    public var debugDescription: String {
        let kind = switch kind {
            case let .swipe(direction):
                "swipe \(direction.rawValue)"
            case let .pinch(pinch):
                "pinch \(pinch.rawValue)"
            case let .rotate(rotation):
                "rotate \(rotation.rawValue)"
            case .tap:
                "tap"
        }
        let modifiers = flags == 0 ? "" : "flags 0x\(String(flags, radix: 16)) "
        return "TrackpadGesture(\(modifiers)\(fingers) fingers \(kind))"
    }
}

/// What a ``TrackpadGestureDetector`` reports about a gesture as it happens
public enum GestureEvent: Sendable, Hashable {
    /// The fingers committed to a gesture: they left the dead zone in a way that matches an anticipated gesture
    case began(TrackpadGesture)
    /// The fingers moved on. `progress` runs from 0 at the dead zone to 1 at the configured travel, and drives whatever
    /// follows the gesture on screen; `rawProgress` is the same before clamping, beyond 1 past full travel, for a rubber
    /// band; `velocity` the speed along the gesture in its units per second.
    case changed(TrackpadGesture, progress: Double, rawProgress: Double, velocity: Double)
    /// The fingers lifted, or their number changed. `completed` tells whether the gesture counts as done, by travel or by a
    /// flick, or whether it was abandoned and whatever followed it should return to where it started; `velocity` is the
    /// speed at that moment, for what follows on screen to carry on with.
    case ended(TrackpadGesture, completed: Bool, velocity: Double)

    public var gesture: TrackpadGesture {
        switch self {
            case let .began(gesture), let .changed(gesture, _, _, _), let .ended(gesture, _, _):
                gesture
        }
    }
}
