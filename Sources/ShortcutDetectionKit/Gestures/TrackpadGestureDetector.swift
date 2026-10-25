import CoreGraphics
import Foundation

/// Actor that recognizes trackpad gestures frame by frame, the counterpart of ``KeystrokeSequenceDetector``.
///
/// Feed it every frame of touches and read the returned ``GestureDetectionState``, or iterate ``events`` for the
/// ``GestureEvent``s as they happen. A gesture's progress follows the fingers until they lift, so that whatever the gesture
/// drives on screen can follow them too, the way Mission Control follows a swipe.
///
/// Modifier keys are not part of the frames: tell the detector about them with ``setModifierFlags(_:)``.
public final actor TrackpadGestureDetector {

    private var state: GestureDetectionState
    private var timeout: Task<Void, Never>?
    private let continuation: AsyncStream<GestureEvent>.Continuation
    /// Every ``GestureEvent``, in order, for as long as the detector lives
    public nonisolated let events: AsyncStream<GestureEvent>

    /// - Parameters:
    ///   - anticipatedInput: The gestures to detect
    ///   - tolerance: How much a hand may stray from the perfect gesture
    public init<S: Sequence>(
        anticipatingInput anticipatedInput: S,
        tolerance: GestureTolerance = .default
    ) where S.Element == TrackpadGesture {
        state = GestureDetectionState(anticipatedGestures: anticipatedInput, tolerance: tolerance)
        let (stream, continuation) = AsyncStream.makeStream(of: GestureEvent.self, bufferingPolicy: .unbounded)
        events = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    /// Processes a frame of touches and updates the detector's state.
    /// - Returns: The state after the frame, with ``GestureDetectionState/events`` telling what the frame changed
    @discardableResult public func process(frame: GestureFrame) -> GestureDetectionState {
        state.attach(frame: frame)
        publishEvents()
        return state
    }

    /// Tells the detector which modifier keys are held. A gesture beginning afterwards has to anticipate exactly these.
    public func setModifierFlags(_ flags: CGEventFlags) {
        state.modifierFlags = flags.subtracting(KeystrokeSequence.ignoredFlags).rawValue
    }

    public func getAnticipatedInput() -> Set<TrackpadGesture> {
        state.anticipatedGestures
    }

    public func setAnticipatedInput<S: Sequence>(_ value: S) where S.Element == TrackpadGesture {
        state.anticipatedGestures = Set(value)
    }

    /// Forgets the fingers, as if they had all lifted without a gesture
    public func reset() {
        timeout?.cancel()
        timeout = nil
        state.reset()
    }

    private func publishEvents() {
        for event in state.events {
            continuation.yield(event)
        }
        timeout?.cancel()
        timeout = nil
        guard state.activeGesture != nil else {
            return
        }
        // A trackpad that stops delivering, say because it disconnected, would leave the gesture hanging
        let interval = state.tolerance.frameTimeout
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else {
                return
            }
            await self?.timeOut()
        }
    }

    private func timeOut() {
        state.timeOut()
        for event in state.events {
            continuation.yield(event)
        }
    }
}
