/// Converts `Data` to `[String: URLEncodedFormData]`.
internal struct URLEncodedFormParser {
    let omitEmptyValues: Bool
    let omitFlags: Bool
    let splitVariablesOn: Character
    let splitKeyValueOn: Character
    
    /// Create a new form-urlencoded data parser.
    init(omitEmptyValues: Bool = false, omitFlags: Bool = false, splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
        self.omitEmptyValues = omitEmptyValues
        self.omitFlags = omitFlags
        self.splitVariablesOn = splitVariablesOn
        self.splitKeyValueOn = splitKeyValueOn
    }

    func parse(_ encoded: String) throws -> [String: URLEncodedFormData] {
        let data = encoded.replacingOccurrences(of: "+", with: " ")
        var decoded: [String: URLEncodedFormData] = [:]

        for pair in data.split(separator: splitVariablesOn) {
            let data: URLEncodedFormData
            let key: URLEncodedFormEncodedKey

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: splitKeyValueOn,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )

            guard let rawKey = token.first else {
                throw URLEncodedFormError(
                    identifier: "percentDecoding",
                    reason: "Could not percent decode string key: \(token[0])"
                )
            }
            let rawValue = token.last

            if token.count == 2 {
                if omitEmptyValues && token[1].count == 0 {
                    continue
                }
                guard let decodedValue = rawValue?.removingPercentEncoding else {
                    throw URLEncodedFormError(identifier: "percentDecoding", reason: "Could not percent decode string value: \(token[1])")
                }
                key = try parseKey(string: rawKey)
                data = .string(decodedValue)
            } else if token.count == 1 {
                if omitFlags {
                    continue
                }
                key = try parseKey(string: rawKey)
                data = "true"
            } else {
                throw URLEncodedFormError(
                    identifier: "malformedData",
                    reason: "Malformed form-urlencoded data encountered"
                )
            }

            if !key.path.isEmpty {
                var current = decoded[key.name] ?? .dictionary([:])
                self.set(&current, to: data, at: key.path)
                decoded[key.name] = current
            } else {
                decoded[key.name] = merge(existing: decoded[key.name], new: data)
            }
        }

        return decoded
    }

    /// Parses a `URLEncodedFormEncodedKey` from `Data`.
    private func parseKey(string: Substring) throws -> URLEncodedFormEncodedKey {
        let name: Substring
        let path: [URLEncodedFormEncodedSubKey]

        // check if the key has `key[]` or `key[5]`
        if string.hasSuffix("]") {
            // split on the `[`
            // a[b][c][d][hello] => a, b], c], d], hello]
            let slices = string.split(separator: "[")
            guard slices.count > 0 else {
                throw URLEncodedFormError(identifier: "malformedKey", reason: "Malformed form-urlencoded key encountered.")
            }
            name = slices[0]
            path = slices[1...].map { subKey in
                if subKey.first == "]" {
                    return .array
                } else {
                    return .dictionary(subKey.dropLast().removingPercentEncoding!)
                }
            }
            if path.prefix(path.count-1).contains(where: { (key: URLEncodedFormEncodedSubKey) -> Bool in
                if case .array = key {
                    return true
                }
                return false
            }) {
                throw URLEncodedFormError(identifier: "malformedKey", reason: "Malformed form-urlencoded key encountered. [] indicating array must be the last element")
            }
        } else {
            name = string
            path = []
        }
        return URLEncodedFormEncodedKey(name: name.removingPercentEncoding!, path: path)
    }

    /// Sets mutable form-urlencoded input to a value at the given `[URLEncodedFormEncodedSubKey]` path.
    private func set(_ base: inout URLEncodedFormData, to data: URLEncodedFormData, at path: [URLEncodedFormEncodedSubKey]) {
        guard path.count >= 1 else {
            base = data
            return
        }

        let first = path[0]

        ///Produce a child
        var child: URLEncodedFormData
        switch path.count {
        case 1:
            child = data
            switch first {
            case .array:
                base = merge(existing: base, new: .array([child]))
            case .dictionary(let key):
                if case .dictionary(var dict) = base {
                    dict[key] = merge(existing: dict[key], new: child)
                    base = .dictionary(dict)
                } else {
                    base = .dictionary([key: child])
                }
            }
        case 2...:
            switch first {
            case .array:
                /// This part of the code should never be hit as we throw an error if we encounter an array in the middle ie `obj[key1][][key2]`
                /// always append to the last element of the array
                child = base.array?.last ?? .array([])
                set(&child, to: data, at: Array(path[1...]))
            case .dictionary(let key):
                ///There is more then one path element so this element has to be a dictionary
                child = base.dictionary?[key] ?? .dictionary([:])
                set(&child, to: data, at: Array(path[1...]))
                if case .dictionary(var dict) = base {
                    dict[key] = child
                    base = .dictionary(dict)
                } else {
                    base = .dictionary([key: child])
                }            }
        default: fatalError()
        }
    }
    
    private func merge(existing: URLEncodedFormData?, new: URLEncodedFormData) -> URLEncodedFormData {
        guard let existing = existing else {
            return new
        }
        switch existing {
        case .string(let existingString):
            switch new {
            case .string(_):
                return .array([existing, new])
            case .dictionary(_):
                return new
            case .array(let newArray):
                return .array([.string(existingString)] + newArray)
            }
        case .dictionary(_):
            return new
        case .array(let existingArray):
            switch new {
            case .string(let newString):
                return .array(existingArray + [.string(newString)])
            case .dictionary(_):
                return new
            case .array(let newArray):
                return .array(existingArray + newArray)
            }
        }
    }
}

// MARK: Key

/// Represents a key in a URLEncodedForm.
private struct URLEncodedFormEncodedKey {
    let name: String
    let path: [URLEncodedFormEncodedSubKey]
}

/// Available subkeys.
private enum URLEncodedFormEncodedSubKey {
    case array
    case dictionary(String)
}

// MARK: Utilities
//
//private extension Data {
//    /// UTF8 decodes a Stirng or throws an error.
//    func utf8DecodedString() throws -> String {
//        guard let string = String(data: self, encoding: .utf8) else {
//            throw URLEncodedFormError(identifier: "utf8Decoding", reason: "Failed to utf8 decode string: \(self)")
//        }
//
//        return string
//    }
//}
//
//private extension Data {
//    /// Percent decodes a String or throws an error.
//    func percentDecodedString() throws -> String {
//        let utf8 = try utf8DecodedString()
//
//        guard let decoded = utf8.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
//            throw URLEncodedFormError(
//                identifier: "percentDecoding",
//                reason: "Failed to percent decode string: \(self)"
//            )
//        }
//
//        return decoded
//    }
//}
