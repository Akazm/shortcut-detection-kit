import CoreGraphics
import Foundation

/// One finger on, or hovering over, a trackpad, as a ``TrackpadGestureDetector`` sees it.
///
/// The detector depends on no event source: whatever delivers touches, such as TapGuard's `TouchFrame`, maps its contacts
/// into these, the way keyboard events are passed in as `CGEvent`s.
public struct GestureTouch: Sendable, Hashable, Codable {
    /// Stays the same for a finger from landing to lifting
    public let id: Int
    /// In 0...1 of the trackpad's width and height, with the origin at the bottom left and `y` growing upwards
    public let position: CGPoint
    /// Whether the finger is on the surface. Hovering fingers take no part in gestures.
    public let isTouching: Bool

    public init(id: Int, position: CGPoint, isTouching: Bool = true) {
        self.id = id
        self.position = position
        self.isTouching = isTouching
    }
}

/// Every finger on a trackpad at one moment
public struct GestureFrame: Sendable, Hashable, Codable {
    /// In seconds, from any fixed point. Only differences between frames matter, and they drive every tolerance, so that
    /// trackpads delivering 50 or 120 frames a second behave the same.
    public let timestamp: TimeInterval
    public let touches: [GestureTouch]

    public init(timestamp: TimeInterval, touches: [GestureTouch]) {
        self.timestamp = timestamp
        self.touches = touches
    }

    /// The fingers on the surface
    public var touching: [GestureTouch] {
        touches.filter(\.isTouching)
    }
}
