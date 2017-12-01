import Foundation

/// Converts data to form-urlencoded struct.
final class FormURLEncodedParser {
    /// Default form url encoded parser.
    static let `default` = FormURLEncodedParser()

    /// Create a new form-urlencoded data parser.
    init() {}

    /// Parses the data.
    /// If empty values is false, `foo=` will resolve as `foo: true`
    /// instead of `foo: ""`
    func parse(
        _ data: Data,
        omitEmptyValues: Bool = false,
        omitFlags: Bool = false
    ) throws -> [String: FormURLEncodedData] {
        var encoded: [String: FormURLEncodedData] = [:]

        for pair in data.split(separator: .ampersand) {
            let data: FormURLEncodedData
            let key: FormURLEncodedKey

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: .equals,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )

            if token.count == 2 {
                if omitEmptyValues && token[1].count == 0 {
                    continue
                }
                key = try parseKey(data: token[0])
                data = try .string(token[1].percentDecodedString())
            } else if token.count == 1 {
                if omitFlags {
                    continue
                }
                key = try parseKey(data: token[0])
                data = "true"
            } else {
                throw FormURLError(
                    identifier: "malformedData",
                    reason: "Malformed form-urlencoded data encountered"
                )
            }

            let resolved: FormURLEncodedData

            if !key.subKeys.isEmpty {
                var current = encoded[key.string] ?? .dictionary([:])
                self.set(&current, to: data, at: key.subKeys)
                resolved = current
            } else {
                resolved = data
            }

            encoded[key.string] = resolved
        }

        return encoded
    }

    private func parseKey(data: Data) throws -> FormURLEncodedKey {
        let stringData: Data
        let subKeys: [FormURLEncodedSubKey]

        // check if the key has `key[]` or `key[5]`
        if data.contains(.rightSquareBracket) && data.contains(.leftSquareBracket) {
            // split on the `[`
            // a[b][c][d][hello] => a, b], c], d], hello]
            let slices = data.split(separator: .leftSquareBracket)

            guard slices.count > 0 else {
                throw FormURLError(
                    identifier: "malformedKey",
                    reason: "Malformed form-urlencoded key encountered."
                )
            }
            stringData = Data(slices[0])
            subKeys = try slices[1...].map(Data.init).map { data -> FormURLEncodedSubKey in
                if data[0] == .rightSquareBracket {
                    return .array
                } else {
                    return try .dictionary(data.dropLast().percentDecodedString())
                }
            }
        } else {
            stringData = data
            subKeys = []
        }

        return try FormURLEncodedKey(
            string: stringData.percentDecodedString(),
            subKeys: subKeys
        )
    }

    /// Sets mutable form-urlencoded input to a value at the given path.
    private func set(
        _ base: inout FormURLEncodedData,
        to data: FormURLEncodedData,
        at path: [FormURLEncodedSubKey]
    ) {
        guard path.count >= 1 else {
            base = data
            return
        }

        let first = path[0]

        var child: FormURLEncodedData
        switch path.count {
        case 1:
            child = data
        case 2...:
            switch first {
            case .array:
                /// always append to the last element of the array
                child = base.array?.last ?? .array([])
                set(&child, to: data, at: Array(path[1...]))
            case .dictionary(let key):
                child = base.dictionary?[key] ?? .dictionary([:])
                set(&child, to: data, at: Array(path[1...]))
            }
        default: fatalError()
        }

        switch first {
        case .array:
            if case .array(var arr) = base {
                /// always append
                arr.append(child)
                base = .array(arr)
            } else {
                base = .array([child])
            }
        case .dictionary(let key):
            if case .dictionary(var dict) = base {
                dict[key] = child
                base = .dictionary(dict)
            } else {
                base = .dictionary([key: child])
            }
        }
    }
}

// MARK: Key

fileprivate struct FormURLEncodedKey {
    let string: String
    let subKeys: [FormURLEncodedSubKey]
}

fileprivate enum FormURLEncodedSubKey {
    case array
    case dictionary(String)
}

// MARK: Utilities

extension Data {
    fileprivate func percentDecodedString() throws -> String {
        guard let string = String(data: self, encoding: .utf8) else {
            throw FormURLError(
                identifier: "utf8Decoding",
                reason: "Failed to utf8 decode string: \(self)"
            )
        }

        guard let decoded = string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
            throw FormURLError(
                identifier: "percentDecoding",
                reason: "Failed to percent decode string: \(self)"
            )
        }

        return decoded
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index < count else {
            return nil
        }
        return self[index]
    }
}
