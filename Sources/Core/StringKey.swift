public struct StringKey: CodingKey {
    public var stringValue: String
    public var intValue: Int? {
        return Int(stringValue)
    }

    public init?(stringValue: String) {
        self.stringValue = stringValue
    }

    public init?(intValue: Int) {
        self.stringValue = intValue.description
    }
}

