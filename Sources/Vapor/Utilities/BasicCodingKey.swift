#if os(Linux)
public typealias CodingKeyRepresentable = Swift.CodingKeyRepresentable
#else
/// This is an unwelcome stand-in for the ``Swift/CodingKeyRepresentable`` protocol that appeared in Swift 5.6.
public protocol CodingKeyRepresentable {
    var codingKey: any CodingKey { get }
}

/// This conformance is provided by the stdlib when ``CodingKeyRepresentable`` is available.
extension String: Vapor.CodingKeyRepresentable {
    public var codingKey: any CodingKey { BasicCodingKey.key(self) }
}

/// This conformance is provided by the stdlib when ``CodingKeyRepresentable`` is available.
extension Int: Vapor.CodingKeyRepresentable {
    public var codingKey: any CodingKey { BasicCodingKey.index(self) }
}
#endif

extension Array where Element == any CodingKey {
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

    public init(_ codingKey: any CodingKey) {
        if let intValue = codingKey.intValue {
            self = .index(intValue)
        } else {
            self = .key(codingKey.stringValue)
        }
    }
    
    public init(_ codingKeyRepresentable: any Vapor.CodingKeyRepresentable) {
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
