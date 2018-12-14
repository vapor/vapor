/// A basic `CodingKey` implementation.
public struct BasicKey: CodingKey {
    /// See `CodingKey`.
    public var stringValue: String
    
    /// See `CodingKey`.
    public var intValue: Int?
    
    /// Creates a new `BasicKey` from a `String.`
    public init(_ string: String) {
        self.stringValue = string
    }
    
    /// Creates a new `BasicKey` from a `Int.`
    ///
    /// These are usually used to specify array indexes.
    public init(_ int: Int) {
        self.intValue = int
        self.stringValue = int.description
    }
    
    /// See `CodingKey`.
    public init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    /// See `CodingKey`.
    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = intValue.description
    }
}

/// Capable of being represented by a `BasicKey`.
public protocol BasicKeyRepresentable {
    /// Converts this type to a `BasicKey`.
    func makeBasicKey() -> BasicKey
}

extension String: BasicKeyRepresentable {
    /// See `BasicKeyRepresentable`
    public func makeBasicKey() -> BasicKey {
        return BasicKey(self)
    }
}

extension Int: BasicKeyRepresentable {
    /// See `BasicKeyRepresentable`
    public func makeBasicKey() -> BasicKey {
        return BasicKey(self)
    }
}

extension Array where Element == BasicKeyRepresentable {
    /// Converts an array of `BasicKeyRepresentable` to `[BasicKey]`
    public func makeBasicKeys() -> [BasicKey] {
        return map { $0.makeBasicKey() }
    }
}
