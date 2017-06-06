import Foundation
import Core
import Node

extension Node {
    /// Queries allow empty values
    /// FormURLEncoded does not
    public init(formURLEncoded data: Bytes, allowEmptyValues: Bool) {
        var urlEncoded: [String: Node] = [:]

        let replacePlus: (Byte) -> (Byte) = { byte in
            guard byte == .plus else { return byte }
            return .space
        }
        
        for pair in data.split(separator: .ampersand) {
            var value: Node = .string("")
            var keyData: Bytes

            /// Allow empty subsequences
            /// value= => "value": ""
            /// value => "value": true
            let token = pair.split(
                separator: .equals,
                maxSplits: 1, // max 1, `foo=a=b` should be `"foo": "a=b"`
                omittingEmptySubsequences: !allowEmptyValues
            )
            if token.count == 2 {
                keyData = token[0].map(replacePlus)
                    .makeString()
                    .percentDecoded
                    .makeBytes()
                
                let valueData = token[1].map(replacePlus)
                    .makeString()
                    .percentDecoded
                
                value = .string(valueData)
            } else if allowEmptyValues && token.count == 1 {
                keyData = token[0].map(replacePlus)
                    .makeString()
                    .percentDecoded.makeBytes()
                
                value = .bool(true)
            } else {
                print("Found bad encoded pair \(pair.makeString()) ... continuing")
                continue
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
                    var obj = existing.object ?? [:]
                    obj[subKey] = value
                    value = .object(obj)
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
                value = .object([subKey: value])
            }

            urlEncoded[key] = value

        }
        
        self = .object(urlEncoded)
    }
    
    public func formURLEncoded() throws -> Bytes {
        guard let dict = self.object else { return [] }

        var bytes: [[Byte]] = []

        for (key, val) in dict {
            var subbytes: [Byte] = []
            
            subbytes += key.urlQueryPercentEncoded.makeBytes()
            subbytes += Byte.equals
            subbytes += val.formURLEncodedValue(forKey: key).makeBytes()
            
            bytes.append(subbytes)
        }

        return bytes.joined(separator: [Byte.ampersand]).array
    }
}

extension Node {
    fileprivate func formURLEncodedValue(forKey key: String) -> String {
        guard let object = self.object else { return string.formURLEncodedValue() }
        return object.formURLEncodedValue(forKey: key)
    }
}

extension Dictionary where Key == String, Value == Node {
    fileprivate func formURLEncodedValue(forKey key: String) -> String {
        let values = map { subKey, value in
            var encoded = ""
            encoded += key.urlQueryPercentEncoded
            encoded += "[\(subKey.urlQueryPercentEncoded)]="
            encoded += value.string.formURLEncodedValue()
            return encoded
        } as [String]

        return values.joined(separator: "&")
    }
}

extension Optional where Wrapped == String {
    fileprivate func formURLEncodedValue() -> String {
        guard let value = self else { return "" }
        return value.urlQueryPercentEncoded
    }
}
