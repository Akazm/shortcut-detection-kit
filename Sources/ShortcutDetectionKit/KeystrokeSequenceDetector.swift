@preconcurrency import CoreGraphics
import Foundation

/// Actor that detects and processes keyboard sequences in real-time.
///
/// The detector maintains state about the current sequence of keystrokes and can be used
/// to detect specific keyboard shortcuts or combinations. It automatically resets after
/// a configurable interval of inactivity.
public final actor KeystrokeSequenceDetector {

    private let autoresetInterval: TimeInterval
    private var keystrokeSequenceState = KeystrokeSequenceDetectionState(anticipatedInput: [])
    private var autoResetSchedule: Task<Void, Error>?
    
    @usableFromInline
    static let defaultAutoResetInterval: TimeInterval = 0.125

    /// Creates a new keystroke sequence detector.
    /// - Parameter autoresetInterval: The time interval in seconds after which the detector will automatically reset if no new keystrokes are detected. Default is 0.125 seconds.
    public init(
        autoresetInterval interval: TimeInterval = KeystrokeSequenceDetector.defaultAutoResetInterval
    ) {
        autoresetInterval = interval
    }
    
    /// Creates a new keystroke sequence detector.
    /// - Parameter autoresetInterval: The time interval in seconds after which the detector will automatically reset if no new keystrokes are detected. Default is 0.125 seconds.
    public init<S: Sequence>(
        autoresetInterval interval: TimeInterval = KeystrokeSequenceDetector.defaultAutoResetInterval,
        anticipatingInput anticipatedInput: S
    ) where S.Element == KeystrokeSequence {
        autoresetInterval = interval
        keystrokeSequenceState.anticipatedInput = Set(anticipatedInput)
    }
    
    private func scheduleAutoReset(withFlags flags: CGEventFlags? = CGEventFlags.empty) {
        autoResetSchedule?.cancel()
        let newAutoResetSchedule = Task { [weak self] in
            guard let self else { return }
            try await Task.sleep(nanoseconds: UInt64(autoresetInterval * 1_000_000_000))
            await reset(withFlags: flags)
        }
        autoResetSchedule = newAutoResetSchedule
    }

    /// Processes a CoreGraphics event and updates the detector's state.
    /// - Parameter cgEvent: The CoreGraphics event to process
    /// - Returns: The updated detection state after processing the event
    @discardableResult public func process(cgEvent: sending CGEvent) -> KeystrokeSequenceDetectionState {
        keystrokeSequenceState.attach(cgEvent: cgEvent)
        if [.keyUp, .keyDown].contains(cgEvent.type) {
            scheduleAutoReset(withFlags: cgEvent.flags)
        }
        return keystrokeSequenceState
    }

    /// Resets the detector's state, optionally preserving certain modifier flags.
    /// - Parameter flags: The modifier flags to preserve after reset. If nil, uses the current flags minus ignored flags.
    public func reset(withFlags flags: CGEventFlags? = CGEventFlags.empty) {
        let flags = flags ?? keystrokeSequenceState.input.flags.subtracting(KeystrokeSequence.ignoredFlags)
        keystrokeSequenceState.reset(withFlags: flags)
    }

    /// Returns the set of anticipated input sequences that the detector is looking for.
    /// - Returns: A set of keystroke sequences that the detector is configured to detect
    public func getAnticipatedInput() -> Set<KeystrokeSequence> {
        keystrokeSequenceState.anticipatedInput
    }

    /// Sets the anticipated input sequences that the detector should look for.
    /// - Parameter value: A sequence of keystroke sequences to detect
    public func setAnticipatedInput<S: Sequence>(_ value: S) where S.Element == KeystrokeSequence {
        keystrokeSequenceState.anticipatedInput = Set(value)
    }

}
