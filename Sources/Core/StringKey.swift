/// A basic string coding key
public struct BasicKey: CodingKey {
    /// the string value
    public var stringValue: String

    /// the optional int value
    public var intValue: Int?

    /// create a new string basic key
    public init(_ string: String) {
        self.stringValue = string
    }

    /// create a new int basic key
    /// note: keys with int values can trigger
    /// array behavior in decoders
    public init(_ int: Int) {
        self.intValue = int
        self.stringValue = int.description
    }

    /// See CodingKey.init
    public init?(stringValue: String) {
        self.stringValue = stringValue
    }

    /// See CodingKey.init
    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = intValue.description
    }
}

/// Capable of being represented by a coding key.
public protocol BasicKeyRepresentable {
    /// Makes a coding key representation.
    func makeBasicKey() -> BasicKey
}

extension String: BasicKeyRepresentable {
    /// See BasicKeyRepresentable.makeBasicKey
    public func makeBasicKey() -> BasicKey {
        return BasicKey(self)
    }
}

extension Int: BasicKeyRepresentable {
    /// See BasicKeyRepresentable.makeBasicKey
    public func makeBasicKey() -> BasicKey {
        return BasicKey(self)
    }
}

extension Array where Element == BasicKeyRepresentable {
    /// Converts an array of CodingKeyRepresentable to [CodingKey]
    public func makeBasicKeys() -> [BasicKey] {
        return map { $0.makeBasicKey() }
    }
}
