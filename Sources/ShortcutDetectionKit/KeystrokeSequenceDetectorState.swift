import Foundation
import CoreGraphics

public struct KeystrokeSequenceDetectionState: Sendable, Equatable {

    public var anticipatedInput: Set<KeystrokeSequence>
    public var input: RawKeystrokeSequence
    private(set) public var isValidSubsequence: Bool

    private init<S: Sequence>(
        anticipatedInput: S,
        currentInput: RawKeystrokeSequence,
        hasAnyMatch: Bool
    ) where S.Element == KeystrokeSequence, S: Sendable {
        self.anticipatedInput = Set(anticipatedInput)
        self.input = currentInput
        self.isValidSubsequence = hasAnyMatch
    }

    public init<S: Sequence>(
        anticipatedInput: S
    ) where S.Element == KeystrokeSequence, S: Sendable {
        self.init(anticipatedInput: anticipatedInput, currentInput: .init(), hasAnyMatch: false)
    }

    public mutating func attach(cgEvent: CGEvent) {
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

    public mutating func reset(withFlags flags: CGEventFlags = .empty) {
        input = .init(flags: flags)
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
