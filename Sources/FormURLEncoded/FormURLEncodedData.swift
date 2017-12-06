import Bits
import Foundation

/// Represents application/x-www-form-urlencoded encoded data.
enum FormURLEncodedData {
    case dictionary([String: FormURLEncodedData])
    case array([FormURLEncodedData])
    case string(String)

    var array: [FormURLEncodedData]? {
        switch self {
        case .array(let arr): return arr
        default: return nil
        }
    }

    var dictionary: [String: FormURLEncodedData]? {
        switch self {
        case .dictionary(let dict): return dict
        default: return nil
        }
    }

    var string: String? {
        switch self {
        case .string(let s): return s
        default: return nil
        }
    }
}

extension FormURLEncodedData: Equatable {
    static func ==(lhs: FormURLEncodedData, rhs: FormURLEncodedData) -> Bool {
        switch (lhs, rhs) {
        case (.array(let a), .array(let b)): return a == b
        case (.dictionary(let a), .dictionary(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        default: return false
        }
    }


}

// MARK: Literal

extension FormURLEncodedData: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: FormURLEncodedData...) {
        self = .array(elements)
    }
}

extension FormURLEncodedData: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension FormURLEncodedData: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, FormURLEncodedData)...) {
        var dict: [String: FormURLEncodedData] = [:]
        elements.forEach { dict[$0.0] = $0.1 }
        self = .dictionary(dict)
    }
}

/// MARK: Get

extension FormURLEncodedData {
    /// Returns the value, if one at from the given path.
    func get(at path: [CodingKey]) -> FormURLEncodedData? {
        var child = self

        for seg in path {
            if let index = seg.intValue {
                guard let c = child.array?[safe: index] else {
                    return nil
                }
                child = c
            } else {
                guard let c = child.dictionary?[seg.stringValue] else {
                    return nil
                }
                child = c
            }
        }

        return child
    }

    /// Gets a value or throws a decoding error
    func require(_ type: Any.Type, atPath path: [CodingKey]) throws -> FormURLEncodedData {
        guard let data = get(at: path) else {
            let pathString = path.map { $0.stringValue }.joined(separator: ".")
            let context = DecodingError.Context(
                codingPath: path,
                debugDescription: "No \(type) was found at path \(pathString)"
            )
            throw Swift.DecodingError.valueNotFound(type, context)
        }

        return data
    }
}

/// Reference wrapper for form urlencoded data
final class PartialFormURLEncodedData {
    /// The wrapped data
    var data: FormURLEncodedData

    /// Create a new wrapper
    init(data: FormURLEncodedData) {
        self.data = data
    }

    /// Sets partial form-urlencoded data to supplied value at the given path.
    func set(_ data: FormURLEncodedData?, atPath path: [CodingKey]) {
        self.set(&self.data, to: data, at: path)
    }

    /// Sets mutable form-urlencoded input to a value at the given path.
    private func set(
        _ base: inout FormURLEncodedData,
        to data: FormURLEncodedData?,
        at path: [CodingKey]
    ) {
        guard path.count >= 1 else {
            base = data ?? .string("")
            return
        }

        let first = path[0]

        var child: FormURLEncodedData?
        switch path.count {
        case 1:
            child = data
        case 2...:
            if let _ = first.intValue {
                /// always append to the last element of the array
                child = base.array?.last ?? .array([])
                set(&child!, to: data, at: Array(path[1...]))
            } else {
                child = base.dictionary?[first.stringValue] ?? .dictionary([:])
                set(&child!, to: data, at: Array(path[1...]))
            }
        default: fatalError()
        }

        if let _ = first.intValue {
            if let child = child {
                if case .array(var arr) = base {
                    /// always append
                    arr.append(child)
                    base = .array(arr)
                } else {
                    base = .array([child])
                }
            }
        } else {
            if case .dictionary(var dict) = base {
                dict[first.stringValue] = child
                base = .dictionary(dict)
            } else {
                if let child = child {
                    base = .dictionary([first.stringValue: child])
                }
            }
        }
    }
}
