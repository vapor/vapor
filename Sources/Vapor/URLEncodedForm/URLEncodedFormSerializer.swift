import struct Foundation.CharacterSet

struct URLEncodedForm2Serializer {
    
    let splitVariablesOn: Character
    let splitKeyValueOn: Character
    
    /// Create a new form-urlencoded data parser.
    init(splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
        self.splitVariablesOn = splitVariablesOn
        self.splitKeyValueOn = splitKeyValueOn
    }
    
    func serialize(_ data: URLEncodedFormData2, codingPath: [CodingKey] = []) throws -> String {
        var entries: [String] = []
        let key = try codingPath.toURLEncodedKey()
        for value in data.values {
            if codingPath.count == 0 {
                try entries.append(value.urlEncoded())
            } else {
                try entries.append(key + String(splitKeyValueOn) + value.urlEncoded())
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

/// Converts `[String: URLEncodedFormData]` structs to `Data`.
internal struct URLEncodedFormSerializer {
    /// Create a new form-urlencoded data serializer.
    init() {}

    /// Serializes the data.
    func serialize(_ dictionary: [String: URLEncodedFormData]) throws -> String {
        var data: [String?] = []
        for (key, val) in dictionary {
            let subdata = try self.serialize(val, forKey: key.urlEncoded())
            data.append(subdata)
        }
        return data.compactMap { $0 }.joined(separator: "&")
    }

    /// Serializes a `URLEncodedFormData` at a given key.
    private func serialize(_ data: URLEncodedFormData, forKey key: String) throws -> String? {
        switch data {
        case .array(let value): return try self.serialize(value, forKey: key)
        case .dictionary(let value): return try self.serialize(value, forKey: key)
        case .string(let value): return try key + "=" + value.urlEncoded()
        }
    }

    /// Serializes a `[String: URLEncodedFormData]` at a given key.
    private func serialize(_ dictionary: [String: URLEncodedFormData], forKey key: String) throws -> String? {
        guard !dictionary.isEmpty else {
            return nil
        }
        return try dictionary.compactMap { subKey, value -> String? in
            return try self.serialize(value, forKey: key + "[" + subKey.urlEncoded() + "]")
        }.joined(separator: "&")
    }

    /// Serializes a `[URLEncodedFormData]` at a given key.
    private func serialize(_ array: [URLEncodedFormData], forKey key: String) throws -> String? {
        guard !array.isEmpty else {
            return nil
        }
        return try array.compactMap { value -> String? in
            return try self.serialize(value, forKey: key + "[]")
        }.joined(separator: "&")
    }
}

// MARK: Utilties

private extension String {
    /// Prepares a `String` for inclusion in form-urlencoded data.
    func urlEncoded(codingPath: [CodingKey] = []) throws -> String {
        guard let result = self.addingPercentEncoding(withAllowedCharacters: _allowedCharacters) else {
            throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: codingPath, debugDescription: "Unable to add percent encoding to \(self)"))
        }
        return result
    }
}

/// Characters allowed in form-urlencoded data.
private var _allowedCharacters: CharacterSet = {
    var allowed = CharacterSet.urlQueryAllowed
    // these symbols are reserved for url-encoded form
    allowed.remove(charactersIn: "?&=[];+")
    return allowed
}()
