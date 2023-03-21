#if swift(>=5.6) && os(Linux)
public typealias CodingKeyRepresentable = Swift.CodingKeyRepresentable
#else
/// This is an unwelcome stand-in for the ``Swift/CodingKeyRepresentable`` protocol that appeared in Swift 5.6.
public protocol CodingKeyRepresentable {
    var codingKey: CodingKey { get }
}

/// This conformance is provided by the stdlib when ``CodingKeyRepresentable`` is available.
extension String: Vapor.CodingKeyRepresentable {
    public var codingKey: CodingKey { BasicCodingKey.key(self) }
}

/// This conformance is provided by the stdlib when ``CodingKeyRepresentable`` is available.
extension Int: Vapor.CodingKeyRepresentable {
    public var codingKey: CodingKey { BasicCodingKey.index(self) }
}
#endif

extension Array where Element == CodingKey {
    public var dotPath: String { self.map(\.stringValue).joined(separator: ".") }
}

/// A basic `CodingKey` implementation.
public enum BasicCodingKey: CodingKey, Hashable {
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

    public init(_ codingKey: CodingKey) {
        if let intValue = codingKey.intValue {
            self = .index(intValue)
        } else {
            self = .key(codingKey.stringValue)
        }
    }
    
    public init(_ codingKeyRepresentable: Vapor.CodingKeyRepresentable) {
        self.init(codingKeyRepresentable.codingKey)
    }
}

extension BasicCodingKey: CustomStringConvertible {
    public var description: String {
        switch self {
        case .index(let index):
            return index.description
        case .key(let key):
            return key.description
        }
    }
}

extension BasicCodingKey: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .index(let index):
            return index.description
        case .key(let key):
            return key.debugDescription
        }
    }
}

extension BasicCodingKey: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self = .key(stringLiteral)
    }
}

extension BasicCodingKey: ExpressibleByIntegerLiteral {
    public init(integerLiteral: Int) {
        self = .index(integerLiteral)
    }
}
