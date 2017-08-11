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
    init(URLEncodedForm: URLEncodedForm) throws
}

/// Able to convert to and from `URLEncodedForm`.
public typealias URLEncodedFormConvertible = URLEncodedFormInitializable & URLEncodedFormRepresentable

// URLEncodedForm can obviously convert to/from itself.
extension URLEncodedForm: URLEncodedFormConvertible {
    public init(URLEncodedForm: URLEncodedForm) throws {
        self = URLEncodedForm
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

// MARK: Compatible Types

extension String: URLEncodedFormConvertible {
    public init(URLEncodedForm: URLEncodedForm) throws {
        self = try URLEncodedForm.assertString()
    }

    public func makeURLEncodedForm() -> URLEncodedForm {
        return .string(self)
    }
}

extension Int: URLEncodedFormConvertible {
    public init(URLEncodedForm: URLEncodedForm) throws {
        self = try URLEncodedForm.assertInt()
    }

    public func makeURLEncodedForm() -> URLEncodedForm {
        return .string(self.description)
    }
}

extension Double: URLEncodedFormConvertible {
    public init(URLEncodedForm: URLEncodedForm) throws {
        self = try URLEncodedForm.assertDouble()
    }

    public func makeURLEncodedForm() throws -> URLEncodedForm {
        return .string(self.description)
    }
}


