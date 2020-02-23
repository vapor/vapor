
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
public struct URLEncodedFormDecoder: ContentDecoder, URLQueryDecoder {

    /// The underlying `URLEncodedFormEncodedParser`
    private let parser: URLEncodedFormParser

    private let codingConfig: URLEncodedFormCodingConfig

    /// Create a new `URLEncodedFormDecoder`.
    ///
    /// - parameters:
    ///     - codingConfig: Defines how decoding is done
    public init(with codingConfig: URLEncodedFormCodingConfig = URLEncodedFormCodingConfig(bracketsAsArray: true, flagsAsBool: true, arraySeparator: nil)) {
        self.parser = URLEncodedFormParser()
        self.codingConfig = codingConfig
    }
    
    /// `ContentDecoder` conformance.
    public func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D
        where D: Decodable
    {
        guard headers.contentType == .urlEncodedForm else {
            throw Abort(.unsupportedMediaType)
        }
        let string = body.getString(at: body.readerIndex, length: body.readableBytes) ?? ""
        return try self.decode(D.self, from: string)
    }
    
    public func decode<D>(_ decodable: D.Type, from url: URI) throws -> D where D: Decodable {
        return try self.decode(D.self, from: url.query ?? "", with: nil)
    }
    
    public func decode<D>(_ decodable: D.Type, from url: URI, with codingConfig: URLEncodedFormCodingConfig? = nil) throws -> D where D : Decodable {
        return try self.decode(D.self, from: url.query ?? "", with: codingConfig)
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
    public func decode<D>(_ decodable: D.Type, from string: String, with codingConfig: URLEncodedFormCodingConfig? = nil) throws -> D where D : Decodable {
        let parsedData = try self.parser.parse(string)
        let decoder = _Decoder(data: parsedData, codingPath: [], with: codingConfig ?? self.codingConfig)
        return try D(from: decoder)
    }
}

// MARK: Private

/// Private `Decoder`. See `URLEncodedFormDecoder` for public decoder.
private struct _Decoder: Decoder {
    var data: URLEncodedFormData
    var codingPath: [CodingKey]
    var codingConfig: URLEncodedFormCodingConfig
    
    /// See `Decoder`
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }
    
