import Foundation
import CoreGraphics
import Carbon

public final class KeyboardCharacters {
    private init() {}

    // swiftlint:disable cyclomatic_complexity
    private static func toModifierKeyString(char: UniChar) -> String? {
        switch char {
        case 54, 55:
            return "⌘"
        case 63:
            return "fn"
        case 53:
            return "⎋"
        case 56, 60:
            return "⇧"
        case 57:
            return "⇪"
        case 58, 61:
            return "⌥"
        case 59:
            return "⌃"
        case 48:
            return "⇥"
        case 71:
            return "⌧"
        case 117:
            return "⌦"
        case 49:
            return "␣"
        case 116:
            return "⇞"
        case 121:
            return "⇟"
        case 115:
            return "⇱"
        case 51:
            return "⌫"
        case 119:
            return "⇲"
        case 122:
            return "F1"
        case 120:
            return "F2"
        case 99:
            return "F3"
        case 118:
            return "F4"
        case 96:
            return "F5"
        case 97:
            return "F6"
        case 98:
            return "F7"
        case 100:
            return "F8"
        case 101:
            return "F9"
        case 109:
            return "F10"
        case 103:
            return "F11"
        case 111:
            return "F12"
        case 105:
            return "F13"
        case 107:
            return "F14"
        case 113:
            return "F15"
        case 106:
            return "F16"
        case 64:
            return "F17"
        case 79:
            return "F18"
        case 80:
            return "F19"
        case 90:
            return "F20"
        case 36:
            return "⏎"
        case 76:
            return "⌤"
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        default:
            return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity

    /// Converts `.maskShift`, `.maskCommand`, `.maskAlternate` and `.maskControl` to `String`
    @MainActor
    public static func keyboardCharactersFor(eventFlags: CGEventFlags) -> String {
        """
        \(eventFlags.contains(.maskShift) ? "⇧" : "")
        \(eventFlags.contains(.maskCommand) ? "⌘" : "")
        \(eventFlags.contains(.maskAlternate) ? "⌥" : "")
        \(eventFlags.contains(.maskControl) ? "^" : "")
        """.replacingOccurrences(of: "\n", with: "")
    }

    @inline(__always)
    @MainActor
    public static func getLayoutData(
        bcp47Locale locale: String
    ) -> Data? {
        let sourceList: [TISInputSource]? = TISCreateInputSourceList(
            [:] as CFDictionary,
            true
        )?.takeRetainedValue() as? [TISInputSource]
        guard let sourceList else {
            return nil
        }
        for source in sourceList {
            if source.category != TISInputSource.Category.keyboardInputSource {
                continue
            }
            if !source.sourceLanguages.contains(locale) {
                continue
            }
            if source.inputSourceType != kTISTypeKeyboardLayout as String,
               source.inputSourceType != kTISTypeKeyboardInputMethodModeEnabled as String {
                continue
            }
            if source.sourceLanguages.contains(locale),
               let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
                return Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
            }
        }
        return nil
    }

    @inline(__always)
    @MainActor
    public static func attributedCharacter(
        forKey key: UniChar,
        flags: CGEventFlags,
        layoutData: Data,
        numpadPrefix: NSAttributedString = .init(string: "﹟")
    ) -> NSAttributedString? {
        if let modifierKey = toModifierKeyString(char: key) {
            return NSAttributedString(string: modifierKey)
        }
        var carbonFlags = 0
        if flags.contains(.maskShift) || flags.contains(.maskAlphaShift) {
            carbonFlags |= Carbon.shiftKey
        }
        if flags.contains(.maskControl) {
            carbonFlags |= Carbon.controlKey
        }
        if flags.contains(.maskAlternate) {
            carbonFlags |= Carbon.optionKey
        }
        if flags.contains(.maskCommand) {
            carbonFlags |= Carbon.cmdKey
        }
        let maxNameLength = 256
        var nameBuffer = [UniChar](repeating: 0, count: maxNameLength)
        var nameLength = 0
        let modifierKeys = UInt32(carbonFlags >> 8)
        var deadKeys: UInt32 = 0
        let keyboardType = UInt32(LMGetKbdType())
        let osStatus = layoutData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            UCKeyTranslate(
                pointer.bindMemory(to: UCKeyboardLayout.self).baseAddress,
                key,
                UInt16(CoreServices.kUCKeyActionDisplay),
                modifierKeys,
                keyboardType,
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeys,
                maxNameLength,
                &nameLength,
                &nameBuffer
            )
        }
        guard osStatus == noErr else {
            return nil
        }
        if KeyCode.keyPad.contains(key) {
            let mutableString = NSMutableAttributedString()
            mutableString.append(numpadPrefix)
            mutableString.append(
                .init(
                    string: String(
                        utf16CodeUnits: nameBuffer,
                        count: nameLength
                    ).uppercased()
                )
            )
            return mutableString
        }
        return .init(
            string: .init(
                utf16CodeUnits: nameBuffer,
                count: nameLength
            ).uppercased()
        )
    }

