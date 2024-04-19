import struct Foundation.CharacterSet

struct URLEncodedFormSerializer: Sendable {
    let splitVariablesOn: Character
    let splitKeyValueOn: Character
    
    /// Create a new form-urlencoded data parser.
    init(splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
        self.splitVariablesOn = splitVariablesOn
        self.splitKeyValueOn = splitKeyValueOn
    }
    
    func serialize(_ data: URLEncodedFormData, codingPath: [CodingKey] = []) throws -> String {
        var entries: [String] = []
        let key = try codingPath.toURLEncodedKey()
        for value in data.values {
            if codingPath.count == 0 {
                try entries.append(value.asUrlEncoded())
            } else {
                try entries.append(key + String(splitKeyValueOn) + value.asUrlEncoded())
            }
        }
        for (key, child) in data.children {
            entries.append(try serialize(child, codingPath: codingPath + [_CodingKey(stringValue: key) as CodingKey]))
        }
        return entries.joined(separator: String(splitVariablesOn))
    }
    
    struct _CodingKey: CodingKey {
        var stringValue: String
        
        init(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int?
        
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = intValue.description
        }
    }
}

extension Array where Element == CodingKey {
    func toURLEncodedKey() throws -> String {
        if count < 1 {
            return ""
        }
        return try self[0].stringValue.urlEncoded(codingPath: self) + self[1...].map({ (key: CodingKey) -> String in
            return try "[" + key.stringValue.urlEncoded(codingPath: self) + "]"
        }).joined()
    }
}

// MARK: Utilities

extension String {
    /// Prepares a `String` for inclusion in form-urlencoded data.
    func urlEncoded(codingPath: [CodingKey] = []) throws -> String {
        guard let result = self.addingPercentEncoding(
            withAllowedCharacters: Characters.allowedCharacters
        ) else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Unable to add percent encoding to \(self)"
            ))
        }
        return result
    }
}

/// Characters allowed in form-urlencoded data.
private enum Characters {
    static let allowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        // these symbols are reserved for url-encoded form
        allowed.remove(charactersIn: "?&=[];+")
        return allowed
    }()
}
