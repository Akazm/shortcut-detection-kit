import CoreGraphics
import Foundation
@testable import ShortcutDetectionKit
import Testing

// MARK: - Synthetic hands

/// A deterministic source of noise
private struct LinearCongruentialGenerator {
    var state: UInt64

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// Frames of `fingers` fingers arranged around `center`, which first sit still, then move together over `duration`
/// seconds, then lift: translated by `translation`, their spread scaled by `scale`, turned by `rotation` degrees
/// (counterclockwise). Fingers land `stagger` seconds apart, positions wobble by up to `noise`.
private func hand(
    fingers: Int,
    center: CGPoint = CGPoint(x: 0.5, y: 0.5),
    spread: Double = 0.1,
    translation: CGPoint = .zero,
    scale: Double = 1,
    rotation: Double = 0,
    stillBefore: TimeInterval = 0.12,
    duration: TimeInterval = 0.4,
    stillAfter: TimeInterval = 0,
    stagger: TimeInterval = 0,
    rate: Double = 60,
    noise: Double = 0,
    lifts: Bool = true,
    hovering: Bool = false
) -> [GestureFrame] {
    var random = LinearCongruentialGenerator(state: 42)
    var frames = [GestureFrame]()
    let end = stillBefore + duration + stillAfter
    var timestamp = 0.0
    while timestamp <= end + 1e-9 {
        let progress = min(max((timestamp - stillBefore) / duration, 0), 1)
        let currentScale = 1 + (scale - 1) * progress
        let currentRotation = rotation * progress * .pi / 180
        var touches = [GestureTouch]()
        for finger in 0 ..< fingers where timestamp + 1e-9 >= Double(finger) * stagger {
            let angle = 2 * Double.pi * Double(finger) / Double(fingers) + currentRotation
            let x = center.x + translation.x * progress + spread * currentScale * cos(angle)
                + (random.next() * 2 - 1) * noise
            let y = center.y + translation.y * progress + spread * currentScale * sin(angle)
                + (random.next() * 2 - 1) * noise
            touches.append(GestureTouch(id: finger, position: CGPoint(x: x, y: y)))
        }
        if hovering {
            touches.append(GestureTouch(id: 99, position: CGPoint(x: 0.9, y: 0.9), isTouching: false))
        }
        frames.append(GestureFrame(timestamp: timestamp, touches: touches))
        timestamp += 1 / rate
    }
    if lifts {
        frames.append(GestureFrame(timestamp: timestamp, touches: []))
    }
    return frames
}

private func run(
    _ frames: [GestureFrame],
    anticipating gestures: [TrackpadGesture],
    flags: CGEventFlags = .empty,
    tolerance: GestureTolerance = .default
) -> [GestureEvent] {
    var state = GestureDetectionState(anticipatedGestures: gestures, tolerance: tolerance, modifierFlags: flags)
    return frames.flatMap { frame in
        state.attach(frame: frame)
        return state.events
    }
}

private func progresses(of events: [GestureEvent]) -> [Double] {
    events.compactMap {
        if case let .changed(_, progress, _, _) = $0 {
            return progress
        }
        return nil
    }
}

private extension GestureEvent {
    var isBegan: Bool {
        if case .began = self {
            return true
        }
        return false
    }

    /// Whether an ended event completed, `nil` for other events
    var completion: Bool? {
        if case let .ended(_, completed, _) = self {
            return completed
        }
        return nil
    }
}

private let swipeUp = TrackpadGesture.swipe(.up, fingers: 3)
private let allSwipes = TrackpadGesture.Direction.allCases.map { TrackpadGesture.swipe($0, fingers: 3) }

@Suite("Trackpad gestures") struct GestureDetectionTests {

