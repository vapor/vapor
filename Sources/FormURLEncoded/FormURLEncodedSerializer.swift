import Bits
import Foundation

/// Converts form-urlencoded structs to data
final class FormURLEncodedSerializer {
    /// Default form url encoded serializer.
    static let `default` = FormURLEncodedSerializer()

    /// Create a new form-urlencoded data serializer.
    init() {}

    /// Serializes the data.
    func serialize(_ formURLEncoded: [String: FormURLEncodedData]) throws -> Data {
        var data: [Data] = []
        for (key, val) in formURLEncoded {
            let key = try key.formURLEncoded()
            let subdata = try serialize(val, forKey: key)
            data.append(subdata)
        }
        return data.joinedWithAmpersands()
    }

    private func serialize(_ dictionary: [String: FormURLEncodedData], forKey key: Data) throws -> Data {
        let values = try dictionary.map { subKey, value -> Data in
            let keyPath = try [.leftSquareBracket] + subKey.formURLEncoded() + [.rightSquareBracket]
            return try serialize(value, forKey: key + keyPath)
        }
        return values.joinedWithAmpersands()
    }

    private func serialize(_ array: [FormURLEncodedData], forKey key: Data) throws -> Data {
        let collection = try array.map { value -> Data in
            let keyPath = key + [.leftSquareBracket, .rightSquareBracket]
            return try serialize(value, forKey: keyPath)
        }

        return collection.joinedWithAmpersands()
    }

    private func serialize(_ data: FormURLEncodedData, forKey key: Data) throws -> Data {
        let encoded: Data
        switch data {
        case .array(let subArray):
            encoded = try serialize(subArray, forKey: key)
        case .dictionary(let subDict):
            encoded = try serialize(subDict, forKey: key)
        case .string(let string):
            encoded = try key + [.equals] + string.formURLEncoded()
        }
        return encoded
    }
}

// MARK: Utilties

extension Array where Element == Data {
    fileprivate func joinedWithAmpersands() -> Data {
        return Data(self.joined(separator: [.ampersand]))
    }
}

extension String {
    fileprivate func formURLEncoded() throws -> Data {
        guard let string = self.addingPercentEncoding(withAllowedCharacters: _allowedCharacters) else {
            throw FormURLError(
                identifier: "percentEncoding",
                reason: "Failed to percent encode string: \(self)"
            )
        }

        guard let encoded = string.data(using: .utf8) else {
            throw FormURLError(
                identifier: "utf8Encoding",
                reason: "Failed to utf8 encode string: \(self)"
            )
        }

        return encoded
    }
}

fileprivate var _allowedCharacters: CharacterSet = {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove("+")
    return allowed
}()
