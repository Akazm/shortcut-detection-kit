import Foundation
import CoreGraphics

/// A representation of a sequence of keystrokes, including modifier flags and pressed keys.
///
/// This type is used to represent keyboard shortcuts and sequences in a way that can be
/// compared, hashed, and encoded. It handles the conversion between raw key codes and
/// their semantic meaning, while also managing modifier flags.
public struct KeystrokeSequence: Hashable, Codable, Sendable {
    public typealias Key = KeyCode

    /// Represents *overhead* of `CGEventFlags`
    ///
    /// Default is `[.maskOverhead, .maskNonCoalesced, .maskNumericPad, .maskSecondaryFn]`
    public static var ignoredFlags: CGEventFlags {
        RawKeystrokeSequence.ignoredFlags
    }

    /// The raw modifier flags for this sequence
    public let flags: UInt64
    
    /// The sequence of keys in this keystroke sequence
    public let keys: [Self.Key]

    /// Creates an empty keystroke sequence
    public init() {
        self = . init(flags: CGEventFlags().rawValue, keys: [Self.Key]())
    }

    /// Creates a keystroke sequence with the specified flags and keys
    /// - Parameters:
    ///   - flags: The raw modifier flags
    ///   - keys: The sequence of keys
    public init(flags: UInt64, keys: [Self.Key]) {
        self.flags = CGEventFlags(rawValue: flags).subtracting(Self.ignoredFlags).rawValue
        self.keys = keys.map(\.self)
    }

    /// Creates a keystroke sequence with the specified flags and keys
    /// - Parameters:
    ///   - flags: The modifier flags
    ///   - keys: The sequence of keys
    public init(flags: CGEventFlags, keys: [Self.Key]) {
        self.flags = flags.subtracting(Self.ignoredFlags).rawValue
        self.keys = keys
    }

    /// Creates a keystroke sequence from a CoreGraphics event
    /// - Parameter cgEvent: The CoreGraphics event to create the sequence from
    public init(cgEvent: CGEvent) {
        self = .init(
            flags: cgEvent.flags.subtracting(Self.ignoredFlags),
            keys: [.keyDown, .keyUp].contains(cgEvent.type) ? [cgEvent.keyCode] : []
        )
    }
}

public extension KeystrokeSequence {
    /// Creates a new sequence with the specified flags
    /// - Parameter flags: The new modifier flags
    /// - Returns: A new keystroke sequence with the updated flags
    func with(flags: CGEventFlags) -> Self {
        .init(flags: flags.subtracting(Self.ignoredFlags).rawValue, keys: keys)
    }

    /// Creates a new sequence with the specified raw flags
    /// - Parameter flags: The new raw modifier flags
    /// - Returns: A new keystroke sequence with the updated flags
    func with(flags: UInt64) -> Self {
        with(flags: .init(rawValue: flags))
    }

    /// Creates a new sequence with the specified key codes
    /// - Parameter keys: The new sequence of key codes
    /// - Returns: A new keystroke sequence with the updated keys
    func with(keys: [UInt16]) -> Self {
        .init(flags: flags, keys: keys)
    }
}

public extension KeystrokeSequence {
    /// Returns true if the modifier flags match, ignoring the specified overhead flags
    /// - Parameter sequence: The sequence to compare against
    /// - Returns: True if the modifier flags match
    func isMaskEqual(to sequence: Self) -> Bool {
        let otherFlags = CGEventFlags(rawValue: sequence.flags)
            .subtracting(Self.ignoredFlags)
        let ownFlags = CGEventFlags(rawValue: flags)
            .subtracting(Self.ignoredFlags)
        return otherFlags.contains(ownFlags) && ownFlags.contains(otherFlags)
    }

    /// Returns true if this sequence contains the specified sequence
    /// - Parameter sequence: The sequence to check for
    /// - Returns: True if this sequence contains the specified sequence
    func contains(_ sequence: Self) -> Bool {
        return !isMaskEqual(to: sequence) || sequence.keys.count > keys.count
            ? false
            : zip(sequence.keys, self.keys).allSatisfy { $0.0 == $0.1 }
    }