    /// Creates a new `_URLEncodedFormDecoder`.
    init(data: URLEncodedFormData, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
        self.data = data
        self.codingPath = codingPath
        self.codingConfig = codingConfig
        
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KeyedContainer<Key>(data: data, codingPath: self.codingPath, with: codingConfig))
    }
    
    struct KeyedContainer<Key>: KeyedDecodingContainerProtocol
        where Key: CodingKey
    {
        let data: URLEncodedFormData
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig

        var allKeys: [Key] {
            return data.children.keys.compactMap { Key(stringValue: String($0)) }
        }
        
        init(data: URLEncodedFormData, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
            self.data = data
            self.codingPath = codingPath
            self.codingConfig = codingConfig
        }
        
        func contains(_ key: Key) -> Bool {
            return data.children[key.stringValue] != nil
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            return data.children[key.stringValue] == nil
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            //If we are trying to decode a required array, we might not have decoded a child, but we should still try to decode an empty array
            let child = data.children[key.stringValue] ?? []
            if let convertible = T.self as? URLEncodedFormFieldConvertible.Type {
                var values = child.values
                if codingConfig.bracketsAsArray {
                    // empty brackets turn into empty strings!
                    if let valuesInBracket = child.children[""] {
                        values = values + valuesInBracket.values
                    }
                }
                guard let value = values.last else {
                    if codingConfig.flagsAsBool {
                        //If no values found see if we are decoding a boolean
                        if let _ = T.self as? Bool.Type {
                            return data.values.contains(.urlDecoded(key.stringValue)) as! T
                        }
                    }
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath + [key])
                }
                if let result = convertible.init(urlEncodedFormValue: value) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath + [key])
                }
            } else {
                let decoder = _Decoder(data: child, codingPath: self.codingPath + [key], with: codingConfig)
                return try T(from: decoder)
            }
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            guard let child = data.children[key.stringValue] else {
                throw DecodingError.valueNotFound([String: Any].self, at: self.codingPath + [key])
            }
            return KeyedDecodingContainer(KeyedContainer<NestedKey>(data: child, codingPath: self.codingPath + [key], with: codingConfig))
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            guard let child = data.children[key.stringValue] else {
                throw DecodingError.valueNotFound([Any].self, at: self.codingPath + [key])
            }
            return try UnkeyedContainer(data: child, codingPath: self.codingPath + [key], with: codingConfig)
        }
        
        func superDecoder() throws -> Decoder {
            return _Decoder(data: data, codingPath: self.codingPath, with: codingConfig)
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            guard let child = data.children[key.stringValue] else {
                throw DecodingError.valueNotFound([Any].self, at: self.codingPath + [key])
            }
            return _Decoder(data: child, codingPath: self.codingPath, with: codingConfig)
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try UnkeyedContainer(data: data, codingPath: codingPath, with: codingConfig)
    }
    
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let data: URLEncodedFormData
        let values: [URLQueryFragment]
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig
        var allChildKeysAreNumbers: Bool

        var count: Int? {
            //Did we get an array with arr[0]=a&arr[1]=b indexing?
            if allChildKeysAreNumbers {
                return data.children.count
            }
            //No we got an array with arr[]=a&arr[]=b or arr=a&arr=b
            return values.count
        }
        var isAtEnd: Bool {
            guard let count = self.count else {
                return true
            }
            return currentIndex >= count
        }
        var currentIndex: Int
        
        init(data: URLEncodedFormData, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) throws {
            self.data = data
            self.codingPath = codingPath
            self.codingConfig = codingConfig
            self.currentIndex = 0
            //Did we get an array with arr[0]=a&arr[1]=b indexing?
            //Cache this result
            self.allChildKeysAreNumbers = data.children.count > 0 && data.allChildKeysAreSequentialIntegers
            
            if allChildKeysAreNumbers {
                self.values = data.values
            } else {
                //No we got an array with arr[]=a&arr[]=b or arr=a&arr=b
                var values = data.values
                if codingConfig.bracketsAsArray {
                    // empty brackets turn into empty strings!
                    if let valuesInBracket = data.children[""] {
                        values = values + valuesInBracket.values
                    }
                }
                if let explodeArraysOn = codingConfig.arraySeparator {
                    var explodedValues: [URLQueryFragment] = []
                    for value in values {
                        explodedValues = try explodedValues + value.asUrlEncoded().split(separator: explodeArraysOn).map({ (ss: Substring) -> URLQueryFragment in
                            return .urlEncoded(String(ss))
                        })
                    }
                    values = explodedValues
                }
                self.values = values
            }
        }
        
        func decodeNil() throws -> Bool {
            return false
        }
        
        struct _CodingKey: CodingKey {
            var stringValue: String
            
            init(stringValue: String) {
                self.stringValue = stringValue
            }
            
            var intValue: Int?
            
            init?(intValue: Int) {
                self.intValue = intValue
                self.stringValue = String(intValue)
            }
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            defer { currentIndex += 1 }
            if allChildKeysAreNumbers {
                let childData = data.children[String(currentIndex)]! //We can force an unwrap because in the constructor we checked data.allChildKeysAreNumbers
                let decoder = _Decoder(data: childData, codingPath: self.codingPath + [_CodingKey(stringValue: String(currentIndex)) as CodingKey] , with: codingConfig)
                return try T(from: decoder)
            } else {
                let value = values[self.currentIndex]
                if let convertible = T.self as? URLEncodedFormFieldConvertible.Type {
                    if let result = convertible.init(urlEncodedFormValue: value) {
                        return result as! T
                    } else {
                        throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                    }
                } else {
                    //We need to pass in the value to be decoded
                    let decoder = _Decoder(data: URLEncodedFormData(values: [value]), codingPath: self.codingPath, with: codingConfig)
                    return try T(from: decoder)
                }
            }
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
            where NestedKey: CodingKey
        {
            throw DecodingError.typeMismatch(type.self, at: codingPath)
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch(Array<Any>.self, at: codingPath)
        }
        
        mutating func superDecoder() throws -> Decoder {
            throw DecodingError.typeMismatch(Array<Any>.self, at: codingPath)
            //      defer { self.currentIndex += 1 }
            //      return _Decoder(data: self.data[self.currentIndex], codingPath: self.codingPath)
        }
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(data: data, codingPath: codingPath, with: codingConfig)
    }
    
    struct SingleValueContainer: SingleValueDecodingContainer {
        let data: URLEncodedFormData
        let values: [URLQueryFragment]
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig
        
        init(data: URLEncodedFormData, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
            self.data = data
            self.codingPath = codingPath
            var values = data.values
            if codingConfig.bracketsAsArray {
                // empty brackets turn into empty strings!
                if let valuesInBracket = data.children[""] {
                    values = values + valuesInBracket.values
                }
            }
            self.values = values
            self.codingConfig = codingConfig
        }
        
        func decodeNil() -> Bool {
            return false
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            if let convertible = T.self as? URLEncodedFormFieldConvertible.Type {
                guard let value = values.last else {
                    throw DecodingError.valueNotFound(T.self, at: self.codingPath)
                }
                if let result = convertible.init(urlEncodedFormValue: value) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder(data: data, codingPath: self.codingPath, with: codingConfig)
                return try T(from: decoder)
            }
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
