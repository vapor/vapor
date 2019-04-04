import struct Foundation.CharacterSet

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
    func urlEncoded() throws -> String {
        guard let result = self.addingPercentEncoding(withAllowedCharacters: _allowedCharacters) else {
            #warning("TODO: better error")
            fatalError()
        }
        return result
    }
}

/// Characters allowed in form-urlencoded data.
private var _allowedCharacters: CharacterSet = {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove("+")
    return allowed
}()
