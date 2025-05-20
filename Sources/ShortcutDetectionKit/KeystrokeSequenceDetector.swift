@preconcurrency import CoreGraphics
import Foundation
import os.log

/// Actor that detects and processes keyboard sequences in real-time.
///
/// The detector maintains state about the current sequence of keystrokes and can be used
/// to detect specific keyboard shortcuts or combinations. It automatically resets after
/// a configurable interval of inactivity.
public final actor KeystrokeSequenceDetector {

    private let autoresetInterval: TimeInterval
    private var keystrokeSequenceState = KeystrokeSequenceDetectionState(anticipatedInput: [])
    private var autoResetSchedule: Task<Void, Error>?
    private let shouldLogKeycodes: Bool
    private let enableLogging: Bool
    private static let log = OSLog(subsystem: "com.shortcutdetectionkit", category: "KeystrokeSequenceDetector")
    
    @usableFromInline
    static let defaultAutoResetInterval: TimeInterval = 0.125

    /// Creates a new keystroke sequence detector.
    /// - Parameters:
    ///   - interval: The time interval in seconds after which the detector will automatically reset if no new keystrokes are detected. Default is 0.125 seconds.
    ///   - shouldLogKeycodes: Whether to include keycodes in logs. Default is false for privacy.
    public init(
        autoresetInterval interval: TimeInterval = KeystrokeSequenceDetector.defaultAutoResetInterval,
        shouldLogKeycodes logKeycodes: Bool = false,
        enableLogging loggingEnabled: Bool = false
    ) {
        autoresetInterval = interval
        shouldLogKeycodes = logKeycodes
        enableLogging = loggingEnabled
    }
    
    /// Creates a new keystroke sequence detector.
    /// - Parameters:
    ///   - interval: The time interval in seconds after which the detector will automatically reset if no new keystrokes are detected. Default is 0.125 seconds.
    ///   - anticipatedInput: A sequence of keystroke sequences to detect
    ///   - shouldLogKeycodes: Whether to include keycodes in logs. Default is false for privacy.
    public init<S: Sequence>(
        autoresetInterval interval: TimeInterval = KeystrokeSequenceDetector.defaultAutoResetInterval,
        anticipatingInput anticipatedInput: S,
        shouldLogKeycodes logKeycodes: Bool = false,
        enableLogging loggingEnabled: Bool = false
    ) where S.Element == KeystrokeSequence {
        autoresetInterval = interval
        keystrokeSequenceState.anticipatedInput = Set(anticipatedInput)
        shouldLogKeycodes = logKeycodes
        enableLogging = loggingEnabled
    }
    
    private func scheduleAutoReset(withFlags flags: CGEventFlags? = CGEventFlags.empty) {
        // Cancel existing task and wait for it to complete
        if let existingTask = autoResetSchedule {
            existingTask.cancel()
            // Wait for the task to complete its cancellation
            _ = try? Task.checkCancellation()
        }
        
        // Create new task only after ensuring previous one is cancelled
        let newAutoResetSchedule = Task { [weak self] in
            guard let self else { return }
            try await Task.sleep(nanoseconds: UInt64(autoresetInterval * 1_000_000_000))
            try Task.checkCancellation()
            await reset(withFlags: flags)
        }
        autoResetSchedule = newAutoResetSchedule
    }

    /// Processes a CoreGraphics event and updates the detector's state.
    /// - Parameter cgEvent: The CoreGraphics event to process
    /// - Returns: The updated detection state after processing the event
    @discardableResult public func process(cgEvent: sending CGEvent) -> KeystrokeSequenceDetectionState {
        if [.keyDown].contains(cgEvent.type) {
            autoResetSchedule?.cancel()
        }
        if [.flagsChanged, .keyUp].contains(cgEvent.type) {
            scheduleAutoReset(withFlags: cgEvent.flags)
        }
        if [.keyUp, .keyDown].contains(cgEvent.type) {
            let eventType = cgEvent.type == .keyDown ? "keyDown" : "keyUp"
            if shouldLogKeycodes, enableLogging {
                os_log(
                    "Processing %{public}s event with keycode: %d",
                    log: Self.log,
                    type: .debug,
                    eventType,
                    cgEvent.getIntegerValueField(.keyboardEventKeycode)
                )
            } else if enableLogging {
                os_log("Processing %{public}s event", log: Self.log, type: .debug, eventType)
            }
        }
        keystrokeSequenceState.attach(cgEvent: cgEvent)
        return keystrokeSequenceState
    }

    /// Resets the detector's state, optionally preserving certain modifier flags.
    /// - Parameter flags: The modifier flags to preserve after reset. If nil, uses the current flags minus ignored flags.
    public func reset(withFlags flags: CGEventFlags? = CGEventFlags.empty) {
        let flags = flags ?? keystrokeSequenceState.input.flags.subtracting(KeystrokeSequence.ignoredFlags)
        keystrokeSequenceState.reset(withFlags: flags)
        if enableLogging {
            os_log("Reset detector state", log: Self.log, type: .debug)
        }
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
        if enableLogging {
            os_log("Updated anticipated input sequences", log: Self.log, type: .debug)
        }
    }
}
