
/**
 Used to capture URLForm Coding Configuration used for encoding and decoding
 */
public struct URLEncodedFormCodingConfig {
    let bracketsAsArray: Bool
    let flagsAsBool: Bool
    let explodeArraysOn: Character?
    
    /**
     - parameters:
            - bracketsAsArray: Set to `true` allows you to parse `arr[]=v1&arr[]=v2` as an array with key `arr`. Otherwise you would use  `arr` without  a bracket like `arr=v1&arr=v2`
            - flagsAsBool: Set to `true` allows you to parse `flag1&flag2` as boolean variables where object with variable `flag1` and `flag2` would decode to `true` or `false` depending on if the value was present or not.
                           If this flag is set to true, it will always resolve for an optional `Bool`.
            - explodeArraysOn: Uses this character to create arrays. If set to `,`, `arr=v1,v2` would populate a key named `arr` of type `Array` to be decoded as `["v1", "v2"]`

     */
    public init(bracketsAsArray: Bool = true, flagsAsBool: Bool = true, explodeArraysOn: Character? = nil) {
        self.bracketsAsArray = bracketsAsArray
        self.flagsAsBool = flagsAsBool
        self.explodeArraysOn = explodeArraysOn
    }
}

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
    private let parser: URLEncodedFormParser2

    private let codingConfig: URLEncodedFormCodingConfig

    /// Create a new `URLEncodedFormDecoder`.
    ///
    /// - parameters:
    ///     - codingConfig: Defines how decoding is done
    public init(with codingConfig: URLEncodedFormCodingConfig = URLEncodedFormCodingConfig()) {
        self.parser = URLEncodedFormParser2()
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
        let decoder = _Decoder2(data: parsedData, codingPath: [], with: codingConfig ?? self.codingConfig)
        return try D(from: decoder)
    }
}

// MARK: Private

private struct _Decoder2: Decoder {
    var data: URLEncodedFormData2
    var codingPath: [CodingKey]
    var codingConfig: URLEncodedFormCodingConfig
    
    /// See `Decoder`
    var userInfo: [CodingUserInfoKey: Any] {
        return [:]
    }
    
    /// Creates a new `_URLEncodedFormDecoder`.
    init(data: URLEncodedFormData2, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
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
        let data: URLEncodedFormData2
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig

        var allKeys: [Key] {
            return data.children.keys.compactMap { Key(stringValue: String($0)) }
        }
        
        init(data: URLEncodedFormData2, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
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
            let child = data.children[key.stringValue] ?? URLEncodedFormData2()
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
                            return data.values.contains(key.stringValue) as! T
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
                let decoder = _Decoder2(data: child, codingPath: self.codingPath + [key], with: codingConfig)
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
            return UnkeyedContainer(data: child, codingPath: self.codingPath + [key], with: codingConfig)
        }
        
        func superDecoder() throws -> Decoder {
            return _Decoder2(data: data, codingPath: self.codingPath, with: codingConfig)
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            guard let child = data.children[key.stringValue] else {
                throw DecodingError.valueNotFound([Any].self, at: self.codingPath + [key])
            }
            return _Decoder2(data: child, codingPath: self.codingPath, with: codingConfig)
        }
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UnkeyedContainer(data: data, codingPath: codingPath, with: codingConfig)
    }
    
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let data: URLEncodedFormData2
        let values: [String]
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig

        var count: Int? {
            return values.count
        }
        var isAtEnd: Bool {
            guard let count = self.count else {
                return true
            }
            return currentIndex >= count
        }
        var currentIndex: Int
        
        init(data: URLEncodedFormData2, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
            self.data = data
            self.codingPath = codingPath
            var values = data.values
            if codingConfig.bracketsAsArray {
                // empty brackets turn into empty strings!
                if let valuesInBracket = data.children[""] {
                    values = values + valuesInBracket.values
                }
            }
            if let explodeArraysOn = codingConfig.explodeArraysOn {
                var explodedValues: [String] = []
                for value in values {
                    explodedValues = explodedValues + value.split(separator: explodeArraysOn).map(String.init)
                }
                values = explodedValues
            }
            self.values = values
            self.codingConfig = codingConfig
            self.currentIndex = 0
        }
        
        func decodeNil() throws -> Bool {
            return false
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            let value = values[self.currentIndex]
            defer { self.currentIndex += 1 }
            if let convertible = T.self as? URLEncodedFormFieldConvertible.Type {
                if let result = convertible.init(urlEncodedFormValue: String(value)) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder2(data: data, codingPath: self.codingPath, with: codingConfig)
                return try T(from: decoder)
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
        let data: URLEncodedFormData2
        let values: [String]
        var codingPath: [CodingKey]
        var codingConfig: URLEncodedFormCodingConfig
        
        init(data: URLEncodedFormData2, codingPath: [CodingKey], with codingConfig: URLEncodedFormCodingConfig) {
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
                if let result = convertible.init(urlEncodedFormValue: String(value)) {
                    return result as! T
                } else {
                    throw DecodingError.typeMismatch(T.self, at: self.codingPath)
                }
            } else {
                let decoder = _Decoder2(data: data, codingPath: self.codingPath, with: codingConfig)
                return try T(from: decoder)
            }
        }
    }
}

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
            throw DecodingError.valueNotFound([String: Any].self, at: codingPath)
        }
        switch data {
        case .dictionary(let dict):
            return KeyedDecodingContainer(KeyedContainer<Key>(data: dict, codingPath: self.codingPath))
        default:
            throw DecodingError.valueNotFound([String: Any].self, at: codingPath)
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
        case .string(let s):
            return UnkeyedContainer(data: [.string(s)], codingPath: self.codingPath)
        default:
            throw DecodingError.valueNotFound([Any].self, at: codingPath)
        }
    }

    /// See `Decoder`
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        guard let data = self.data else {
            throw DecodingError.valueNotFound(Any.self, at: codingPath)
        }

        return SingleValueContainer(data: data, codingPath: codingPath)
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
                throw DecodingError.valueNotFound([String: Any].self, at: codingPath)
            }
            switch data {
            case .dictionary(let dict):
                return KeyedDecodingContainer(KeyedContainer<NestedKey>(data: dict, codingPath: self.codingPath + [key]))
            default:
                throw DecodingError.valueNotFound([String: Any].self, at: codingPath)
            }
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            guard let data = self.data[key.stringValue] else {
                throw DecodingError.valueNotFound([Any].self, at: codingPath)
            }
            switch data {
            case .array(let arr):
                return UnkeyedContainer(data: arr, codingPath: self.codingPath + [key])
            default:
                throw DecodingError.valueNotFound([Any].self, at: codingPath)
            }
        }
        
        func superDecoder() throws -> Decoder {
            return _Decoder(data: .dictionary(self.data), codingPath: self.codingPath)
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            guard let data = self.data[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(
                    codingPath: self.codingPath + [key],
                    debugDescription: "Key not found",
                    underlyingError: nil
                ))
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
            default:
                throw DecodingError.valueNotFound([String: Any].self, at: codingPath + [BasicCodingKey.index(currentIndex)])
            }
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            defer { self.currentIndex += 1 }
            switch self.data[self.currentIndex] {
            case .array(let arr):
                return UnkeyedContainer(data: arr, codingPath: self.codingPath)
            default:
                throw DecodingError.valueNotFound([Any].self, at: codingPath + [BasicCodingKey.index(currentIndex)])
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
