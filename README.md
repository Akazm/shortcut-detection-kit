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

## Components

- `KeystrokeSequenceDetector`: Main class for detecting keyboard sequences
- `KeystrokeSequence`: Represents a sequence of keystrokes
- `KeyCode`: Enumeration of commonly known supported key codes
- `KeyboardCharacters`: Mapping of key codes to characters
- `TISInputSourceExtensions`: Extensions for working with keyboard hardware