    @Test("A swipe begins past the dead zone, progresses monotonically to 1 and completes") func swipe() {
        let frames = hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4))
        var state = GestureDetectionState(anticipatedGestures: [swipeUp])
        var events = [GestureEvent]()
        var travelAtBegin: Double?
        var centroidAtStart: CGFloat?
        for frame in frames {
            state.attach(frame: frame)
            let centroid = frame.touching.map(\.position.y).reduce(0, +) / CGFloat(max(frame.touching.count, 1))
            if centroidAtStart == nil, !frame.touching.isEmpty {
                centroidAtStart = centroid
            }
            if events.isEmpty, state.events.contains(where: { $0.isBegan && $0.gesture == swipeUp }), let centroidAtStart {
                travelAtBegin = centroid - centroidAtStart
            }
            events += state.events
        }
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
        let progress = progresses(of: events)
        #expect(progress == progress.sorted())
        #expect(progress.last == 1)
        #expect(travelAtBegin ?? 0 >= GestureTolerance.default.deadZone)
    }

    @Test("Overshooting past full travel shows in the raw progress alone") func overshoot() {
        var state = GestureDetectionState(anticipatedGestures: [swipeUp])
        var maxProgress = 0.0
        var maxRawProgress = 0.0
        var lastVelocity = 0.0
        for frame in hand(fingers: 3, translation: CGPoint(x: 0, y: 0.6)) {
            state.attach(frame: frame)
            if let active = state.activeGesture {
                maxProgress = max(maxProgress, active.progress)
                maxRawProgress = max(maxRawProgress, active.rawProgress)
            }
            for case let .changed(_, _, rawProgress, velocity) in state.events {
                maxRawProgress = max(maxRawProgress, rawProgress)
                lastVelocity = velocity
            }
        }
        #expect(maxProgress == 1)
        #expect(maxRawProgress > 1.5)
        #expect(lastVelocity > 1)
    }

    @Test("A swipe also recognizes with a short settle and commitment") func tightTolerance() {
        var tolerance = GestureTolerance()
        tolerance.fingerSettleInterval = 0.05
        tolerance.commitmentInterval = 0.02
        let frames = hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), stillBefore: 0.06, stagger: 0.015, noise: 0.004)
        let events = run(frames, anticipating: [swipeUp], tolerance: tolerance)
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
    }

    @Test("A wobbly hand still swipes") func noisySwipe() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), noise: 0.01), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
    }

    @Test("A diagonal movement is no swipe") func diagonal() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0.3, y: 0.3)), anticipating: allSwipes)
        #expect(events.isEmpty)
    }

    @Test("A swipe lifted short of its travel ends without completing") func shortSwipe() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.1)), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == false)
        #expect(progresses(of: events).last ?? 1 < 1)
    }

    @Test("A flick completes before its travel") func flick() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.15), duration: 0.1), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
        #expect(progresses(of: events).last ?? 1 < 1)
    }

    @Test("Fingers landing one after another all count") func staggeredLanding() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), stagger: 0.025), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
    }

    @Test("Hovering fingers take no part") func hovering() {
        let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), hovering: true), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
    }

    @Test("A finger lifting mid-gesture ends it by its progress") func fingerLifts() {
        // Slowly, so that the lift is no flick
        let frames = hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), duration: 1.2, lifts: false)
        // Two fingers remain from halfway through the movement on
        let cut = frames.count / 2
        let interrupted = frames[..<cut] + frames[cut...].map {
            GestureFrame(timestamp: $0.timestamp, touches: Array($0.touches.dropLast()))
        }
        let events = run(Array(interrupted), anticipating: [swipeUp])
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == false)
    }

    @Test("The number of fingers has to match") func fingerCount() {
        let events = run(hand(fingers: 4, translation: CGPoint(x: 0, y: 0.4)), anticipating: [swipeUp])
        #expect(events.isEmpty)
    }

    @Test("Pinches open and close") func pinch() {
        let opening = TrackpadGesture.pinch(.opening, fingers: 2)
        let closing = TrackpadGesture.pinch(.closing, fingers: 2)
        let opened = run(hand(fingers: 2, scale: 2), anticipating: [opening, closing])
        #expect(opened.first?.isBegan == true && opened.first?.gesture == opening)
        #expect(opened.last?.gesture == opening && opened.last?.completion == true)
        let closed = run(hand(fingers: 2, spread: 0.2, scale: 0.5), anticipating: [opening, closing])
        #expect(closed.first?.isBegan == true && closed.first?.gesture == closing)
        #expect(closed.last?.gesture == closing && closed.last?.completion == true)
    }

    @Test("Rotations turn both ways") func rotation() {
        let counterclockwise = TrackpadGesture.rotate(.counterclockwise, fingers: 2)
        let clockwise = TrackpadGesture.rotate(.clockwise, fingers: 2)
        let turnedLeft = run(hand(fingers: 2, rotation: 70), anticipating: [clockwise, counterclockwise])
        #expect(turnedLeft.first?.isBegan == true && turnedLeft.first?.gesture == counterclockwise)
        #expect(turnedLeft.last?.gesture == counterclockwise && turnedLeft.last?.completion == true)
        let turnedRight = run(hand(fingers: 2, rotation: -70), anticipating: [clockwise, counterclockwise])
        #expect(turnedRight.first?.isBegan == true && turnedRight.first?.gesture == clockwise)
        #expect(turnedRight.last?.gesture == clockwise && turnedRight.last?.completion == true)
    }

    @Test("A tap lands and lifts without moving") func tap() {
        let tap = TrackpadGesture.tap(fingers: 3)
        let tapped = run(hand(fingers: 3, stillBefore: 0.05, duration: 0.1), anticipating: [tap])
        #expect(tapped.count == 2)
        #expect(tapped.first?.isBegan == true && tapped.first?.gesture == tap)
        #expect(tapped.last?.gesture == tap && tapped.last?.completion == true)
        let moved = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.05), stillBefore: 0.05, duration: 0.1), anticipating: [tap])
        #expect(moved.isEmpty)
        let held = run(hand(fingers: 3, stillBefore: 0.3, duration: 0.2), anticipating: [tap])
        #expect(held.isEmpty)
    }

    @Test("Modifier keys are part of the gesture") func modifierFlags() {
        let commandSwipeUp = CGEventFlags.maskCommand + swipeUp
        let frames = hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4))
        #expect(run(frames, anticipating: [commandSwipeUp]).isEmpty)
        let withCommand = run(frames, anticipating: [commandSwipeUp], flags: [.maskCommand, .maskNonCoalesced])
        #expect(withCommand.first?.isBegan == true && withCommand.first?.gesture == commandSwipeUp)
        #expect(run(frames, anticipating: [swipeUp], flags: .maskCommand).isEmpty)
    }

    @Test("Frame rate makes no difference") func frameRate() {
        for rate in [50.0, 120.0] {
            let events = run(hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4), rate: rate), anticipating: [swipeUp])
            #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
            #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
            #expect(progresses(of: events).last == 1)
        }
    }

    @Test("Frames stopping mid-gesture end it without completing") func timeout() {
        var state = GestureDetectionState(anticipatedGestures: [swipeUp])
        for frame in hand(fingers: 3, translation: CGPoint(x: 0, y: 0.2), lifts: false) {
            state.attach(frame: frame)
        }
        #expect(state.activeGesture?.gesture == swipeUp)
        state.timeOut()
        #expect(state.events.count == 1)
        #expect(state.events.first?.gesture == swipeUp && state.events.first?.completion == false)
        #expect(state.activeGesture == nil)
    }

    @Test("The detector streams the events") func detector() async {
        let detector = TrackpadGestureDetector(anticipatingInput: [swipeUp])
        for frame in hand(fingers: 3, translation: CGPoint(x: 0, y: 0.4)) {
            await detector.process(frame: frame)
        }
        var events = [GestureEvent]()
        for await event in detector.events {
            events.append(event)
            if case .ended = event {
                break
            }
        }
        #expect(events.first?.isBegan == true && events.first?.gesture == swipeUp)
        #expect(events.last?.gesture == swipeUp && events.last?.completion == true)
    }
}
