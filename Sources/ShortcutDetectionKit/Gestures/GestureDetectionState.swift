import CoreGraphics
import Foundation

/// What a ``TrackpadGestureDetector`` knows after a frame: the gesture under way, if any, and what the frame told about it.
///
/// Recognition follows the fingers' common centre, their mean distance from it (the spread) and their turn around it, so
/// that fingers moving at different speeds average out. A gesture begins once one of those has left its dead zone in a way
/// that matches an anticipated gesture, reports its progress with every frame, and ends when a finger lifts: completed if
/// it travelled far enough or was flicked, abandoned otherwise.
public struct GestureDetectionState: Sendable, Equatable {

    /// A gesture under way
    public struct ActiveGesture: Sendable, Equatable {
        public let gesture: TrackpadGesture
        /// 0 at the dead zone, 1 at full travel, never beyond
        public let progress: Double
        /// The raw signed travel in the gesture's own units: trackpad widths for a swipe, the natural log of the spread
        /// ratio for a pinch, degrees for a rotation. Goes beyond full travel, and below the dead zone, where `progress`
        /// stops.
        public let displacement: Double
        /// The speed along the gesture, in its units per second
        public let velocity: Double
        /// `progress` before clamping: below 0 before the dead zone, beyond 1 past full travel, for whatever follows the
        /// gesture on screen to rubber-band with
        public let rawProgress: Double
    }

    public var anticipatedGestures: Set<TrackpadGesture>
    public let tolerance: GestureTolerance
    /// The raw modifier flags held, overhead bits removed, read when a gesture begins
    public var modifierFlags: UInt64
    public private(set) var activeGesture: ActiveGesture?
    /// What the last frame told, in order
    public private(set) var events: [GestureEvent] = []

    private var session: Session?

    public init<S: Sequence>(
        anticipatedGestures: S,
        tolerance: GestureTolerance = .default,
        modifierFlags: CGEventFlags = .empty
    ) where S.Element == TrackpadGesture {
        self.anticipatedGestures = Set(anticipatedGestures)
        self.tolerance = tolerance
        self.modifierFlags = flags(of: modifierFlags)
    }

    public mutating func attach(frame: GestureFrame) {
        events = []
        let touching = frame.touching
        guard var session else {
            if !touching.isEmpty {
                self.session = Session(firstFrameAt: frame.timestamp, touches: touching)
            }
            return
        }
        if touching.isEmpty {
            end(&session, at: frame.timestamp)
            self.session = nil
            activeGesture = nil
            return
        }
        if case let .recognizing(gesture) = session.phase, touching.count != session.fingerCount {
            // A finger lifted or landed: the gesture is over, however the rest go on. Decided before measuring the frame,
            // whose centre jumps with the finger and would look like a flick.
            events.append(.ended(
                gesture, completed: isCompleted(gesture, in: session), velocity: velocity(of: gesture, in: session)
            ))
            session.phase = .unrecognized
        }
        session.measure(touching, at: frame.timestamp)
        let isSettling = frame.timestamp - session.startTimestamp < tolerance.fingerSettleInterval
        switch session.phase {
            case .settling:
                session.fingerCount = max(session.fingerCount, touching.count)
                // The references follow the fingers while they land
                session.takeReferences()
                if !isSettling {
                    session.phase = session.fingerCount >= 2 && touching.count == session.fingerCount
                        ? .candidate
                        : .unrecognized
                }
            case .candidate:
                if touching.count == session.fingerCount {
                    classify(&session)
                } else {
                    session.phase = .unrecognized
                }
            case let .recognizing(gesture):
                follow(gesture, in: &session)
            case .unrecognized:
                break
        }
        self.session = session
        activeGesture = currentGesture(in: session)
    }

    /// Forgets the fingers, as if they had all lifted without a gesture
    public mutating func reset() {
        session = nil
        activeGesture = nil
        events = []
    }

    /// Ends the gesture under way as not completed, for when frames stopped coming
    public mutating func timeOut() {
        events = []
        if case let .recognizing(gesture)? = session?.phase {
            events.append(.ended(gesture, completed: false, velocity: 0))
        }
        session = nil
        activeGesture = nil
    }

    // MARK: - Recognition

