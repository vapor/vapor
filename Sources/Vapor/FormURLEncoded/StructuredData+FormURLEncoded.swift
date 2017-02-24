import Foundation
import Core
import Node

extension Node {
    public init(formURLEncoded data: Bytes, allowEmptyValues: Bool = false) {
        var urlEncoded: [String: Node] = [:]

        let replacePlus: (Byte) -> (Byte) = { byte in
            if byte == .plus {
                return .space
            } else {
                return byte
            }
        }
        
        for pair in data.split(separator: .ampersand) {
            var value: Node = .string("")
            var keyData: Bytes
            
            let token = pair.split(separator: .equals)
            if token.count == 2 {
                keyData = percentDecoded(token[0], nonEncodedTransform: replacePlus) ?? []
                let valueData = percentDecoded(token[1], nonEncodedTransform: replacePlus) ?? []

                value = .string(valueData.string)
            } else if token.count == 1 && allowEmptyValues {
                keyData = percentDecoded(token[0], nonEncodedTransform: replacePlus) ?? []
            } else {
                self = .object(urlEncoded)
                return
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
                if case .array(var array) = existing {
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
        guard case .object(let dict) = self else {
            return []
        }

        var bytes: [[Byte]] = []

        for (key, val) in dict {
            var subbytes: [Byte] = []
            subbytes += try percentEncoded(key.bytes)
            subbytes += Byte.equals
            subbytes += try percentEncoded(val.string?.bytes ?? [])
            bytes.append(subbytes)
        }

        return bytes.joined(separator: [Byte.ampersand]).array
    }
}
