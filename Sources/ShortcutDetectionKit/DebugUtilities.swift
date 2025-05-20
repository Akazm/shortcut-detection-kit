extension OptionSet where RawValue: FixedWidthInteger {
    
    /// Returns an array of individual elements (bit flags) contained in the set
    var options: [Self] {
        var options: [Self] = []
        var raw = self.rawValue
        var bit: RawValue = 1

        while raw != 0 {
            if raw & bit != 0 {
                options.append(Self(rawValue: bit))
                raw &= ~bit
            }
            bit = bit << 1
        }

        return options
    }
    
}