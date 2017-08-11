import Foundation
import HTTP

extension URLEncodedForm: Content {
    public static var mediaType: MediaType {
        return .urlEncodedForm
    }

    public static func parse(data: Data) throws -> URLEncodedForm {
        var urlEncoded: [String: URLEncodedForm] = [:]

        for pair in data.split(separator: .ampersand) {
            var value = URLEncodedForm.string("")
            var keyData: Bytes

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: .equals,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: false
            )
            if token.count == 2 {
                keyData = token[0]
                    .makeString()
                    .replacingOccurrences(of: "+", with: " ")
                    .percentDecoded
                    .makeBytes()

                let valueData = token[1]
                    .makeString()
                    .replacingOccurrences(of: "+", with: " ")
                    .percentDecoded

                value = .string(valueData)
            } else if token.count == 1 {
                keyData = token[0]
                    .makeString()
                    .replacingOccurrences(of: "+", with: " ")
                    .percentDecoded.makeBytes()

                value = .string("true")
            } else {
                throw URLEncodedError.unexpected(
                    reason: "Unexpected split count when parsing: \(pair.makeString())"
                )
            }

            var keyIndicatedArray = false

            var subKey = ""
            var keyIndicatedObject = false

            // check if the key has `key[]` or `key[5]`
            if keyData.contains(.rightSquareBracket) && keyData.contains(.leftSquareBracket) {
                // get the key without the `[]`
                let slices = keyData
                    .split(separator: .leftSquareBracket, maxSplits: 1)
                guard slices.count == 2 else {
                    print("Found bad encoded pair \(pair.makeString()) ... continuing")
                    continue
                }

                keyData = slices[0].array

                let contents = slices[1].array
                if contents[0] == .rightSquareBracket {
                    keyIndicatedArray = true
                } else {
                    subKey = contents.dropLast().makeString()
                    keyIndicatedObject = true
                }
            }

            let key = keyData.makeString()

            if let existing = urlEncoded[key] {
                if keyIndicatedArray {
                    var array = existing.array ?? [existing]
                    array.append(value)
                    value = .array(array)
                } else if keyIndicatedObject {
                    var obj = existing.dictionary ?? [:]
                    obj[subKey] = value
                    value = .dictionary(obj)
                } else {
                    // if we don't have `[]` on this pair, but it was previously assigned
                    // an array, then it is implicit and should be appended.
                    // OR if we found a subsequent value w/ same identifier, it should
                    // become an array
                    var array = existing.array ?? [existing]
                    array.append(value)
                    value = .array(array)
                }
            } else if keyIndicatedArray {
                value = .array([value])
            } else if keyIndicatedObject {
                value = .dictionary([subKey: value])
            }

            urlEncoded[key] = value
        }

        return .dictionary(urlEncoded)
    }

    public func serialize() throws -> Data {
        guard case .dictionary(let dict) = self else {
            throw URLEncodedError.unsupportedTopLevel()
        }

        var datas: [Data] = []

        for (key, val) in dict {
            let key = key.formURLEscaped()
            let data: Data

            switch val {
            case .dictionary(let dict):
                var datas: [Data] = []
                try dict.forEach { subKey, value in
                    let subKey = subKey.formURLEscaped()
                    guard let value = value.string else {
                        throw URLEncodedError.unsupportedNesting(
                            reason: "Dictionary may only be nested one layer deep."
                        )
                    }

                    let string = "\(key)[\(subKey)]=\(value)"
                    guard let encoded = string.data(using: .utf8) else {
                        throw URLEncodedError.unableToEncode(string: string)
                    }
                    datas.append(encoded)
                }
                data = datas.joined(separatorByte: .ampersand)
            case .array(let array):
                var datas: [Data] = []
                try array.forEach { value in
                    guard let val = value.string else {
                        throw URLEncodedError.unsupportedNesting(
                            reason: "Array values may only be nested one layer deep."
                        )
                    }

                    let string = "\(key)[]=\(val)"
                    guard let encoded = string.data(using: .utf8) else {
                        throw URLEncodedError.unableToEncode(string: string)
                    }
                    datas.append(encoded)
                }
                data = datas.joined(separatorByte: .ampersand)
            case .string(let string):
                let string = "\(key)=\(string)"
                guard let encoded = string.data(using: .utf8) else {
                    throw URLEncodedError.unableToEncode(string: string)
                }
                data = encoded
            case .null:
                continue
            }

            datas.append(data)
        }

        return datas.joined(separatorByte: .ampersand)
    }
}

// MARK: Utilities

extension Array where Element == Data {
    fileprivate func joined(separatorByte byte: Byte) -> Data {
        return Data(joined(separator: [byte]))
    }
}

extension String {
    fileprivate func formURLEscaped() -> String {
        return addingPercentEncoding(withAllowedCharacters: .formURLEncoded) ?? self
    }
}

extension CharacterSet {
    fileprivate static var formURLEncoded: CharacterSet {
        var set: CharacterSet = .urlQueryAllowed
        set.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return set
    }
}