    @inline(__always)
    @MainActor
    public static func characterFor(
        key: UniChar,
        flags: CGEventFlags,
        layoutData: Data,
        numpadPrefix: String = "﹟"
    ) -> String? {
        if let modifierKey = toModifierKeyString(char: key) {
            return modifierKey
        }
        var carbonFlags = 0
        if flags.contains(.maskShift) || flags.contains(.maskAlphaShift) {
            carbonFlags |= Carbon.shiftKey
        }
        if flags.contains(.maskControl) {
            carbonFlags |= Carbon.controlKey
        }
        if flags.contains(.maskAlternate) {
            carbonFlags |= Carbon.optionKey
        }
        if flags.contains(.maskCommand) {
            carbonFlags |= Carbon.cmdKey
        }
        let maxNameLength = 256
        var nameBuffer = [UniChar](repeating: 0, count: maxNameLength)
        var nameLength = 0
        let modifierKeys = UInt32(carbonFlags >> 8)
        var deadKeys: UInt32 = 0
        let keyboardType = UInt32(LMGetKbdType())
        let osStatus = layoutData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            UCKeyTranslate(
                pointer.bindMemory(to: UCKeyboardLayout.self).baseAddress,
                key,
                UInt16(CoreServices.kUCKeyActionDisplay),
                modifierKeys,
                keyboardType,
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeys,
                maxNameLength,
                &nameLength,
                &nameBuffer
            )
        }
        guard osStatus == noErr else {
            return nil
        }
        if KeyCode.keyPad.contains(key) {
            return "\(numpadPrefix)\(String(utf16CodeUnits: nameBuffer, count: nameLength))"
        }
        return String(utf16CodeUnits: nameBuffer, count: nameLength)
    }

    /// Converts `key` to the character printed on the user's keyboard. If the passed `flags` are not empty, they'll be applied to
    /// the conversion as well. The built-in macOS keyboard viewer gives a good preview of the expected result.
    @inline(__always)
    @MainActor
    public static func characterFor(
        key: UniChar,
        flags: CGEventFlags,
        bip47Locale locale: String,
        numpadPrefix: String = "﹟"
    ) -> String? {
        guard let layoutData = getLayoutData(bcp47Locale: locale) else {
            return nil
        }
        return characterFor(key: key, flags: flags, layoutData: layoutData, numpadPrefix: numpadPrefix)
    }

    /// Converts `key` to the character printed on the user's keyboard. If the passed `flags` are not empty, they'll be applied to
    /// the conversion as well. The built-in macOS keyboard viewer gives a good preview of the expected result.
    @inline(__always)
    @MainActor
    public static func attributedKeyboardCharacterFor(
        key: UniChar,
        flags: CGEventFlags,
        bip47Locale locale: String,
        numpadPrefix: NSAttributedString = .init(string: "﹟")
    ) -> NSAttributedString? {
        guard let layoutData = getLayoutData(bcp47Locale: locale) else {
            return nil
        }
        return attributedCharacter(
            forKey: key,
            flags: flags,
            layoutData: layoutData,
            numpadPrefix: numpadPrefix
        )
    }

    /// Converts `key` to the character printed on the user's keyboard. If the passed `flags` are not empty, they'll be applied to
    /// the conversion as well. The built-in macOS keyboard viewer gives a good preview of the expected result.
    @inline(__always)
    @MainActor
    public static func keyboardCharacterFor(key: UniChar, flags: CGEventFlags, numpadPrefix: String = "﹟") -> String? {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeUnretainedValue()
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        return characterFor(key: key, flags: flags, layoutData: layoutData, numpadPrefix: numpadPrefix)
    }

    /// Converts `key` to the character printed on the user's keyboard. If the passed `flags` are not empty, they'll be applied to
    /// the conversion as well. The built-in macOS keyboard viewer gives a good preview of the expected result.
    @inline(__always)
    @MainActor
    public static func attributedCharacterFor(
        key: UniChar,
        flags: CGEventFlags,
        numpadPrefix: NSAttributedString = .init(string: "﹟")
    ) -> NSAttributedString? {
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeUnretainedValue()
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        return attributedCharacter(
            forKey: key,
            flags: flags,
            layoutData: layoutData,
            numpadPrefix: numpadPrefix
        )
    }

    @inline(__always)
    @MainActor
    public static func charactersForAllKeys(numpadPrefix: String = "﹟") -> [UInt16: String] {
        let dictionaryEntries = (UniChar.min...UniChar.max)
            .compactMap { keyCode in
                if let character = Self.keyboardCharacterFor(key: keyCode, flags: .empty) {
                    (keyCode: keyCode, character: character)
                } else {
                    nil
                }
            }
        return Dictionary(dictionaryEntries) { key, _ in
            key
        }
    }

}
