import Foundation

extension StructuredData {
    init(formURLEncoded data: Data) {
        var urlEncoded: [String: StructuredData] = [:]

        for pair in data.split(separator: .ampersand) {
            let token = pair.split(separator: .equals)
            if token.count == 2 {
                var keyData = percentDecoded(token[0]) ?? []

                let valueData = percentDecoded(token[1]) ?? []
                var value: StructuredData = .string(valueData.string)

                var keyIndicatedArray = false

                // check if the key has `key[]` or `key[5]`
                if keyData.contains(.rightSquareBracket) && keyData.contains(.leftSquareBracket) {
                    // get the key without the `[]`
                    if let keySlice = keyData
                        .split(separator: .leftSquareBracket, maxSplits: 1)
                        .first {
                        keyData = Data(keySlice)
                    }

                    keyIndicatedArray = true
                }

                let key: String = keyData.string

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
