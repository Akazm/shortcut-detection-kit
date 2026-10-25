import CoreGraphics

public func +(lhs: CGEventFlags, rhs: [KeyCode]) -> KeystrokeSequence {
    KeystrokeSequence(flags: lhs, keys: rhs)
}
public func +(lhs: CGEventFlags, rhs: TrackpadGesture) -> TrackpadGesture {
    rhs.with(flags: lhs)
}
