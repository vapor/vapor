import Mapper

/// Supported data types for storing
// and fetching from a `Cache`.
public enum URLEncodedForm {
    case string(String)
    case array([URLEncodedForm])
    case dictionary([String: URLEncodedForm])
    case null
}

/// Able to be represented as `URLEncodedForm`.
public protocol URLEncodedFormRepresentable {
    func makeURLEncodedForm() throws -> URLEncodedForm
}

/// Able to be initialized with `URLEncodedForm`
public protocol URLEncodedFormInitializable {
    init(urlEncodedForm: URLEncodedForm) throws
}

/// Able to convert to and from `URLEncodedForm`.
public typealias URLEncodedFormConvertible = URLEncodedFormInitializable & URLEncodedFormRepresentable

// URLEncodedForm can obviously convert to/from itself.
extension URLEncodedForm: URLEncodedFormConvertible {
    public init(urlEncodedForm: URLEncodedForm) throws {
        self = urlEncodedForm
    }

    public func makeURLEncodedForm() throws -> URLEncodedForm {
        return self
    }
}

/// Support conversion to `Map` type for easy
/// conversions b/t other data types.
extension URLEncodedForm: MapConvertible {
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
            self = .dictionary(dict.mapValues { URLEncodedForm(map: $0) })
        case .array(let arr):
            self = .array(arr.map { URLEncodedForm(map: $0) })
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
extension URLEncodedForm: Polymorphic {
    // Automatically implemented by conforming to `MapConvertible`.
}

// Instances of `URLEncodedForm` can be compared.
extension URLEncodedForm: Equatable {
    public static func ==(lhs: URLEncodedForm, rhs: URLEncodedForm) -> Bool {
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

// MARK: Keyed

extension URLEncodedForm: Keyed {
    public static var empty: URLEncodedForm { return .dictionary([:]) }

    public mutating func set(key: PathComponent, to value: URLEncodedForm?) {
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

    public func get(key: PathComponent) -> URLEncodedForm? {
        switch key {
        case .index(let int):
            return array?[safe: int]
        case .key(let string):
            return dictionary?[string]
        }
    }
}

// Keyed convenience
extension URLEncodedForm {
    public mutating func set<T: URLEncodedFormRepresentable>(_ path: Path..., to value: T) throws {
        try set(path, to: value) { try $0.makeURLEncodedForm() }
    }

    public func get<T: URLEncodedFormInitializable>(_ path: Path...) throws -> T {
        return try get(path) { try T.init(urlEncodedForm: $0) }
    }
}



// MARK: Compatible Types

extension String: URLEncodedFormConvertible {
    public init(urlEncodedForm: URLEncodedForm) throws {
        self = try urlEncodedForm.assertString()
    }

    public func makeURLEncodedForm() -> URLEncodedForm {
        return .string(self)
    }
}

extension Int: URLEncodedFormConvertible {
    public init(urlEncodedForm: URLEncodedForm) throws {
        self = try urlEncodedForm.assertInt()
    }

    public func makeURLEncodedForm() -> URLEncodedForm {
        return .string(self.description)
    }
}

extension Double: URLEncodedFormConvertible {
    public init(urlEncodedForm: URLEncodedForm) throws {
        self = try urlEncodedForm.assertDouble()
    }

    public func makeURLEncodedForm() throws -> URLEncodedForm {
        return .string(self.description)
    }
}

// MARK: Expressible

extension URLEncodedForm: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: URLEncodedForm...) {
        self = .array(elements)
    }
}

extension URLEncodedForm: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, URLEncodedForm)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements) )
    }
}

extension URLEncodedForm: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension URLEncodedForm: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
