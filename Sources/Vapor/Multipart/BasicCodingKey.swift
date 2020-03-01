/// A basic `CodingKey` implementation.
internal enum BasicCodingKey: CodingKey {
    case key(String)
    case index(Int)

    /// See `CodingKey`.
    public var stringValue: String {
        switch self {
        case .index(let index): return index.description
        case .key(let key): return key
        }
    }

    /// See `CodingKey`.
    public var intValue: Int? {
        switch self {
        case .index(let index): return index
        case .key(let key): return Int(key)
        }
    }

    /// See `CodingKey`.
    public init?(stringValue: String) {
        self = .key(stringValue)
    }

    /// See `CodingKey`.
    public init?(intValue: Int) {
        self = .index(intValue)
    }
}

