/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData2: Equatable {
    var values: [String]
    // If you have an array
    var children: [String: URLEncodedFormData2]
    
    var hasOnlyValues: Bool {
        return children.count == 0
    }
    
    init(values: [String] = [], children: [String: URLEncodedFormData2] = [:]) {
        self.values = values
        self.children = children
    }
    
    init(_ value: String) {
        self.values = [value]
        self.children = [:]
    }
    
    init(_ values: [String]) {
        self.values = values
        self.children = [:]
    }
    
    init(_ children: [String: URLEncodedFormData2]) {
        self.values = []
        self.children = children
    }
    
    mutating func set(value: String, forPath path: [String]) {
        guard let firstElement = path.first else {
            values.append(value)
            return
        }
        var child: URLEncodedFormData2
        if let existingChild = children[firstElement] {
            child = existingChild
        } else {
            child = URLEncodedFormData2()
        }
        child.set(value: value, forPath: Array(path[1...]))
        children[firstElement] = child
    }
}

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
        //If we parsed an array but the code needs a string then get the last element of the array
        //Question: Should it be the last or the first element? If we assume that variables are "assigned" in the order that they are received and new values overwrite old ones then last makes sense. First can also be acceptible.
        //Should this be configurable?
        case .array(let arr):
            guard
                let element = arr.last,
                case let URLEncodedFormData.string(s) = element else {
                return nil
            }
            return s
        default: return nil
        }
    }

    /// Converts self to an `[URLEncodedFormData]` or returns `nil` if not convertible.
    var array: [URLEncodedFormData]? {
        switch self {
        //If we parsed a string but the code is asking for an array then convert self into an array
        case .string(_): return [self]
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
