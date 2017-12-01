import Bits
import Core
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