    /// Decides what the fingers do once any of the dead zones is left
    private mutating func classify(_ session: inout Session) {
        let travel = session.travel
        let lnSpreadRatio = session.lnSpreadRatio
        let turn = session.turn
        var passed = [(score: Double, kind: TrackpadGesture.Kind?)]()
        if hypot(travel.x, travel.y) >= tolerance.deadZone {
            passed.append((hypot(travel.x, travel.y) / tolerance.swipeDistance, direction(of: travel).map { .swipe($0) }))
        }
        if abs(lnSpreadRatio) >= log(1 + tolerance.pinchDeadZone) {
            passed.append((abs(lnSpreadRatio) / log(tolerance.pinchRatio), .pinch(lnSpreadRatio > 0 ? .opening : .closing)))
        }
        if abs(turn) >= tolerance.rotationDeadZone {
            passed.append((abs(turn) / tolerance.rotationAngle, .rotate(turn > 0 ? .counterclockwise : .clockwise)))
        }
        // Noise crosses a dead zone for a frame; a hand that means it stays across
        guard !passed.isEmpty else {
            session.deadZoneLeftAt = nil
            return
        }
        guard let deadZoneLeftAt = session.deadZoneLeftAt else {
            session.deadZoneLeftAt = session.lastTimestamp
            return
        }
        guard session.lastTimestamp - deadZoneLeftAt >= tolerance.commitmentInterval else {
            return
        }
        // The kind that got furthest, relative to its full travel, is what the hand means
        for candidate in passed.sorted(by: { $0.score > $1.score }) {
            guard let kind = candidate.kind else {
                // A swipe off every axis stays undecided until it commits to one
                continue
            }
            guard let gesture = anticipatedGesture(fingers: session.fingerCount, kind: kind) else {
                session.phase = .unrecognized
                return
            }
            session.phase = .recognizing(gesture)
            let (displacement, progress, rawProgress) = measure(gesture, in: session)
            session.lastDisplacement = displacement
            session.lastProgress = progress
            session.lastRawProgress = rawProgress
            events.append(.began(gesture))
            return
        }
    }

    private mutating func follow(_ gesture: TrackpadGesture, in session: inout Session) {
        let (displacement, progress, rawProgress) = measure(gesture, in: session)
        guard abs(displacement - session.lastDisplacement) >= jitter(of: gesture) else {
            return
        }
        session.lastDisplacement = displacement
        session.lastProgress = progress
        session.lastRawProgress = rawProgress
        events.append(.changed(
            gesture, progress: progress, rawProgress: rawProgress, velocity: velocity(of: gesture, in: session)
        ))
    }

    /// Every finger lifted
    private mutating func end(_ session: inout Session, at timestamp: TimeInterval) {
        switch session.phase {
            case let .recognizing(gesture):
                events.append(.ended(
                    gesture, completed: isCompleted(gesture, in: session), velocity: velocity(of: gesture, in: session)
                ))
            case .settling, .candidate:
                guard session.fingerCount >= 2,
                      timestamp - session.startTimestamp <= tolerance.tapMaximumDuration,
                      session.maxTravelFromStart <= tolerance.tapMaximumTravel,
                      let tap = anticipatedGesture(fingers: session.fingerCount, kind: .tap) else {
                    return
                }
                events.append(.began(tap))
                events.append(.ended(tap, completed: true, velocity: 0))
            case .unrecognized:
                break
        }
    }

    private func isCompleted(_ gesture: TrackpadGesture, in session: Session) -> Bool {
        if session.lastProgress >= tolerance.completionProgress {
            return true
        }
        let flickRate: Double = switch gesture.kind {
            case .swipe:
                tolerance.flickVelocity
            case .pinch:
                tolerance.pinchFlickRate
            case .rotate:
                tolerance.rotationFlickRate
            case .tap:
                .infinity
        }
        return session.lastProgress >= tolerance.flickMinimumProgress && velocity(of: gesture, in: session) >= flickRate
    }

    private func currentGesture(in session: Session) -> ActiveGesture? {
        guard case let .recognizing(gesture) = session.phase else {
            return nil
        }
        return ActiveGesture(
            gesture: gesture,
            progress: session.lastProgress,
            displacement: session.lastDisplacement,
            velocity: velocity(of: gesture, in: session),
            rawProgress: session.lastRawProgress
        )
    }

    private func anticipatedGesture(fingers: Int, kind: TrackpadGesture.Kind) -> TrackpadGesture? {
        anticipatedGestures.first { $0.fingers == fingers && $0.kind == kind && $0.flags == modifierFlags }
    }

    // MARK: - Geometry

