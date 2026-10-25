# ShortcutDetectionKit

A Swift library for parsing keyboard shortcuts and keystroke sequences on macOS.

## Overview

ShortcutDetectionKit provides a robust solution for detecting and handling keyboard shortcuts and keystroke sequences in macOS applications. It offers a modern, Swift-native API that leverages async/await for efficient event handling.

## Features

- Detect keyboard shortcuts and keystroke sequences
- Support for key combinations
- Modern Swift concurrency with async/await
- Thread-safe
- Comprehensive key code and character mapping

## Requirements

- macOS 10.15 or later
- Swift 6.0 or later

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/akazm/shortcut-detection-kit.git", from: "1.0.0")
]
```

## Usage

```swift
import ShortcutDetectionKit

// Define a shortcut to detect
let shortcut = KeystrokeSequence(flags: [.command, .shift], keys: [.a, .a])

// Alternatively
let shortcut: KeystrokeSequence = [CGEventFlags.command, .shift] + [KeyCode.a, .a]

// Create a keystroke sequence detector
let detector = KeystrokeSequenceDetector(anticipatingInput: [shortcut])

// Process a CGEvent
let nextDetectionState = detector.process(cgEvent: e)

// Get the matched KeystrokeSequence (`nil` when the previously processed event didn't match on any anticipated state)  
let matchingStroke = nextDetectionState.matchingKeystrokeSequence

// If required, reset the detector to an empty state
detector.reset()
```

### Modifier taps

Modifier keys (⌃, ⌥, ⌘, ⇧, fn) contribute flags only by default. Opt into `ModifierKeyInterpretation.modifierAndKey` to also
treat a modifier key that is pressed and released on its own - a *tap* - as a keystroke:

```swift
// Double tap on ⌃, i.e. KeystrokeSequence(flags: [], keys: [.control, .control])
let doubleTapControl = KeystrokeSequence(tapping: .control)

let detector = KeystrokeSequenceDetector(
    autoresetInterval: 0.3, // Longest hold of a tap and longest pause between two taps
    anticipatingInput: [doubleTapControl],
    modifierKeyInterpretation: .modifierAndKey
)
```

Left and right modifier keys are told apart (`.control` vs. `.rightControl`). Modifier shortcuts such as ⌘⌥← keep
working as before.

### Trackpad gestures

`TrackpadGestureDetector` recognizes swipes, pinches, rotations and taps of two to five fingers, with the modifier keys
held, from frames of finger positions. It depends on no event source: map whatever delivers touches, such as TapGuard's
`MultitouchDispatcher`, into `GestureFrame`s.

```swift
let detector = TrackpadGestureDetector(
    anticipatingInput: [.swipe(.up, fingers: 3), CGEventFlags.maskCommand + .pinch(.opening, fingers: 2)],
    tolerance: .default // Dead zones, direction cones, full travel, flick speeds, tap limits
)

// Feed every frame; positions are in 0...1 of the trackpad with the origin at the bottom left
let state = await detector.process(frame: GestureFrame(
    timestamp: frame.timestamp,
    touches: frame.touches.map { GestureTouch(id: Int($0.identifier), position: $0.position, isTouching: $0.isTouching) }
))
if let active = state.activeGesture {
    print(active.gesture, active.progress) // 0 at the dead zone, 1 at full travel
}

// Or follow the events: began, changed(progress, rawProgress, velocity), ended(completed, velocity)
for await event in detector.events { ... }

// Modifier keys are not part of the frames
await detector.setModifierFlags(cgEvent.flags)
```

A gesture begins once the fingers leave a dead zone in a way that matches an anticipated gesture, reports its progress with
every frame, and ends when a finger lifts: completed if it travelled far enough or was flicked, abandoned otherwise, so that
whatever followed it on screen can return to where it started. `GestureTolerance` holds every allowance made for a real hand.

## Components

- `KeystrokeSequenceDetector`: Main class for detecting keyboard sequences
- `KeystrokeSequence`: Represents a sequence of keystrokes
- `KeyCode`: Enumeration of commonly known supported key codes
- `KeyboardCharacters`: Mapping of key codes to characters
- `TISInputSourceExtensions`: Extensions for working with keyboard hardware

## Documentation

[View documentation](https://akazm.github.io/shortcut-detection-kit/documentation/shortcutdetectionkit/)