    /// Returns true if this sequence exactly matches the specified sequence
    /// - Parameter sequence: The sequence to compare against
    /// - Returns: True if the sequences match exactly
    func matches(sequence: Self) -> Bool {
        return if !isMaskEqual(to: sequence) || sequence.keys.count != keys.count {
            false
        } else {
            zip(sequence.keys, keys).allSatisfy { $0.0 == $0.1 }
        }
    }

    /// A value used for sorting sequences
    var sortPriority: UInt64 {
        flags + keys.enumerated().reduce(
            UInt64(0), { (result, enumeratedKey) in
                let (index, keyCode) = enumeratedKey
                return result + (UInt64(index + 1) * UInt64(keyCode))
            }
        )
    }

    /// Returns true if the sequence is empty (no keys and no modifier flags)
    var isEmpty: Bool {
        keys.isEmpty && (CGEventFlags() == CGEventFlags(rawValue: flags) || CGEventFlags(rawValue: flags) == .init())
    }

    /// Returns a string representation of the sequence
    @MainActor
    var stringValue: String {
        let modifiers = KeyboardCharacters.keyboardCharactersFor(
            eventFlags: CGEventFlags(rawValue: flags)
        )
        let keys = keys.compactMap {
            KeyboardCharacters.keyboardCharacterFor(key: $0, flags: .init())
        }.joined(
            separator: "\u{2009}"
        )
        return "\(modifiers)  \(keys)".trimmingCharacters(in: .whitespaces)
    }

    /// Returns an attributed string representation of the sequence
    /// - Parameter numpadPrefix: The prefix to use for numpad keys
    /// - Returns: An attributed string representation of the sequence
    @MainActor
    func attributedStringValue(numpadPrefix: NSAttributedString) -> NSAttributedString {
        let keys = keys.reduce(NSMutableAttributedString(string: "")) { string, keyCode in
            let character = KeyboardCharacters.attributedCharacterFor(
                key: keyCode,
                flags: .init(),
                numpadPrefix: numpadPrefix
            )
            if let character {
                string.append(.init(string: "\u{2009}"))
                string.append(character)
            }
            return string
        }
        let finalResult = NSMutableAttributedString(
            attributedString: NSAttributedString(
                string: KeyboardCharacters.keyboardCharactersFor(
                    eventFlags: CGEventFlags(rawValue: flags)
                )
            )
        )
        finalResult.append(.init(string: ""))
        finalResult.append(keys)
        return finalResult
    }

    /// Returns a debug description of the sequence
    @MainActor
    var debugDescription: String {
       let modifiers = KeyboardCharacters.keyboardCharactersFor(
           eventFlags: CGEventFlags(rawValue: flags)
       )
       let keys = keys.compactMap {
           KeyboardCharacters.keyboardCharacterFor(key: $0, flags: .init())
       }.joined(
           separator: " "
       )
       let modifiersDescription = modifiers.isEmpty ? "" : "\(modifiers) "
       return "\(String(describing: Self.self))\("(\(modifiersDescription)\(keys)".trimmingCharacters(in: .whitespaces)))"
    }

    /// Prints the sequence to the console
    func printToConsole() {
        Task {
            await MainActor.run {
                print(debugDescription)
            }
        }
    }
}

extension KeystrokeSequence: Comparable {
    /// Compares two keystroke sequences based on their sort priority
    public static func < (lhs: KeystrokeSequence, rhs: KeystrokeSequence) -> Bool {
        lhs.sortPriority < rhs.sortPriority
    }
}

public extension RawKeystrokeSequence {
    /// Converts a raw keystroke sequence to a sanitized keystroke sequence
    var sanitized: KeystrokeSequence {
        return .init(
            flags: flags.rawValue,
            keys: keys.compactMap {
                switch $0 {
                    case .keyDown(let code):
                        return code
                    default:
                        return nil
                }
            }
        )
    }
}