    /// The signed travel along the gesture, and the progress it amounts to
    private func measure(
        _ gesture: TrackpadGesture, in session: Session
    ) -> (displacement: Double, progress: Double, rawProgress: Double) {
        let (displacement, deadZone, fullTravel): (Double, Double, Double) = switch gesture.kind {
            case let .swipe(direction):
                (Self.component(of: session.travel, along: direction), tolerance.deadZone, tolerance.swipeDistance)
            case .pinch(.opening):
                (session.lnSpreadRatio, log(1 + tolerance.pinchDeadZone), log(tolerance.pinchRatio))
            case .pinch(.closing):
                (-session.lnSpreadRatio, log(1 + tolerance.pinchDeadZone), log(tolerance.pinchRatio))
            case .rotate(.counterclockwise):
                (session.turn, tolerance.rotationDeadZone, tolerance.rotationAngle)
            case .rotate(.clockwise):
                (-session.turn, tolerance.rotationDeadZone, tolerance.rotationAngle)
            case .tap:
                (1, 0, 1)
        }
        let rawProgress = (displacement - deadZone) / max(fullTravel - deadZone, .ulpOfOne)
        return (displacement, min(max(rawProgress, 0), 1), rawProgress)
    }

    private func velocity(of gesture: TrackpadGesture, in session: Session) -> Double {
        switch gesture.kind {
            case let .swipe(direction):
                Self.component(of: session.velocity, along: direction)
            case .pinch(.opening):
                session.spreadRate
            case .pinch(.closing):
                -session.spreadRate
            case .rotate(.counterclockwise):
                session.turnRate
            case .rotate(.clockwise):
                -session.turnRate
            case .tap:
                0
        }
    }

    private func jitter(of gesture: TrackpadGesture) -> Double {
        switch gesture.kind {
            case .swipe:
                tolerance.jitter
            case .pinch:
                tolerance.pinchJitter
            case .rotate:
                tolerance.rotationJitter
            case .tap:
                0
        }
    }

    /// The axis `travel` points along, if it lies within the direction tolerance of one
    private func direction(of travel: CGPoint) -> TrackpadGesture.Direction? {
        let angle = atan2(travel.y, travel.x) * 180 / .pi
        return TrackpadGesture.Direction.allCases.first { direction in
            let axis: Double = switch direction {
                case .right: 0
                case .up: 90
                case .left: 180
                case .down: -90
            }
            var difference = (angle - axis).truncatingRemainder(dividingBy: 360)
            if difference > 180 { difference -= 360 }
            if difference < -180 { difference += 360 }
            return abs(difference) <= tolerance.directionTolerance
        }
    }

    private static func component(of vector: CGPoint, along direction: TrackpadGesture.Direction) -> Double {
        switch direction {
            case .up: vector.y
            case .down: -vector.y
            case .right: vector.x
            case .left: -vector.x
        }
    }
}

private func flags(of eventFlags: CGEventFlags) -> UInt64 {
    eventFlags.subtracting(KeystrokeSequence.ignoredFlags).rawValue
}

/// The fingers from the first landing to the last lifting
private struct Session: Sendable, Equatable {

    enum Phase: Sendable, Equatable {
        /// Fingers are still landing
        case settling
        /// All fingers are down; waiting for them to leave a dead zone
        case candidate
        case recognizing(TrackpadGesture)
        /// Whatever the fingers do, until they all lift
        case unrecognized
    }

    /// Below this spread, fingers sit too close together for a ratio to mean anything
    private static let minimumSpread = 0.01
    /// How much of the previous rate survives into the next, which steadies rates read off two frames
    private static let rateSmoothing = 0.5

    var phase = Phase.settling
    let startTimestamp: TimeInterval
    let startCentroid: CGPoint
    var fingerCount: Int
    var lastTimestamp: TimeInterval

    // What the fingers do now
    var centroid: CGPoint
    var spread: Double
    /// Each finger's angle around the centre, in radians
    var fingerAngles: [Int: Double]

    // Where they started from, taken when the last of them landed
    var referenceCentroid: CGPoint
    var referenceSpread: Double
    var referenceAngles: [Int: Double]

    // Rates, in units per second
    var velocity = CGPoint.zero
    var spreadRate = 0.0
    var turnRate = 0.0

    var maxTravelFromStart = 0.0
    var lastDisplacement = 0.0
    var lastProgress = 0.0
    var lastRawProgress = 0.0
    /// When a dead zone was first found exceeded, for the commitment interval
    var deadZoneLeftAt: TimeInterval?
    /// The spread and turn lightly smoothed over frames, which takes the edge off sensor noise and finger rolling
    var smoothedSpread: Double
    var smoothedTurn = 0.0

