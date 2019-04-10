/// Decodes instances of `Decodable` types from `application/x-www-form-urlencoded` `Data`.
///
///     print(data) // "name=Vapor&age=3"
///     let user = try URLEncodedFormDecoder().decode(User.self, from: data)
///     print(user) // User
///
/// URL-encoded forms are commonly used by websites to send form data via POST requests. This encoding is relatively
/// efficient for small amounts of data but must be percent-encoded.  `multipart/form-data` is more efficient for sending
/// large data blobs like files.
///
/// See [Mozilla's](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) docs for more information about
/// url-encoded forms.
public struct URLEncodedFormDecoder: RequestDecoder, URLContentDecoder {
    /// The underlying `URLEncodedFormEncodedParser`
    private let parser: URLEncodedFormParser

    /// If `true`, empty values will be omitted. Empty values are URL-Encoded keys with no value following the `=` sign.
    ///
    ///     name=Vapor&age=
    ///
    /// In the above example, `age` is an empty value.
    public var omitEmptyValues: Bool

    /// If `true`, flags will be omitted. Flags are URL-encoded keys with no following `=` sign.
    ///
    ///     name=Vapor&isAdmin&age=3
    ///
    /// In the above example, `isAdmin` is a flag.
    public var omitFlags: Bool

    /// Create a new `URLEncodedFormDecoder`.
    ///
    /// - parameters:
    ///     - omitEmptyValues: If `true`, empty values will be omitted.
    ///                        Empty values are URL-Encoded keys with no value following the `=` sign.
    ///     - omitFlags: If `true`, flags will be omitted.
    ///                  Flags are URL-encoded keys with no following `=` sign.
    public init(omitEmptyValues: Bool = false, omitFlags: Bool = false) {
        self.parser = URLEncodedFormParser(omitEmptyValues: omitEmptyValues, omitFlags: omitFlags)
        self.omitFlags = omitFlags
        self.omitEmptyValues = omitEmptyValues
    }
    
    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from request: Request) throws -> D
        where D: Decodable {
        guard request.headers.contentType == .urlEncodedForm else {
            throw Abort(.unsupportedMediaType)
        }
        guard let buffer = request.body.data else {
            throw Abort(.notAcceptable)
        }
        let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
        return try self.decode(D.self, from: string)
    }
    
    public func decode<D>(_ decodable: D.Type, from url: URL) throws -> D where D : Decodable {
        guard let query = url.query else {
            throw Abort(.notAcceptable)
        }
        return try self.decode(D.self, from: query)
    }
    

    /// Decodes an instance of the supplied `Decodable` type from `Data`.
    ///
    ///     print(data) // "name=Vapor&age=3"
    ///     let user = try URLEncodedFormDecoder().decode(User.self, from: data)
    ///     print(user) // User
    ///
    /// - parameters:
    ///     - decodable: Generic `Decodable` type (`D`) to decode.
    ///     - from: `Data` to decode a `D` from.
    /// - returns: An instance of the `Decodable` type (`D`).
    /// - throws: Any error that may occur while attempting to decode the specified type.
    public func decode<D>(_ decodable: D.Type, from string: String) throws -> D where D : Decodable {
        let urlEncodedFormData = try self.parser.parse(string)
        let decoder = _Decoder(data: .dictionary(urlEncodedFormData), codingPath: [])
        return try D(from: decoder)
    }
}

// MARK: Private

/// Private `Decoder`. See `URLEncodedFormDecoder` for public decoder.
private struct _Decoder: Decoder {
    /// See `Decoder`
    let codingPath: [CodingKey]

