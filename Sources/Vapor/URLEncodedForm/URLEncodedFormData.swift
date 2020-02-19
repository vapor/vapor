/// Represents application/x-www-form-urlencoded encoded data.
enum URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable, CustomStringConvertible {
    /// Stores a string, this is the root storage.
    case string(String)

    /// Stores a dictionary of self.
    case dictionary([String: URLEncodedFormData])

    /// Stores an array of self.
    case array([URLEncodedFormData])
    
    /// `CustomStringConvertible` conformance.
    var description: String {
        switch self {
        case .string(let string): return string.debugDescription
        case .array(let arr): return arr.description
        case .dictionary(let dict): return dict.description
        }
    }

    /// Converts self to an `String` or returns `nil` if not convertible.
    var string: String? {
        switch self {
        case .string(let s): return s
        default: return nil
        }
    }

    /// Converts self to an `URL` or returns `nil` if not convertible.
    var url: URL? {
        switch self {
        case .string(let s): return URL(string: s)
        default: return nil
        }
    }

    /// Converts self to an `[URLEncodedFormData]` or returns `nil` if not convertible.
    var array: [URLEncodedFormData]? {
        switch self {
        case .array(let arr): return arr
        default: return nil
        }
    }

    /// Converts self to an `[String: URLEncodedFormData]` or returns `nil` if not convertible.
    var dictionary: [String: URLEncodedFormData]? {
        switch self {
        case .dictionary(let dict): return dict
        default: return nil
        }
    }

    // MARK: Literal

    /// See `ExpressibleByArrayLiteral`.
    init(arrayLiteral elements: URLEncodedFormData...) {
        self = .array(elements)
    }

    /// See `ExpressibleByStringLiteral`.
    init(stringLiteral value: String) {
        self = .string(value)
    }

    /// See `ExpressibleByDictionaryLiteral`.
    init(dictionaryLiteral elements: (String, URLEncodedFormData)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}
