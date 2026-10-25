import CoreGraphics
import Foundation
@testable import ShortcutDetectionKit
import Testing

private let nonCoalesced = CGEventFlags.maskNonCoalesced
private let leftControl = CGEventFlags.maskControl.union(.init(rawValue: 0x1))
private let rightControl = CGEventFlags.maskControl.union(.init(rawValue: 0x2000))
private let leftCommand = CGEventFlags.maskCommand.union(.init(rawValue: 0x8))

private func flagsChanged(_ keyCode: KeyCode, flags: CGEventFlags) -> CGEvent {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    event.type = .flagsChanged
    event.flags = flags.union(nonCoalesced)
    return event
}

private func key(_ keyCode: KeyCode, down: Bool, flags: CGEventFlags = []) -> CGEvent {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down)!
    event.flags = flags.union(nonCoalesced)
    return event
}

/// Presses and releases `keyCode`, which sets `flags` while held, on top of `held`.
private func tap(_ keyCode: KeyCode, flags: CGEventFlags, held: CGEventFlags = []) -> [CGEvent] {
    [flagsChanged(keyCode, flags: held.union(flags)), flagsChanged(keyCode, flags: held)]
}

private func state(
    _ anticipatedInput: [KeystrokeSequence],
    _ interpretation: ModifierKeyInterpretation = .modifierAndKey
) -> KeystrokeSequenceDetectionState {
    KeystrokeSequenceDetectionState(anticipatedInput: anticipatedInput, modifierKeyInterpretation: interpretation)
}

private extension KeystrokeSequenceDetectionState {
    mutating func attach(_ events: [CGEvent]) {
        events.forEach { attach(cgEvent: $0) }
    }
}

@Suite("Modifier taps") struct ModifierTapTests {
    let doubleTapControl = KeystrokeSequence(tapping: .control)

    @Test("A double tap on ⌃ matches") func doubleTapMatches() {
        var state = state([doubleTapControl])
        state.attach(tap(.control, flags: leftControl))
        #expect(state.isValidSubsequence)
        #expect(state.matchingKeystrokeSequence == nil)
        state.attach(tap(.control, flags: leftControl))
        #expect(state.matchingKeystrokeSequence == doubleTapControl)
    }

    @Test("A modifier used for a shortcut is no tap") func modifierWithKeyIsNoTap() {
        var state = state([doubleTapControl])
        state.attach([
            flagsChanged(.control, flags: leftControl),
            key(.c, down: true, flags: leftControl),
            key(.c, down: false, flags: leftControl),
            flagsChanged(.control, flags: []),
        ])
        state.attach(tap(.control, flags: leftControl))
        #expect(state.matchingKeystrokeSequence == nil)
    }

    @Test("Left and right modifier keys are told apart") func leftAndRightAreDistinct() {
        var state = state([doubleTapControl])
        state.attach(tap(.rightControl, flags: rightControl))
        state.attach(tap(.rightControl, flags: rightControl))
        #expect(state.matchingKeystrokeSequence == nil)
        state.attach(tap(.control, flags: leftControl))
        state.attach(tap(.rightControl, flags: rightControl))
        #expect(state.matchingKeystrokeSequence == nil)
        state.attach(tap(.rightControl, flags: rightControl))
        #expect(state.matchingKeystrokeSequence == nil)
        state.attach(tap(.control, flags: leftControl))
        state.attach(tap(.control, flags: leftControl))
        #expect(state.matchingKeystrokeSequence == doubleTapControl)
    }

    @Test("Taps are recognized without device dependent flags") func synthesizedFlags() {
        var state = state([doubleTapControl])
        state.attach(tap(.control, flags: .maskControl))
        state.attach(tap(.control, flags: .maskControl))
        #expect(state.matchingKeystrokeSequence == doubleTapControl)
    }

    @Test("Taps carry the flags of other modifiers held") func tapWhileHoldingOtherModifier() {
        let sequence = KeystrokeSequence(tapping: .control, flags: .maskCommand)
        var state = state([sequence, doubleTapControl])
        state.attach(cgEvent: flagsChanged(.command, flags: leftCommand))
        state.attach(tap(.control, flags: leftControl, held: leftCommand))
        state.attach(tap(.control, flags: leftControl, held: leftCommand))
        #expect(state.matchingKeystrokeSequence == sequence)
    }

    @Test("Taps are ignored when modifiers are interpreted as modifiers only") func modifierOnly() {
        var state = state([doubleTapControl], .modifier)
        state.attach(tap(.control, flags: leftControl))
        state.attach(tap(.control, flags: leftControl))
        #expect(state.matchingKeystrokeSequence == nil)
    }

    @Test("Sequences of flags only keep matching") func flagsOnlySequences() {
        let holdControl = KeystrokeSequence(flags: .maskControl, keys: [])
        var state = state([holdControl, doubleTapControl])
        state.attach(cgEvent: flagsChanged(.control, flags: leftControl))
        #expect(state.matchingKeystrokeSequence == holdControl)
    }

    @Test("Modifier shortcuts keep matching") func modifierShortcuts() {
        let shortcut = KeystrokeSequence(flags: [.maskCommand, .maskControl], keys: [.leftArrow])
        var state = state([shortcut, doubleTapControl])
        state.attach([
            flagsChanged(.command, flags: leftCommand),
            flagsChanged(.control, flags: leftCommand.union(leftControl)),
            key(.leftArrow, down: true, flags: leftCommand.union(leftControl)),
        ])
        #expect(state.matchingKeystrokeSequence == shortcut)
    }

    @Test("A double tap matches within the autoreset interval") func detectorDoubleTap() async {
        let detector = KeystrokeSequenceDetector(
            autoresetInterval: 0.25,
            anticipatingInput: [doubleTapControl],
            modifierKeyInterpretation: .modifierAndKey
        )
        var match: KeystrokeSequence?
        for flags in [leftControl, [], leftControl, []] {
            match = await detector.process(cgEvent: flagsChanged(.control, flags: flags)).matchingKeystrokeSequence
        }
        #expect(match == doubleTapControl)
    }

    @Test("A modifier held beyond the autoreset interval is no tap") func detectorLongHold() async throws {
        let detector = KeystrokeSequenceDetector(
            autoresetInterval: 0.05,
            anticipatingInput: [doubleTapControl],
            modifierKeyInterpretation: .modifierAndKey
        )
        await detector.process(cgEvent: flagsChanged(.control, flags: leftControl))
        try await Task.sleep(nanoseconds: 200_000_000)
        await detector.process(cgEvent: flagsChanged(.control, flags: []))
        var match: KeystrokeSequence?
        for flags in [leftControl, []] {
            match = await detector.process(cgEvent: flagsChanged(.control, flags: flags)).matchingKeystrokeSequence
        }
        #expect(match == nil)
    }
}
