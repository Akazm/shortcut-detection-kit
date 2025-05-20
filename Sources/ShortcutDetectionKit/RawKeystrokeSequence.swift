import CoreGraphics

/// A raw representation of a sequence of keystroke events, including modifier flags and key events.
///
/// This struct is used for low-level processing of keyboard input, capturing both key down and key up events
/// along with the associated modifier flags. It is useful for building higher-level abstractions like
/// ``KeystrokeSequence``.
public struct RawKeystrokeSequence: Hashable, Codable, Sendable {

    /// An event in a raw keystroke sequence, representing either a key down or key up event.
    public enum Event: Hashable, Codable, Sendable {
        /// A key down event for the specified key code.
        case keyDown(UInt16)
        /// A key up event for the specified key code.
        case keyUp(UInt16)
    }

    private var rawFlags: UInt64
    /// The sequence of key events in this raw keystroke sequence.
    public var keys: [Self.Event]

    /// Creates a new raw keystroke sequence.
    /// - Parameters:
    ///   - flags: The modifier flags for the sequence (default: empty)
    ///   - keys: The sequence of key events (default: empty)
    public init(flags: CGEventFlags = .empty, keys: [Event] = []) {
        self.rawFlags = flags.subtracting(Self.ignoredFlags).rawValue
        self.keys = keys
    }

    /// The modifier flags for this sequence.
    public var flags: CGEventFlags {
        get {
            .init(rawValue: rawFlags)
        }
        set {
            rawFlags = newValue.subtracting(Self.ignoredFlags).rawValue
        }
    }

    /// The set of modifier flags to ignore when processing events.
    public static var ignoredFlags: CGEventFlags {
        [.maskOverhead, .maskNonCoalesced, .maskNumericPad, .maskSecondaryFn, .maskShiftLeftRight]
    }
}
