import Foundation

extension String {
    init?(percentDecoding byteSlice: ArraySlice<UInt8>) {
        let data = Data(byteSlice)
        let string = String(data)

        guard let validated = String(validatingUTF8: string) else {
            return nil
        }

        guard let decoded = try? String(percentEncoded: validated) else {
            return nil
        }

        self = decoded
    }
}

extension Request {
    static func parseFormURLEncoded(_ data: Data) -> StructuredData {
        var urlEncoded: [String: StructuredData] = [:]

        let ampersand = "&".data.bytes[0]
        let equals = "=".data.bytes[0]

        for pair in data.split(separator: ampersand) {
            let token = pair.split(separator: equals)
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
        
        return .dictionary(urlEncoded)
    }
}
