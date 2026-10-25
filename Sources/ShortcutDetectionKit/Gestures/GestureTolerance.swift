import Foundation

/// How much a hand may stray from the geometrically perfect gesture and still mean it.
///
/// Distances are fractions of the trackpad's size, since positions come normalized to 0...1. Times are seconds, angles
/// degrees. Nothing counts frames: trackpads deliver anywhere from 50 to 120 of them a second.
public struct GestureTolerance: Sendable, Hashable, Codable {

    // MARK: Fingers

    /// How long after the first finger lands the others may still land and count. Fingers never land together; the number
    /// of fingers is the most touching within this window, and nothing is classified before it has passed.
    public var fingerSettleInterval: TimeInterval = 0.08

    // MARK: Dead zones, below which nothing begins

    /// How far the fingers' centre has to travel before a swipe begins. Filters hand tremor and fingers shifting as they land.
    public var deadZone: Double = 0.025
    /// How much the fingers' spread has to change, relative to the initial spread, before a pinch begins
    public var pinchDeadZone: Double = 0.06
    /// How far the fingers have to turn before a rotation begins
    public var rotationDeadZone: Double = 10

    /// How long a dead zone has to stay exceeded before a gesture begins. A single frame of noise crossing a dead zone
    /// does not persist; a hand that means it does.
    public var commitmentInterval: TimeInterval = 0.03

    // MARK: Direction

    /// The half-angle of the cone around each axis a swipe must stay in. Movement outside every cone, such as a diagonal,
    /// stays undecided until it commits to an axis.
    public var directionTolerance: Double = 35

    // MARK: Full travel, where progress reaches 1

    public var swipeDistance: Double = 0.35
    /// The spread ratio, final over initial, of a complete pinch; its inverse for a closing one
    public var pinchRatio: Double = 1.6
    public var rotationAngle: Double = 60

    // MARK: Completion

    /// The progress at which lifting the fingers completes the gesture
    public var completionProgress: Double = 1
    /// Fingers lifted while still moving at least this fast, in trackpad widths per second, complete a swipe early
    public var flickVelocity: Double = 0.8
    /// Fingers lifted while the spread changes at least this fast, in natural log units of the ratio per second, complete a
    /// pinch early
    public var pinchFlickRate: Double = 2
    /// Fingers lifted while turning at least this fast, in degrees per second, complete a rotation early
    public var rotationFlickRate: Double = 180
    /// A flick only completes a gesture that got at least this far
    public var flickMinimumProgress: Double = 0.15

    // MARK: Noise

    /// Movement of the fingers' centre below this produces no change
    public var jitter: Double = 0.002
    /// Spread changes below this, in natural log units of the ratio, produce no change
    public var pinchJitter: Double = 0.005
    /// Turns below this produce no change
    public var rotationJitter: Double = 0.5

    // MARK: Taps

    /// How long fingers may stay down for a tap
    public var tapMaximumDuration: TimeInterval = 0.3
    /// How far fingers may move during a tap
    public var tapMaximumTravel: Double = 0.02

    // MARK: Interruption

    /// A gesture without a new frame for this long, say because the trackpad disconnected, ends as not completed
    public var frameTimeout: TimeInterval = 0.5

    public init() {}

    public static let `default` = Self()
}
