import Mapper

/// Supported data types for storing
// and fetching from a `Session`.
public enum SessionData {
    case string(String)
    case array([SessionData])
    case dictionary([String: SessionData])
    case null
}

/// Able to be represented as `SessionData`.
public protocol SessionDataRepresentable {
    func makeSessionData() throws -> SessionData
}

/// Able to be initialized with `SessionData`
public protocol SessionDataInitializable {
    init(sessionData: SessionData) throws
}

/// Able to convert to and from `SessionData`.
public typealias SessionDataConvertible = SessionDataInitializable & SessionDataRepresentable

// SessionData can obviously convert to/from itself.
extension SessionData: SessionDataConvertible {
    public init(sessionData: SessionData) throws {
        self = sessionData
    }

    public func makeSessionData() throws -> SessionData {
        return self
    }
}

// MARK: Map

/// Support conversion to `Map` type for easy
/// conversions b/t other data types.
extension SessionData: MapConvertible {
    public init(map: Map) {
        switch map {
        case .string(let string):
            self = .string(string)
        case .int(let int):
            self = .string(int.description)
        case .double(let double):
            self = .string(double.description)
        case .bool(let bool):
            self = .string(bool.description)
        case .null:
            self = .null
        case .dictionary(let dict):
            self = .dictionary(dict.mapValues { SessionData(map: $0) })
        case .array(let arr):
            self = .array(arr.map { SessionData(map: $0) })
        }
    }

    public func makeMap() -> Map {
        switch self {
        case .array(let arr):
            return .array(arr.map { $0.makeMap() })
        case .dictionary(let dict):
            return .dictionary(dict.mapValues { $0.makeMap() })
        case .null:
            return .null
        case .string(let string):
            return .string(string)
        }
    }
}

// MARK: Keyed

extension SessionData: Keyed {
    public static var empty: SessionData { return .dictionary([:]) }

    public mutating func set(key: PathComponent, to value: SessionData?) {
        switch key {
        case .index(let int):
            var array = self.array ?? []
            array[safe: int] = value ?? .null
            self = .array(array)
        case .key(let string):
            var dict = dictionary ?? [:]
            dict[string] = value ?? .null
            self = .dictionary(dict)
        }
    }

    public func get(key: PathComponent) -> SessionData? {
        switch key {
        case .index(let int):
            return array?[safe: int]
        case .key(let string):
            return dictionary?[string]
        }
    }
}

// Keyed convenience
extension SessionData {
    public mutating func set<T: SessionDataRepresentable>(_ path: Path..., to sessionData: T) throws {
        try set(path, to: sessionData) { try $0.makeSessionData() }
    }

    public func get<T: SessionDataInitializable>(_ path: Path...) throws -> T {
        return try get(path) { try T.init(sessionData: $0) }
    }
}


// Convenience accessors like `.string`.
extension SessionData: Polymorphic {
    // Automatically implemented by conforming to `MapConvertible`.
}

// Instances of `SessionData` can be compared.
extension SessionData: Equatable {
    public static func ==(lhs: SessionData, rhs: SessionData) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)):
            return a == b
        case (.dictionary(let a), .dictionary(let b)):
            return a == b
        case (.array(let a), .array(let b)):
            return a == b
        case (.null, .null):
            return true
        default:
            return false
        }
    }
}

// MARK: Compatible Types

extension String: SessionDataConvertible {
    public init(sessionData: SessionData) throws {
        self = try sessionData.assertString()
    }

    public func makeSessionData() -> SessionData {
        return .string(self)
    }
}

extension Int: SessionDataConvertible {
    public init(sessionData: SessionData) throws {
        self = try sessionData.assertInt()
    }

    public func makeSessionData() -> SessionData {
        return .string(self.description)
    }
}

extension Double: SessionDataConvertible {
    public init(sessionData: SessionData) throws {
        self = try sessionData.assertDouble()
    }

    public func makeSessionData() throws -> SessionData {
        return .string(self.description)
    }
}

// MARK: Expressible

extension SessionData: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SessionData...) {
        self = .array(elements)
    }
}

extension SessionData: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, SessionData)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements) )
    }
}

extension SessionData: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension SessionData: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}


