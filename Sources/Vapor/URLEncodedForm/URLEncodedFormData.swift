import Logging

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Keeps track if the string was percent encoded or not.
/// Prevents double encoding/double decoding
enum URLQueryFragment: ExpressibleByStringLiteral, Equatable {
    init(stringLiteral: String) {
        self = .urlDecoded(stringLiteral)
    }

    case urlEncoded(String)
    case urlDecoded(String)

    /// Returns the URL Encoded version
    func asUrlEncoded() throws -> String {
        switch self {
        case .urlEncoded(let encoded):
            return encoded
        case .urlDecoded(let decoded):
            return try decoded.urlEncoded()
        }
    }

    /// Returns the URL Decoded version
    func asUrlDecoded() throws -> String {
        switch self {
        case .urlEncoded(let encoded):
            guard let decoded = encoded.removingPercentEncoding else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Unable to remove percent encoding for \(encoded)"))
            }
            return decoded
        case .urlDecoded(let decoded):
            return decoded
        }
    }

    /// Do comparison and hashing using the decoded version as there are multiple ways something can be encoded.
    /// Certain characters that are not typically encoded could have been encoded making string comparisons between two encodings not work
    static func == (lhs: URLQueryFragment, rhs: URLQueryFragment) -> Bool {
        do {
            return try lhs.asUrlDecoded() == rhs.asUrlDecoded()
        } catch {
            return false
        }
    }

    func hash(into: inout Hasher) {
        do {
            try self.asUrlDecoded().hash(into: &into)
        } catch {
            Logger(label: "codes.vapor.url").report(error: error)
        }
    }
}

/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable {
    var values: [URLQueryFragment]
    var children: [String: URLEncodedFormData]
    let maxRecursionDepth = 100

    var hasOnlyValues: Bool {
        return children.count == 0
    }

    var allChildKeysAreSequentialIntegers: Bool {
        guard !self.children.isEmpty else {
            return false
        }
        for i in 0..<self.children.count {
            if !self.children.keys.contains(String(i)) {
                return false
            }
        }
        return true
    }

    init(values: [URLQueryFragment] = [], children: [String: URLEncodedFormData] = [:]) {
        self.values = values
        self.children = children
    }

    init(stringLiteral: String) {
        self.values = [.urlDecoded(stringLiteral)]
        self.children = [:]
    }

    init(arrayLiteral: String...) {
        self.values = arrayLiteral.map({ (s: String) -> URLQueryFragment in
            return .urlDecoded(s)
        })
        self.children = [:]
    }

    init(dictionaryLiteral: (String, URLEncodedFormData)...) {
        self.values = []
        self.children = Dictionary(uniqueKeysWithValues: dictionaryLiteral)
    }

    private func containsValue(atPath path: ArraySlice<String>) -> Bool {
        guard let head = path.first else {
            return !self.values.isEmpty || !self.children.isEmpty
        }
        if head.isEmpty {
            // Empty brackets denote a nested append rather than overwriting an existing field on the current element.
            return false
        }
        guard let child = self.children[head] else {
            return false
        }
        return child.containsValue(atPath: path.dropFirst())
    }

    mutating func set(value: URLQueryFragment, forPath path: [String], recursionDepth: Int) throws {
        try self.set(value: value, forPath: path[...], recursionDepth: recursionDepth)
    }

    private mutating func set(value: URLQueryFragment, forPath path: ArraySlice<String>, recursionDepth: Int) throws {
        guard recursionDepth <= self.maxRecursionDepth else {
            throw URLEncodedFormError.reachedNestingLimit
        }
        guard let firstElement = path.first else {
            self.values.append(value)
            return
        }
        let remainingPath = path.dropFirst()
        let targetKey: String
        if firstElement.isEmpty,
            !remainingPath.isEmpty,
            self.children.isEmpty || self.allChildKeysAreSequentialIntegers
        {
            if self.children.isEmpty {
                targetKey = "0"
            } else {
                let lastIndex = self.children.count - 1
                let lastKey = String(lastIndex)
                if let lastChild = self.children[lastKey], lastChild.containsValue(atPath: remainingPath) {
                    targetKey = String(lastIndex + 1)
                } else {
                    targetKey = lastKey
                }
            }
        } else {
            targetKey = firstElement
        }
        var child = self.children[targetKey] ?? []
        try child.set(value: value, forPath: remainingPath, recursionDepth: recursionDepth + 1)
        self.children[targetKey] = child
    }
}
