import Foundation

// TODO: Use URI percent decoding

extension String {
    init?(percentDecoding byteSlice: ArraySlice<Byte>) {

        let data = Data(byteSlice)
        guard let decoded = percentDecoded(data.bytes) else {
            return nil
        }

        self = decoded.string
    }
}

extension StructuredData {
    init(formURLEncoded data: Data) {
        var urlEncoded: [String: StructuredData] = [:]

        for pair in data.split(separator: .ampersand) {
            let token = pair.split(separator: .equals)
            if token.count == 2 {
                var key = String(percentDecoding: token[0]) ?? ""

                let stringValue = String(percentDecoding: token[1]) ?? ""
                var value: StructuredData = .string(stringValue)

                var keyIndicatedArray = false

                // check if the key has `key[]` or `key[5]`
                if key.hasSuffix("]") && key.characters.contains("[") {

                    // get the key without the `[]`
                    if let keySequence = key
                        .characters
                        .split(separator: "[", maxSplits: 1)
                        .first {
                        key = String(keySequence)
                    } else {
                        key = ""
                    }

                    keyIndicatedArray = true
                }

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
        }
        
        self = .dictionary(urlEncoded)
    }
}
