import CoreGraphics

public func +(lhs: CGEventFlags, rhs: [KeyCode]) -> KeystrokeSequence {
    KeystrokeSequence(flags: lhs, keys: rhs)
}