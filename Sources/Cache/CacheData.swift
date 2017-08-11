import Mapper

/// Supported data types for storing
// and fetching from a `Cache`.
public enum CacheData {
    case string(String)
    case array([CacheData])
    case dictionary([String: CacheData])
    case null
}

/// Able to be represented as `CacheData`.
public protocol CacheDataRepresentable {
    func makeCacheData() throws -> CacheData
}

/// Able to be initialized with `CacheData`
public protocol CacheDataInitializable {
    init(cacheData: CacheData) throws
}

/// Able to convert to and from `CacheData`.
public typealias CacheDataConvertible = CacheDataInitializable & CacheDataRepresentable

// CacheData can obviously convert to/from itself.
extension CacheData: CacheDataConvertible {
    public init(cacheData: CacheData) throws {
        self = cacheData
    }

    public func makeCacheData() throws -> CacheData {
        return self
    }
}

/// Support conversion to `Map` type for easy
/// conversions b/t other data types.
extension CacheData: MapConvertible {
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
            self = .dictionary(dict.mapValues { CacheData(map: $0) })
        case .array(let arr):
            self = .array(arr.map { CacheData(map: $0) })
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

// Convenience accessors like `.string`.
extension CacheData: Polymorphic {
    // Automatically implemented by conforming to `MapConvertible`.
}

// Instances of `CacheData` can be compared.
extension CacheData: Equatable {
    public static func ==(lhs: CacheData, rhs: CacheData) -> Bool {
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

extension String: CacheDataConvertible {
    public init(cacheData: CacheData) throws {
        self = try cacheData.assertString()
    }

    public func makeCacheData() -> CacheData {
        return .string(self)
    }
}

extension Int: CacheDataConvertible {
    public init(cacheData: CacheData) throws {
        self = try cacheData.assertInt()
    }

    public func makeCacheData() -> CacheData {
        return .string(self.description)
    }
}

extension Double: CacheDataConvertible {
    public init(cacheData: CacheData) throws {
        self = try cacheData.assertDouble()
    }

    public func makeCacheData() throws -> CacheData {
        return .string(self.description)
    }
}
