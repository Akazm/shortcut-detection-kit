import Carbon
import Foundation

/// Extensions for working with Text Input Source (TIS) framework on macOS.
///
/// These extensions provide convenient access to input source properties and functionality
/// for working with keyboard layouts and input methods.
extension TISInputSource {
    /// Categories of input sources in the Text Input Source framework.
    enum Category {
        /// The category identifier for keyboard input sources.
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }

    /// Retrieves a property value from the input source.
    /// - Parameter key: The property key to retrieve
    /// - Returns: The property value, if available
    private func getProperty(_ key: CFString) -> AnyObject? {
        let cfType = TISGetInputSourceProperty(self, key)
        if cfType != nil {
            return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue()
        } else {
            return nil
        }
    }

    // swiftlint:disable force_cast
    /// The unique identifier of the input source.
    var id: String {
        getProperty(kTISPropertyInputSourceID) as! String
    }

    /// The localized name of the input source.
    var name: String {
        getProperty(kTISPropertyLocalizedName) as! String
    }

    /// The category of the input source.
    var category: String {
        getProperty(kTISPropertyInputSourceCategory) as! String
    }

    /// Whether the input source can be selected by the user.
    var isSelectable: Bool {
        getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }

    /// Whether the input source is currently active.
    var isActive: Bool {
        getProperty(kTISPropertyInputSourceIsEnabled) as! Bool
    }

    /// The languages supported by this input source.
    var sourceLanguages: [String] {
        getProperty(kTISPropertyInputSourceLanguages) as! [String]
    }

    /// The URL to the icon image for this input source.
    var iconImageURL: URL? {
        getProperty(kTISPropertyIconImageURL) as! URL?
    }

    /// The type of the input source.
    var inputSourceType: String {
        getProperty(kTISPropertyInputSourceType) as! String
    }
    // swiftlint:enable force_cast

    /// The icon reference for this input source.
    var iconRef: IconRef? {
        OpaquePointer(TISGetInputSourceProperty(self, kTISPropertyIconRef)) as IconRef?
    }
}
