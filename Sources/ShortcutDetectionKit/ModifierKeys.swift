import CoreGraphics

/// How a ``KeystrokeSequenceDetector`` interprets the modifier keys ⌃, ⌥, ⌘, ⇧ and fn.
public enum ModifierKeyInterpretation: Sendable, Hashable, Codable {
    /// Modifier keys contribute their flags to a sequence and nothing else (default).
    case modifier
    /// Modifier keys contribute their flags while held, just like with ``modifier``. In addition, pressing and releasing a
    /// modifier key without any other key in between - a *tap* - counts as a keystroke of its own: the modifier's key code
    /// is appended to the sequence's keys, under the flags still held after the release.
    ///
    /// Double tapping the left ⌃ key thus produces `KeystrokeSequence(flags: .empty, keys: [.control, .control])`, which is
    /// what ``KeystrokeSequence/init(tapping:times:flags:)`` creates.
    ///
    /// A modifier key held for longer than the detector's `autoresetInterval` is no tap. The interval is also the longest pause
    /// between two taps of a sequence.
    case modifierAndKey
}

public extension KeyCode {
    /// Key code for the right command key
    static let rightCommand: Self = 54

    /// The modifier keys a tap is recognized for. Caps lock toggles rather than being held and is therefore not among them.
    static let modifierKeys: [KeyCode] = [
        .command, .rightCommand, .shift, .rightShift, .option, .rightOption, .control, .rightControl, .function
    ]

    /// Whether this is one of the ``modifierKeys``
    var isModifierKey: Bool {
        modifierFlag != nil
    }

    /// The device independent flag set while this modifier key is held, `nil` for any other key
    var modifierFlag: CGEventFlags? {
        switch self {
            case .command, .rightCommand:
                .maskCommand
            case .shift, .rightShift:
                .maskShift
            case .option, .rightOption:
                .maskAlternate
            case .control, .rightControl:
                .maskControl
            case .function:
                .maskSecondaryFn
            default:
                nil
        }
    }

    /// The device dependent flag (`NX_DEVICE…KEYMASK`) that tells the left from the right key of a modifier pair
    internal var deviceModifierFlag: CGEventFlags? {
        switch self {
            case .control:
                .init(rawValue: 0x0000_0001)
            case .shift:
                .init(rawValue: 0x0000_0002)
            case .rightShift:
                .init(rawValue: 0x0000_0004)
            case .command:
                .init(rawValue: 0x0000_0008)
            case .rightCommand:
                .init(rawValue: 0x0000_0010)
            case .option:
                .init(rawValue: 0x0000_0020)
            case .rightOption:
                .init(rawValue: 0x0000_0040)
            case .rightControl:
                .init(rawValue: 0x0000_2000)
            default:
                nil
        }
    }

    /// Whether the flags of a `flagsChanged` event for this modifier key report it as held, `nil` for any other key.
    ///
    /// Events lacking device dependent flags, such as synthesized ones, only tell whether either key of a left/right pair is held.
    internal func isHeld(in flags: CGEventFlags) -> Bool? {
        guard let modifierFlag else {
            return nil
        }
        guard flags.contains(modifierFlag) else {
            return false
        }
        guard let deviceModifierFlag else {
            return true
        }
        let pairFlags = Self.modifierKeys
            .filter { $0.modifierFlag == modifierFlag }
            .compactMap(\.deviceModifierFlag)
            .reduce(CGEventFlags()) { $0.union($1) }
        return flags.isDisjoint(with: pairFlags) || flags.contains(deviceModifierFlag)
    }
}

public extension KeystrokeSequence {
    /// A sequence of taps on a modifier key, e.g. `KeystrokeSequence(tapping: .control)` for a double tap on ⌃.
    ///
    /// Only a ``KeystrokeSequenceDetector`` interpreting modifier keys as ``ModifierKeyInterpretation/modifierAndKey`` detects it.
    ///
    /// - Parameters:
    ///   - modifierKey: The modifier key to tap, one of ``KeyCode/modifierKeys``
    ///   - count: How often the key is tapped (default: 2)
    ///   - flags: Other modifiers held throughout the taps (default: none)
    init(tapping modifierKey: KeyCode, times count: Int = 2, flags: CGEventFlags = .empty) {
        self.init(flags: flags, keys: Array(repeating: modifierKey, count: count))
    }
}
