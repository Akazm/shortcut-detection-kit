import Foundation
import CoreGraphics

public struct KeystrokeSequenceDetectionState: Sendable, Equatable {

    /// A modifier key pressed with no other key event since: a tap, once released.
    private struct PendingModifierTap: Sendable, Equatable {
        let keyCode: KeyCode
        /// The input as it was before the modifier key went down, which the tap continues.
        let input: RawKeystrokeSequence
    }

    public var anticipatedInput: Set<KeystrokeSequence>
    public var input: RawKeystrokeSequence
    private(set) public var isValidSubsequence: Bool
    /// How modifier keys are interpreted. See: ``ModifierKeyInterpretation``
    public var modifierKeyInterpretation: ModifierKeyInterpretation {
        didSet {
            pendingModifierTap = nil
        }
    }
    private var pendingModifierTap: PendingModifierTap?

    private init<S: Sequence>(
        anticipatedInput: S,
        currentInput: RawKeystrokeSequence,
        hasAnyMatch: Bool,
        modifierKeyInterpretation: ModifierKeyInterpretation
    ) where S.Element == KeystrokeSequence, S: Sendable {
        self.anticipatedInput = Set(anticipatedInput)
        self.input = currentInput
        self.isValidSubsequence = hasAnyMatch
        self.modifierKeyInterpretation = modifierKeyInterpretation
    }

    public init<S: Sequence>(
        anticipatedInput: S,
        modifierKeyInterpretation: ModifierKeyInterpretation = .modifier
    ) where S.Element == KeystrokeSequence, S: Sendable {
        self.init(
            anticipatedInput: anticipatedInput,
            currentInput: .init(),
            hasAnyMatch: false,
            modifierKeyInterpretation: modifierKeyInterpretation
        )
    }

    public mutating func attach(cgEvent: CGEvent) {
        if let modifierTap = trackModifierTap(cgEvent: cgEvent) {
            attach(modifierTap: modifierTap, flags: cgEvent.flags)
            return
        }
        let nextInput = switch cgEvent.type {
            case .keyDown:
                RawKeystrokeSequence(flags: cgEvent.flags, keys: input.keys + [.keyDown(cgEvent.keyCode)])
            case .keyUp:
                RawKeystrokeSequence(flags: cgEvent.flags, keys: input.keys + [.keyUp(cgEvent.keyCode)])
            case .flagsChanged:
                RawKeystrokeSequence(flags: cgEvent.flags, keys: input.keys + [.keyUp(cgEvent.keyCode)])
            default:
                nil as RawKeystrokeSequence?
        }
        guard var nextInput else {
            return
        }
        let anticipatedInput = anticipatedInput
        var hasAnyPartialMatch = anticipatedInput.first { $0.contains(nextInput.sanitized) } != nil
        if !hasAnyPartialMatch {
            let newNextInput = RawKeystrokeSequence(
                flags: cgEvent.flags,
                keys: [.keyDown].contains(cgEvent.type) ? [.keyDown(cgEvent.keyCode)] : []
            )
            nextInput = newNextInput
            hasAnyPartialMatch = anticipatedInput.first { $0.contains(nextInput.sanitized) } != nil
        }
        input = nextInput
        isValidSubsequence = hasAnyPartialMatch
    }

    /// Follows modifier keys going down and up.
    ///
    /// - Returns: The pending tap `cgEvent` completes, `nil` if it completes none
    private mutating func trackModifierTap(cgEvent: CGEvent) -> PendingModifierTap? {
        guard modifierKeyInterpretation == .modifierAndKey else {
            return nil
        }
        let pendingModifierTap = pendingModifierTap
        self.pendingModifierTap = nil
        guard cgEvent.type == .flagsChanged, let isHeld = cgEvent.keyCode.isHeld(in: cgEvent.flags) else {
            return nil
        }
        if isHeld {
            self.pendingModifierTap = .init(keyCode: cgEvent.keyCode, input: input)
            return nil
        }
        return pendingModifierTap?.keyCode == cgEvent.keyCode ? pendingModifierTap : nil
    }

    /// Continues the input the tapped modifier key went down on, as if the key was any other key.
    private mutating func attach(modifierTap: PendingModifierTap, flags: CGEventFlags) {
        let tap: [RawKeystrokeSequence.Event] = [.keyDown(modifierTap.keyCode), .keyUp(modifierTap.keyCode)]
        var nextInput = RawKeystrokeSequence(flags: flags, keys: modifierTap.input.keys + tap)
        var hasAnyPartialMatch = anticipatedInput.contains { $0.contains(nextInput.sanitized) }
        if !hasAnyPartialMatch {
            nextInput = RawKeystrokeSequence(flags: flags, keys: tap)
            hasAnyPartialMatch = anticipatedInput.contains { $0.contains(nextInput.sanitized) }
        }
        input = nextInput
        isValidSubsequence = hasAnyPartialMatch
    }

    public mutating func reset(withFlags flags: CGEventFlags = .empty) {
        input = .init(flags: flags)
        pendingModifierTap = nil
    }

    public var remainingInputOptions: Set<KeystrokeSequence> {
        anticipatedInput.filter {
            $0.contains(input.sanitized)
        }
    }

    public var matchingKeystrokeSequence: KeystrokeSequence? {
        if input.keys.isEmpty {
            nil
        } else {
            anticipatedInput.first {
                $0.matches(sequence: input.sanitized)
            }
        }
    }

}