    init(firstFrameAt timestamp: TimeInterval, touches: [GestureTouch]) {
        let metrics = Self.metrics(of: touches)
        startTimestamp = timestamp
        startCentroid = metrics.centroid
        fingerCount = touches.count
        lastTimestamp = timestamp
        centroid = metrics.centroid
        spread = metrics.spread
        fingerAngles = metrics.angles
        referenceCentroid = metrics.centroid
        referenceSpread = metrics.spread
        referenceAngles = metrics.angles
        smoothedSpread = metrics.spread
    }

    var travel: CGPoint {
        CGPoint(x: centroid.x - referenceCentroid.x, y: centroid.y - referenceCentroid.y)
    }

    var lnSpreadRatio: Double {
        referenceSpread > Self.minimumSpread && smoothedSpread > 0 ? log(smoothedSpread / referenceSpread) : 0
    }

    var turn: Double {
        smoothedTurn
    }

    /// How far the fingers turned around their centre since the references were taken, in degrees, counterclockwise
    /// positive: the mean over the fingers of how far each is from where it was, which keeps sensor noise from adding up
    /// the way summing frame-to-frame turns would
    private var rawTurn: Double {
        let deltas = fingerAngles.compactMap { id, angle -> Double? in
            guard let reference = referenceAngles[id] else {
                return nil
            }
            var delta = angle - reference
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            return delta
        }
        guard deltas.count >= 2 else {
            return 0
        }
        return deltas.reduce(0, +) / Double(deltas.count) * 180 / .pi
    }

    /// Starts measuring from where the fingers are now. Smoothing starts afresh as well, so that a finger that landed a
    /// moment ago leaves no lag behind to look like a slow pinch.
    mutating func takeReferences() {
        referenceCentroid = centroid
        referenceSpread = spread
        referenceAngles = fingerAngles
        smoothedSpread = spread
        smoothedTurn = 0
        deadZoneLeftAt = nil
    }

    /// Updates centre, spread, turn and their rates from the fingers of a new frame
    mutating func measure(_ touches: [GestureTouch], at timestamp: TimeInterval) {
        let metrics = Self.metrics(of: touches)
        let dt = timestamp - lastTimestamp
        let previousTurn = smoothedTurn
        let previousCentroid = centroid
        let previousSpread = smoothedSpread
        centroid = metrics.centroid
        spread = metrics.spread
        fingerAngles = metrics.angles
        smoothedSpread = Self.smoothed(smoothedSpread, spread)
        smoothedTurn = Self.smoothed(smoothedTurn, rawTurn)
        lastTimestamp = timestamp
        if dt > 0 {
            velocity = CGPoint(
                x: Self.smoothed(velocity.x, (centroid.x - previousCentroid.x) / dt),
                y: Self.smoothed(velocity.y, (centroid.y - previousCentroid.y) / dt)
            )
            if previousSpread > Self.minimumSpread, smoothedSpread > 0 {
                spreadRate = Self.smoothed(spreadRate, log(smoothedSpread / previousSpread) / dt)
            }
            turnRate = Self.smoothed(turnRate, (smoothedTurn - previousTurn) / dt)
        }
        maxTravelFromStart = max(
            maxTravelFromStart, hypot(centroid.x - startCentroid.x, centroid.y - startCentroid.y)
        )
    }

    private static func smoothed(_ previous: Double, _ current: Double) -> Double {
        previous * rateSmoothing + current * (1 - rateSmoothing)
    }

    private static func metrics(of touches: [GestureTouch]) -> (centroid: CGPoint, spread: Double, angles: [Int: Double]) {
        let count = Double(touches.count)
        var sumX = 0.0
        var sumY = 0.0
        for touch in touches {
            sumX += Double(touch.position.x)
            sumY += Double(touch.position.y)
        }
        let centroid = CGPoint(x: sumX / count, y: sumY / count)
        var spreadSum = 0.0
        var angles = [Int: Double]()
        for touch in touches {
            let dx = Double(touch.position.x) - Double(centroid.x)
            let dy = Double(touch.position.y) - Double(centroid.y)
            spreadSum += (dx * dx + dy * dy).squareRoot()
            if angles[touch.id] == nil {
                angles[touch.id] = atan2(dy, dx)
            }
        }
        return (centroid, spreadSum / count, angles)
    }
}
