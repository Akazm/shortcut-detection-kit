import Foundation

/// A type alias for UInt16 representing a key code in the macOS keyboard event system.
///
/// Key codes are used to identify specific keys on the keyboard, regardless of the current
/// keyboard layout or input method. This type provides a set of constants for commonly
/// used keys and key combinations.
public typealias KeyCode = UInt16

public extension KeyCode {
    /// An array of all numeric keypad keys (0-9)
    static let keyPad: [KeyCode] = [
        KeyCode.keypad0,
        KeyCode.keypad1,
        KeyCode.keypad2,
        KeyCode.keypad3,
        KeyCode.keypad4,
        KeyCode.keypad5,
        KeyCode.keypad6,
        KeyCode.keypad7,
        KeyCode.keypad8,
        KeyCode.keypad9
    ]
    
    /// Key code for the numeric keypad 0 key
    static let keypad0: Self = 82
    /// Key code for the numeric keypad 1 key
    static let keypad1: Self = 83
    /// Key code for the numeric keypad 2 key
    static let keypad2: Self = 84
    /// Key code for the numeric keypad 3 key
    static let keypad3: Self = 85
    /// Key code for the numeric keypad 4 key
    static let keypad4: Self = 86
    /// Key code for the numeric keypad 5 key
    static let keypad5: Self = 87
    /// Key code for the numeric keypad 6 key
    static let keypad6: Self = 88
    /// Key code for the numeric keypad 7 key
    static let keypad7: Self = 89
    /// Key code for the numeric keypad 8 key
    static let keypad8: Self = 91
    /// Key code for the numeric keypad 9 key
    static let keypad9: Self = 92
    
    // swiftlint:disable identifier_name
    /// Key code for the 'X' key
    static let x: Self = 7
    /// Key code for the 'C' key
    static let c: Self = 0x08
    /// Key code for the 'V' key
    static let v: Self = 9
    // swiftlint:enable identifier_name
    
    /// Key code for the '0' key
    static let zero: Self = 29
    /// Key code for the '1' key
    static let one: Self = 18
    /// Key code for the '2' key
    static let two: Self = 19
    /// Key code for the '3' key
    static let three: Self = 20
    /// Key code for the '4' key
    static let four: Self = 21
    /// Key code for the '5' key
    static let five: Self = 23
    /// Key code for the '6' key
    static let six: Self = 22
    /// Key code for the '7' key
    static let seven: Self = 26
    /// Key code for the '8' key
    static let eight: Self = 28
    /// Key code for the '9' key
    static let nine: Self = 25
    
    /// Key code for the numeric keypad decimal point key
    static let keypadDecimal: Self = 65
    /// Key code for the numeric keypad multiply key
    static let keypadMultiply: Self = 67
    /// Key code for the numeric keypad plus key
    static let keypadPlus: Self = 69
    /// Key code for the numeric keypad divide key
    static let keypadDivide: Self = 75
    /// Key code for the numeric keypad minus key
    static let keypadMinus: Self = 78
    /// Key code for the numeric keypad equals key
    static let keypadEquals: Self = 81
    /// Key code for the numeric keypad clear key
    static let keypadClear: Self = 71
    /// Key code for the numeric keypad enter key
    static let keypadEnter: Self = 76
    
    /// Key code for the space key
    static let space: Self = 49
    /// Key code for the return key
    static let `return`: Self = 36
    /// Key code for the tab key
    static let tab: Self = 48
    /// Key code for the delete/backspace key
    static let delete: Self = 51
    /// Key code for the forward delete key
    static let forwardDelete: Self = 117
    /// Key code for the line feed key
    static let linefeed: Self = 52
    /// Key code for the escape key
    static let escape: Self = 53
    /// Key code for the command key
    static let command: Self = 55
    /// Key code for the shift key
    static let shift: Self = 56
    /// Key code for the caps lock key
    static let capsLock: Self = 57
    /// Key code for the option/alt key
    static let option: Self = 58
    /// Key code for the control key
    static let control: Self = 59
    /// Key code for the right shift key
    static let rightShift: Self = 60
    /// Key code for the right option/alt key
    static let rightOption: Self = 61
    /// Key code for the right control key
    static let rightControl: Self = 62
    /// Key code for the function key
    static let function: Self = 63
    
    /// Key code for the help/insert key
    static let helpInsert: Self = 114
    /// Key code for the home key
    static let home: Self = 115
    /// Key code for the end key
    static let end: Self = 119
    /// Key code for the page up key
    static let pageUp: Self = 116
    /// Key code for the page down key
    static let pageDown: Self = 121
    /// Key code for the left arrow key
    static let leftArrow: Self = 123
    /// Key code for the right arrow key
    static let rightArrow: Self = 124
    /// Key code for the down arrow key
    static let downArrow: Self = 125
    /// Key code for the up arrow key
    static let upArrow: Self = 126
    
    // swiftlint:disable identifier_name
    /// Key code for the F1 function key
    static let f1: Self = 122
    /// Key code for the F2 function key
    static let f2: Self = 120
    /// Key code for the F3 function key
    static let f3: Self = 99
    /// Key code for the F4 function key
    static let f4: Self = 118
    /// Key code for the F5 function key
    static let f5: Self = 96
    /// Key code for the F6 function key
    static let f6: Self = 97
    /// Key code for the F7 function key
    static let f7: Self = 98
    /// Key code for the F8 function key
    static let f8: Self = 100
    /// Key code for the F9 function key
    static let f9: Self = 101
    // swiftlint:enable identifier_name
    
    /// Key code for the F10 function key
    static let f10: Self = 109
    /// Key code for the F11 function key
    static let f11: Self = 103
    /// Key code for the F12 function key
    static let f12: Self = 111
    /// Key code for the F13 function key
    static let f13: Self = 105
    /// Key code for the F14 function key
    static let f14: Self = 107
    /// Key code for the F15 function key
    static let f15: Self = 113
    /// Key code for the F16 function key
    static let f16: Self = 106
    /// Key code for the F17 function key
    static let f17: Self = 64
    /// Key code for the F18 function key
    static let f18: Self = 79
    /// Key code for the F19 function key
    static let f19: Self = 80
    /// Key code for the F20 function key
    static let f20: Self = 90
}
