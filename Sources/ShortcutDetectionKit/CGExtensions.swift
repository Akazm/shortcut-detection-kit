import CoreGraphics

/// Extensions for working with CoreGraphics event flags.
public extension CGEventFlags {
    /// Unknown *overhead flags* of unknown semantics sometimes to be found within event flags emitted by macOS.
    ///
    /// These flags appear to be internal to macOS and don't have documented meanings.
    /// They are typically filtered out when processing keyboard events.
    static var maskOverhead: CGEventFlags {
        [
            .init(rawValue: 0x28), .init(rawValue: 0x2), .init(rawValue: 0x40), .init(rawValue: 0x10),
            .init(rawValue: 0x100), .init(rawValue: 0x1), .init(rawValue: 0x2000)
        ]
    }
    
    static var maskShiftLeftRight: CGEventFlags {
        [.init(rawValue: 2), .init(rawValue: 4)]
    }

    /// Explicit representation for empty event flags sometimes to be found within event flags emitted by macOS.
    ///
    /// This is used to represent a state where no modifier keys are pressed.
    static var empty: CGEventFlags {
        .init()
    }
}

/// Extensions for working with CoreGraphics events.
public extension CGEvent {
    /// The key code associated with this keyboard event.
    ///
    /// This property extracts the key code from the event's integer value field.
    /// For non-keyboard events, the value may be undefined.
    var keyCode: UInt16 {
        .init(
            getIntegerValueField(.keyboardEventKeycode)
        )
    }
    
    /// Whether the user holds the key with the associated `keyCode`
    var isKeyRepeat: Bool {
        getIntegerValueField(.keyboardEventAutorepeat) != 0
    }
}