    /// See `Decoder`
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }

    /// The data being decoded
    let data: URLEncodedFormData?

    /// Creates a new `_URLEncodedFormDecoder`.
    init(data: URLEncodedFormData?, codingPath: [CodingKey]) {
        self.data = data
        self.codingPath = codingPath
    }

    /// See `Decoder`
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey
    {
        guard let data = self.data else {
            fatalError()
        }
        switch data {
        case .dictionary(let dict):
            return KeyedDecodingContainer(KeyedContainer<Key>(data: dict, codingPath: self.codingPath))
        default: fatalError()
        }
    }

    /// See `Decoder`
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let data = self.data else {
            return UnkeyedContainer(data: [], codingPath: self.codingPath)
        }
        switch data {
        case .array(let arr):
            return UnkeyedContainer(data: arr, codingPath: self.codingPath)
        default: fatalError()
        }
    }

    /// See `Decoder`
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(data: self.data!, codingPath: codingPath)
    }
    
    struct SingleValueContainer: SingleValueDecodingContainer {
        let data: URLEncodedFormData
        var codingPath: [CodingKey]
        
        init(data: URLEncodedFormData, codingPath: [CodingKey]) {
            self.data = data
            self.codingPath = codingPath
        }
        
        func decodeNil() -> Bool {
            return false
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            if let convertible = T.self as? URLEncodedFormDataConvertible.Type {
                if let data = convertible.init(urlEncodedFormData: self.data) {
                    return data as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder(data: data, codingPath: self.codingPath)
                return try T(from: decoder)
            }
        }
    }
    
    struct KeyedContainer<Key>: KeyedDecodingContainerProtocol
        where Key: CodingKey
    {
        let data: [String: URLEncodedFormData]
        var codingPath: [CodingKey]
        
        var allKeys: [Key] {
            return self.data.keys.compactMap { Key(stringValue: $0) }
        }
        
        init(data: [String: URLEncodedFormData], codingPath: [CodingKey]) {
            self.data = data
            self.codingPath = codingPath
        }
        
        func contains(_ key: Key) -> Bool {
            return self.data[key.stringValue] != nil
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            return self.data[key.stringValue] == nil
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            if let convertible = T.self as? URLEncodedFormDataConvertible.Type {
                guard let data = self.data[key.stringValue] else {
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath + [key])
                }
                if let result = convertible.init(urlEncodedFormData: data) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath + [key])
                }
            } else {
                let decoder = _Decoder(data: self.data[key.stringValue], codingPath: self.codingPath + [key])
                return try T(from: decoder)
            }
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            guard let data = self.data[key.stringValue] else {
                fatalError()
            }
            switch data {
            case .dictionary(let dict):
                return KeyedDecodingContainer(KeyedContainer<NestedKey>(data: dict, codingPath: self.codingPath + [key]))
            default: fatalError()
            }
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            guard let data = self.data[key.stringValue] else {
                fatalError()
            }
            switch data {
            case .array(let arr):
                return UnkeyedContainer(data: arr, codingPath: self.codingPath + [key])
            default: fatalError()
            }
        }
        
        func superDecoder() throws -> Decoder {
            return _Decoder(data: .dictionary(self.data), codingPath: self.codingPath)
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            guard let data = self.data[key.stringValue] else {
                fatalError()
            }
            return _Decoder(data: data, codingPath: self.codingPath + [key])
        }
    }
    
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let data: [URLEncodedFormData]
        var codingPath: [CodingKey]
        var count: Int? {
            return self.data.count
        }
        var isAtEnd: Bool {
            guard let count = self.count else {
                return true
            }
            return currentIndex >= count
        }
        var currentIndex: Int
        
        init(data: [URLEncodedFormData], codingPath: [CodingKey]) {
            self.data = data
            self.codingPath = codingPath
            self.currentIndex = 0
        }
        
        func decodeNil() throws -> Bool {
            return false
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            let data = self.data[self.currentIndex]
            defer { self.currentIndex += 1 }
            if let convertible = T.self as? URLEncodedFormDataConvertible.Type {
                if let result = convertible.init(urlEncodedFormData: data) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder(data: data, codingPath: self.codingPath)
                return try T(from: decoder)
            }
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            defer { self.currentIndex += 1 }
            switch self.data[self.currentIndex] {
            case .dictionary(let dict):
                return KeyedDecodingContainer(KeyedContainer<NestedKey>(data: dict, codingPath: self.codingPath))
            default: fatalError()
            }
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            defer { self.currentIndex += 1 }
            switch self.data[self.currentIndex] {
            case .array(let arr):
                return UnkeyedContainer(data: arr, codingPath: self.codingPath)
            default: fatalError()
            }
        }
        
        mutating func superDecoder() throws -> Decoder {
            defer { self.currentIndex += 1 }
            return _Decoder(data: self.data[self.currentIndex], codingPath: self.codingPath)
        }
    }
}

private extension DecodingError {
    static func typeMismatch(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "Data found at '\(pathString)' was not \(type)"
        )
        return Swift.DecodingError.typeMismatch(type, context)
    }
    
    static func valueNotFound(_ type: Any.Type, at path: [CodingKey]) -> DecodingError {
        let pathString = path.map { $0.stringValue }.joined(separator: ".")
        let context = DecodingError.Context(
            codingPath: path,
            debugDescription: "No \(type) was found at '\(pathString)'"
        )
        return Swift.DecodingError.valueNotFound(type, context)
    }
}
