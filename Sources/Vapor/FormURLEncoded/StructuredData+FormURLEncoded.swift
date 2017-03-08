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
                keyData = percentDecoded(token[0], nonEncodedTransform: replacePlus) ?? []
                let valueData = percentDecoded(token[1], nonEncodedTransform: replacePlus) ?? []
                value = .string(valueData.string)
            } else if allowEmptyValues && token.count == 1 {
                keyData = percentDecoded(token[0], nonEncodedTransform: replacePlus) ?? []
                value = .bool(true)
            } else {
                print("Found bad encoded pair \(pair.string) ... continuing")
                continue
            }

            var keyIndicatedArray = false

            // check if the key has `key[]` or `key[5]`
            if keyData.contains(.rightSquareBracket) && keyData.contains(.leftSquareBracket) {
                // get the key without the `[]`
                if let keySlice = keyData
                    .split(separator: .leftSquareBracket, maxSplits: 1)
                    .first {
                    keyData = keySlice.array
                }

                keyIndicatedArray = true
            }

            let key = keyData.string
            if let existing = urlEncoded[key] {
                // if a key already exists, create an
                // array and append the new value
                if var array = existing.typeArray {
                    array.append(value)
                    value = .array(array)
                } else {
                    value = .array([existing, value])
                }

            } else if keyIndicatedArray {
                // turn the value into an array
                // if the key had `[]`
                value = .array([value])
            }

            urlEncoded[key] = value

        }
        
        self = .object(urlEncoded)
    }
    
    public func formURLEncoded() throws -> Bytes {
        guard let dict = self.typeObject else { return [] }

        var bytes: [[Byte]] = []

        for (key, val) in dict {
            var subbytes: [Byte] = []
            subbytes += try percentEncoded(key.makeBytes())
            subbytes += Byte.equals
            subbytes += try percentEncoded(val.string?.makeBytes() ?? [])
            bytes.append(subbytes)
        }

        return bytes.joined(separator: [Byte.ampersand]).array
    }
}
